/* dzprobe.c — TEMPORARY measurement shim for the dazzle frame-lifetime probe.
 *
 * Question it answers: of the engine's remaining allocation posts, how much
 * dies at a VM frame boundary (which is what stage 6b's per-frame regions
 * would reclaim) and how much survives it?
 *
 * Mechanism: the Scaly side hosts a SAMPLED primitive result on a page of its
 * own and, at the first frame pop after its creation, ARMS that page
 * (PROT_NONE). Any later read or write faults; this handler records
 * (page, frame-pop sequence, eval generation), un-protects, and lets the
 * access retry, so the run continues correctly. The Scaly side re-arms at the
 * next frame pop, so per object we learn at which frame boundaries it was
 * still in use. No faults after arming = the object died at its own frame
 * boundary.
 *
 * Not part of the port. Compiled into a measurement binary only.
 */
#include <signal.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#define DZP_PAGE 4096UL
#define DZP_SET_SLOTS (1UL << 22)    /* 4 M slots, 32 MB — armed page set */
#define DZP_RING (1UL << 16)

static unsigned long* dzp_set;        /* open-addressed set of armed pages */
static long dzp_seq;                  /* frame-pop sequence (Scaly bumps) */
static long dzp_gen;                  /* eval-bracket generation */
static long dzp_faults;               /* total faults recognised */
static long dzp_dropped;              /* ring overflows */
static long dzp_arms;                 /* pages armed */
static unsigned long dzp_last_arm;    /* most recently armed page */
static char dzp_altstack[262144];

struct dzp_ent { unsigned long page; long seq; long gen; };
static struct dzp_ent dzp_ring[DZP_RING];
static volatile long dzp_head;        /* written by the handler */
static long dzp_tail;                 /* read/written by the Scaly side */

static void (*dzp_prev_segv)(int, siginfo_t*, void*);

static unsigned long dzp_hash(unsigned long p)
{
    unsigned long h = p >> 12;
    h *= 0x9E3779B97F4A7C15UL;
    return h >> 20;
}

/* membership test — the handler only ever reads this table */
static int dzp_known(unsigned long page)
{
    unsigned long i = dzp_hash(page) & (DZP_SET_SLOTS - 1);
    for (;;) {
        unsigned long k = dzp_set[i];
        if (k == 0) return 0;
        if (k == page) return 1;
        i = (i + 1) & (DZP_SET_SLOTS - 1);
    }
}

static void dzp_insert(unsigned long page)
{
    unsigned long i = dzp_hash(page) & (DZP_SET_SLOTS - 1);
    for (;;) {
        unsigned long k = dzp_set[i];
        if (k == 0) { dzp_set[i] = page; return; }
        if (k == page) return;
        i = (i + 1) & (DZP_SET_SLOTS - 1);
    }
}

/* Which armed page does this fault belong to? Normally the page the address
 * sits in — but a SIGBUS on arm64 can report si_addr rounded to the NEXT page
 * (seen for the engine's first touch of an armed page), so an unknown address
 * whose PREVIOUS page is armed counts as that page's fault. */
static unsigned long dzp_owner(unsigned long addr)
{
    unsigned long page = addr & ~(DZP_PAGE - 1);
    if (!dzp_set || !page) return 0;
    if (dzp_known(page)) return page;
    if (dzp_known(page - DZP_PAGE)) return page - DZP_PAGE;
    return 0;
}

static void dzp_handler(int sig, siginfo_t* si, void* ctx)
{
    unsigned long addr = si ? (unsigned long)si->si_addr : 0;
    unsigned long page = dzp_owner(addr);
    if (page) {
        long h = dzp_head;
        dzp_faults++;
        if (h - dzp_tail < (long)DZP_RING) {
            struct dzp_ent* e = &dzp_ring[h & (DZP_RING - 1)];
            e->page = page; e->seq = dzp_seq; e->gen = dzp_gen;
            dzp_head = h + 1;
        } else
            dzp_dropped++;
        mprotect((void*)page, DZP_PAGE, PROT_READ | PROT_WRITE);
        return;
    }
    /* not ours: say where, then die the way we would have without the handler */
    {
        char buf[128]; int n = 0; int i;
        const char* m = "dzprobe: unhandled fault sig=";
        while (*m) buf[n++] = *m++;
        buf[n++] = (char)('0' + (sig / 10)); buf[n++] = (char)('0' + (sig % 10));
        m = " addr=0x"; while (*m) buf[n++] = *m++;
        for (i = 60; i >= 0; i -= 4) {
            int d = (int)((addr >> i) & 0xF);
            buf[n++] = (char)(d < 10 ? '0' + d : 'a' + d - 10);
        }
        m = " known="; while (*m) buf[n++] = *m++;
        buf[n++] = (char)('0' + (page != 0));
        m = " arms="; while (*m) buf[n++] = *m++;
        { long f = dzp_arms; char t[24]; int k = 0; if (!f) t[k++]='0'; while (f>0){t[k++]=(char)('0'+(f%10)); f/=10;} while(k>0) buf[n++]=t[--k]; }
        m = " lastarm=0x"; while (*m) buf[n++] = *m++;
        for (i = 60; i >= 0; i -= 4) { int d = (int)((dzp_last_arm >> i) & 0xF); buf[n++] = (char)(d < 10 ? '0'+d : 'a'+d-10); }
        m = " faults="; while (*m) buf[n++] = *m++;
        {
            long f = dzp_faults; char t[24]; int k = 0;
            if (f == 0) t[k++] = '0';
            while (f > 0) { t[k++] = (char)('0' + (f % 10)); f /= 10; }
            while (k > 0) buf[n++] = t[--k];
        }
        buf[n++] = 10;
        write(2, buf, (unsigned long)n);
    }
    (void)ctx;
    signal(sig, SIG_DFL);
    raise(sig);
}

