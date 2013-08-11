#!/bin/bash
#$ -S /bin/bash
#
# Execute commands from a file
set -e
set -o pipefail

. "$1/gt-setup.sh"

MAX_ATTEMPTS="$2"
profile="$3"
step="$4"
cmd_file="$5"
shift 5

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
unset time
if [[ "${profile}" = "profile" ]]; then
  time="/usr/bin/time -v"
fi

msg="file \`${cmd_file}', line(s) ${SGE_TASK_ID}-$((${SGE_TASK_ID}+${step}-1))"

# Feed a portion of the commands file to bash
tail -n +"${SGE_TASK_ID}" "${cmd_file}" \
  | head -n "${step}" \
  | ${time} /bin/bash -e -o pipefail \
  || command_failed "${msg}"
