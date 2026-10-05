# toolchain.sh -- which compiler, which tool and which runtime archive the
# tests use. Sourced by every script here, from the repository root:
#
#   . tests/toolchain.sh "${1:-}" || exit 2
#
#   SCALYC     the compiler; default: the `scalyc` on the PATH, that is an
#              installed Scaly (https://scaly.io)
#   SCALY      the tool (build, run, test) beside that compiler, named alike
#              but for the `c`: scaly beside scalyc, scaly_stage2 beside
#              scalyc_stage2; default: derived from SCALYC
#   LIBSCALY   the runtime archive a program is linked against; default:
#              lib/libscaly.a (libscaly.lib on a Windows shell) of the
#              installation that compiler belongs to
#
# Set them in the environment to test against a compiler built somewhere else.
# The one argument is the compiler a script was handed on its command line
# (always pass it, empty if there is none -- a bare `.` would see the CALLER's
# arguments): it replaces SCALYC, and the other two are then derived from it,
# because a tool and an archive given for another compiler say nothing about
# this one.
#
# All three are exported, so a script that starts another one (a suite calling
# tests/dazzle/build-cli.sh) hands its toolchain on without naming it again.
#
# The compiler finds the standard library in its installation and the packages
# of this repository in ./packages of the directory it runs in -- which is why
# everything here runs from the repository root.
if [ -n "${1:-}" ] && [ "$1" != "${SCALYC:-}" ]; then
  SCALYC=$1
  SCALY=
  LIBSCALY=
fi
if [ -z "${SCALYC:-}" ]; then
  SCALYC=$(command -v scalyc 2>/dev/null || true)
  if [ -z "$SCALYC" ]; then
    echo "no scalyc on the PATH: install Scaly (https://scaly.io) or set SCALYC" >&2
    return 2 2>/dev/null || exit 2
  fi
fi
if [ -z "${SCALY:-}" ]; then
  tc_dir=$(dirname "$SCALYC")
  tc_base=$(basename "$SCALYC")
  case "$tc_base" in
    scalyc*) tc_base="scaly${tc_base#scalyc}" ;;
  esac
  # a name that does not begin with `scalyc` has no sibling by this rule: it is
  # taken as given, and the first `scaly build` says what is missing
  SCALY=$tc_dir/$tc_base
fi
if [ -z "${LIBSCALY:-}" ]; then
  # an installation that says where it is, else <home>/libexec/scalyc, usually
  # reached through a link in <home>/../bin
  if [ -n "${SCALY_HOME:-}" ]; then
    tc_home=$SCALY_HOME
  else
    tc_real=$SCALYC
    while [ -L "$tc_real" ]; do
      tc_link=$(readlink "$tc_real")
      case "$tc_link" in
        /*) tc_real=$tc_link ;;
        *)  tc_real=$(dirname "$tc_real")/$tc_link ;;
      esac
    done
    tc_home=$(cd "$(dirname "$tc_real")/.." 2>/dev/null && pwd)
  fi
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) LIBSCALY=$tc_home/lib/libscaly.lib ;;
    *)                    LIBSCALY=$tc_home/lib/libscaly.a ;;
  esac
fi
export SCALYC SCALY LIBSCALY