static void (*dzp_report)(void);
static void dzp_atexit(void) { if (dzp_report) dzp_report(); }

/* `report` is the Scaly side's reporting entry point, run from atexit — the CLI
 * has seven exits and inserting the call at each one is how you accidentally
 * detach a single-statement `if` body. */
long dz_probe_install(void (*report)(void))
{
    stack_t ss;
    struct sigaction sa;
    if (dzp_set) return 0;
    dzp_report = report;
    atexit(dzp_atexit);
    dzp_set = calloc(DZP_SET_SLOTS, sizeof(unsigned long));
    if (!dzp_set) return 1;
    ss.ss_sp = dzp_altstack; ss.ss_size = sizeof dzp_altstack; ss.ss_flags = 0;
    if (sigaltstack(&ss, 0) < 0) return 2;
    memset(&sa, 0, sizeof sa);
    sa.sa_sigaction = dzp_handler;
    sa.sa_flags = SA_SIGINFO | SA_ONSTACK;
    sigemptyset(&sa.sa_mask);
    if (sigaction(SIGSEGV, &sa, 0) < 0) return 3;
    if (sigaction(SIGBUS, &sa, 0) < 0) return 4;
    (void)dzp_prev_segv;
    return 0;
}

/* a 4 KB page of our own: mmap'd, so it is zero-filled and mprotect on it is
 * always allowed (a page out of the engine's HeapBucket is inside a malloc'd
 * block, and mprotect on those sub-ranges was measured to fail). */
void* dz_probe_page(void)
{
    void* p = mmap(0, DZP_PAGE, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (p == MAP_FAILED) return 0;
    return p;
}

/* arm one page: remember it and take away all access */
long dz_probe_arm(void* page)
{
    dzp_arms++;
    dzp_last_arm = (unsigned long)page;
    dzp_insert((unsigned long)page);
    if (mprotect(page, DZP_PAGE, PROT_NONE) < 0) return errno;
    return 0;
}

/* self-test: arm a page of our own, touch it, and report the fault count
 * delta. 1 = the mechanism works in this binary. */
long dz_probe_selftest(void)
{
    volatile char* p = aligned_alloc(DZP_PAGE, DZP_PAGE);
    long before = dzp_faults;
    if (!p) return -1;
    p[3] = 7;
    if (dz_probe_arm((void*)p)) return -2;
    if (p[3] != 7) return -3;
    return dzp_faults - before;
}

/* re-arm a page already in the set (after a recorded fault) */
long dz_probe_rearm(void* page)
{
    if (mprotect(page, DZP_PAGE, PROT_NONE) < 0) return 1;
    return 0;
}

/* the frame-pop clock; the handler stamps faults with it */
long dz_probe_tick(void)
{
    return ++dzp_seq;
}

long dz_probe_seq(void) { return dzp_seq; }

void dz_probe_set_gen(long g) { dzp_gen = g; }

/* copy out recorded faults; returns how many triples were written */
long dz_probe_drain(unsigned long* pages, long* seqs, long* gens, long max)
{
    long n = 0;
    while (dzp_tail != dzp_head && n < max) {
        struct dzp_ent* e = &dzp_ring[dzp_tail & (DZP_RING - 1)];
        pages[n] = e->page; seqs[n] = e->seq; gens[n] = e->gen;
        dzp_tail++; n++;
    }
    return n;
}

long dz_probe_pending(void) { return dzp_head - dzp_tail; }
long dz_probe_faults(void) { return dzp_faults; }
long dz_probe_dropped(void) { return dzp_dropped; }
