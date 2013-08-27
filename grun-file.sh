#!/bin/bash
#$ -S /bin/bash
#
# Executes commands from a file
set -e
set -o pipefail

. "$1/gt-setup.sh"

MAX_ATTEMPTS="$2"
timeit="$3"
matlab="$4"
step="$5"
cmd_file="$6"
shift 6

# Setup traps to report received signals
trap 'log_signal HUP' HUP
trap 'log_signal INT' INT
trap 'log_signal QUIT' QUIT
trap 'log_signal TERM' TERM
trap 'log_signal USR1' USR1
trap 'log_signal USR2' USR2
trap 'log_signal XCPU' XCPU
trap 'log_signal XFSZ' XFSZ

# Report resource usage (profiling)
unset timeit_cmd
if [[ "${timeit}" = "yes" ]]; then
  timeit_cmd="${TIMEIT_CMD}"
fi

# Setup MATLAB MCR
if [[ "${matlab}" = "yes" ]]; then
  TMPDIR="$(mktemp -d)"
  trap "rm -fr ${TMPDIR}" EXIT
  export LD_LIBRARY_PATH="${MCR_LD_LIBRARY_PATH}"
  export XAPPLRESDIR="${MCR_XAPPLRESDIR}"
  export MCR_CACHE_SIZE="${MCR_CACHE_SIZE}"
  export MCR_CACHE_ROOT="${TMPDIR}"
fi

msg="file \`${cmd_file}', line(s) ${SGE_TASK_ID}-$((${SGE_TASK_ID}+${step}-1))"

# Feed a portion of the commands file to bash
tail -n +"${SGE_TASK_ID}" "${cmd_file}" \
  | head -n "${step}" \
  | ${timeit_cmd} /bin/bash -e -o pipefail \
  || command_failed "${msg}"
