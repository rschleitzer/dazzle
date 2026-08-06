/* primprof.c — TEMPORARY measurement shim: per-PRIMITIVE time profile.
 *
 * Question it answers (tests/dazzle/PERFORMANCE.md, "Warum der Styling-Pfad
 * noch 1.4x braucht"): the leaf profile puts 93 % of the port's excess
 * instructions in the ENGINE, and inside the engine the outlier is not the
 * interpreter loop (2.2x) or the call path (2.3x) but "die Primitiven selbst"
 * at 1.72 G against the reference's 0.23 G — a factor of 7.5. That row is a
 * SUM over 226 primitives. Which of them holds it is unknown, and every time
 * this port has looked into such a row it found an algorithmic defect rather
 * than a constant factor (hashed id index, lazy pair node list, lazy
 * select-elements, element-number/NumberCache).
 *
 * Why not `sample`: the primitive bodies are INLINED into Primitive::dispatch
 * (that is the documented misdiagnosis of 2026-08-05 — the 201 leaf samples
 * under `dispatch` are the primitives, not dispatch overhead), so an external
 * profiler cannot separate them. Any per-call clock is worse: on Apple Silicon
 * mach_absolute_time costs 5.56 ns/call MEASURED and ticks at only 41.7 ns, so
 * bracketing calls that cost tens of nanoseconds would perturb more than it
 * resolves.
 *
 * Mechanism instead: the Scaly side publishes WHICH primitive is running into
 * one word (`pp_cur`, save/restore so a primitive that re-enters the
 * interpreter is charged its SELF time only), and an ITIMER_PROF signal at
 * 1 ms samples that word. Cost on the hot path: one store, one increment, one
 * store. The sampler is a true CPU-time profile and is immune to inlining,
 * because it reads the engine's own notion of what it is doing rather than the
 * program counter.
 *
 * Bucket 0 is "outside any primitive" — the interpreter loop, the call path
 * and everything a primitive triggers by re-entering the engine. It is
 * reported, so the primitive SHARE of the run is visible and comparable to the
 * 1.72 G row rather than being a ratio of a ratio.
 *
 * Not part of the port. Compiled into a measurement binary only, by
 * tests/dazzle/primprof/run.sh, never by build-cli.sh.
 */
#include <signal.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PP_MAX 256            /* ids run 0..231 today (226 defined) */
#define PP_SLOTS (PP_MAX + 1) /* slot i+1 is id i; slot 0 is "outside" */
#define PP_NAMELEN 56

static volatile sig_atomic_t pp_cur;      /* id + 1, 0 = outside a primitive */
static long pp_hist[PP_SLOTS];            /* samples, written by the handler */
static long pp_count[PP_SLOTS];           /* calls,   written by the engine   */
static char pp_name[PP_SLOTS][PP_NAMELEN];
static long pp_samples;
static long pp_overflow;                  /* ids outside the table, if any */
static long pp_period_usec = 1000;        /* the sample period, for ns/call */
static int  pp_on;

static void pp_report(void);

/* The handler touches only pp_hist/pp_samples, which nothing else writes, and
 * reads pp_cur, which is sig_atomic_t. The engine is strictly single-threaded
 * (measured: cpu == wall in every survey row), so no further discipline is
 * needed. */
static void pp_tick(int sig)
{
    (void)sig;
    pp_hist[(long)pp_cur]++;
    pp_samples++;
}

/* Enter a primitive: charge it a call, make it the current one, and hand back
 * the previous occupant so the exit can restore it. Save/restore is what makes
 * the number SELF time: `sort` running a comparator, or `apply` re-entering
 * the VM, spends that time in bucket 0 or in the inner primitive, not in
 * itself. */
long pp_enter(long id)
{
    long prev = (long)pp_cur;
    if (id < 0 || id >= PP_MAX) { pp_overflow++; return prev; }
    pp_count[id + 1]++;
    pp_cur = (sig_atomic_t)(id + 1);
    return prev;
}

void pp_exit(long prev)
{
    pp_cur = (sig_atomic_t)prev;
}

/* Called from Interpreter.install_primitive / install_x_primitive, so the
 * report can print names instead of ids. First name for an id wins (an id
 * installed twice under an alias keeps the primary spelling). */
