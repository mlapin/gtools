#!/bin/bash
#$ -S /bin/bash
#
# Executes a command
set -e
set -o pipefail

. "$1/gt-setup.sh"

MAX_ATTEMPTS="$2"
timeit="$3"
shift 3

# Setup traps to report received signals
trap 'log_signal HUP' HUP
trap 'log_signal INT' INT
trap 'log_signal QUIT' QUIT
trap 'log_signal TERM' TERM
trap 'log_signal USR1' USR1
trap 'log_signal USR2' USR2
trap 'log_signal XCPU' XCPU
trap 'log_signal XFSZ' XFSZ

# Report resource usage if profiling is requested
unset timeit_cmd
if [[ "${timeit}" = "yes" ]]; then
  timeit_cmd="${TIMEIT_CMD}"
fi

# Execute the command via `eval' to enable variable substitution
# (e.g., one can use `\$JOB_ID' as an argument)
eval ${timeit_cmd} "$@" || command_failed "$@"