void pp_name_id(const char *name, long id)
{
    if (id < 0 || id >= PP_MAX || name == 0) return;
    if (pp_name[id + 1][0]) return;
    strncpy(pp_name[id + 1], name, PP_NAMELEN - 1);
    pp_name[id + 1][PP_NAMELEN - 1] = 0;
}

/* Armed once, from install_primitives. Off unless DZ_PRIM_PROF=1, so the same
 * binary can be used for an unperturbed control run. */
void pp_start(void)
{
    const char *e = getenv("DZ_PRIM_PROF");
    long usec = 1000;
    const char *p;
    struct sigaction sa;
    struct itimerval it;

    if (!e || e[0] != '1' || pp_on) return;
    pp_on = 1;
    strcpy(pp_name[0], "(outside primitives)");

    p = getenv("DZ_PRIM_PROF_USEC");
    if (p && *p) { usec = atol(p); if (usec < 100) usec = 100; }
    pp_period_usec = usec;

    memset(&sa, 0, sizeof sa);
    sa.sa_handler = pp_tick;
    sa.sa_flags = SA_RESTART;   /* the engine does blocking I/O */
    sigemptyset(&sa.sa_mask);
    if (sigaction(SIGPROF, &sa, 0) != 0) { pp_on = 0; return; }

    it.it_interval.tv_sec = 0;
    it.it_interval.tv_usec = (int)usec;
    it.it_value = it.it_interval;
    if (setitimer(ITIMER_PROF, &it, 0) != 0) { pp_on = 0; return; }

    atexit(pp_report);
}

static void pp_report(void)
{
    long order[PP_SLOTS];
    long i, j, n = 0, calls = 0, prim_samples = 0;
    struct itimerval off;

    if (!pp_on) return;
    memset(&off, 0, sizeof off);
    setitimer(ITIMER_PROF, &off, 0);   /* no samples during the report */

    for (i = 0; i < PP_SLOTS; i++) {
        if (pp_hist[i] || pp_count[i]) order[n++] = i;
        if (i > 0) { calls += pp_count[i]; prim_samples += pp_hist[i]; }
    }
    /* selection sort, descending by samples then by calls — n is ~230 */
    for (i = 0; i < n; i++) {
        long best = i;
        for (j = i + 1; j < n; j++) {
            long a = order[j], b = order[best];
            if (pp_hist[a] > pp_hist[b] ||
                (pp_hist[a] == pp_hist[b] && pp_count[a] > pp_count[b])) best = j;
        }
        { long t = order[i]; order[i] = order[best]; order[best] = t; }
    }

    fprintf(stderr,
        "primprof: %ld samples (ITIMER_PROF), %ld primitive calls, "
        "%ld samples in primitives (%.1f %% of cpu)\n",
        pp_samples, calls, prim_samples,
        pp_samples ? 100.0 * prim_samples / pp_samples : 0.0);
    if (pp_overflow)
        fprintf(stderr, "primprof: %ld calls with an id outside 0..%d "
                        "(NOT profiled — widen PP_MAX)\n", pp_overflow, PP_MAX - 1);
    fprintf(stderr, "primprof: %8s %10s %14s %10s  %s\n",
            "cpu%", "samples", "calls", "ns/call", "primitive");
    for (i = 0; i < n; i++) {
        long s = order[i];
        double pct = pp_samples ? 100.0 * pp_hist[s] / pp_samples : 0.0;
        char id[16];
        const char *nm;
        /* one sample == the timer period; report it as ns spent per call */
        double nspc = pp_count[s]
            ? (double)pp_hist[s] * (double)pp_period_usec * 1000.0 / pp_count[s]
            : 0.0;
        snprintf(id, sizeof id, "#%ld", s - 1);
        nm = pp_name[s][0] ? pp_name[s] : id;
        /* every row that was entered or sampled is printed — a primitive with
         * many calls and no samples is a finding too (it is cheap), and a
         * truncated table reads as "that was all of them" */
        fprintf(stderr, "primprof: %7.2f%% %10ld %14ld %10.0f  %s\n",
                pct, pp_hist[s], pp_count[s], nspc, nm);
    }
    fflush(stderr);
}
