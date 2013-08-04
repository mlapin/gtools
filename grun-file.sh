#!/bin/bash
#$ -S /bin/bash
#
# Execute commands from a file
set -e
set -o pipefail

. "$1/gt-setup.sh"

MAX_ATTEMPTS="$2"
step="$3"
cmd_file="$4"
shift 4

trap 'log_signal HUP' HUP
trap 'log_signal INT' INT
trap 'log_signal TERM' TERM
trap 'log_signal USR1' USR1
trap 'log_signal USR2' USR2
trap 'log_signal XCPU' XCPU
trap 'log_signal XFSZ' XFSZ

msg="file \`${cmd_file}', line(s) ${SGE_TASK_ID}-$((${SGE_TASK_ID}+${step}-1))"

tail -n +"${SGE_TASK_ID}" "${cmd_file}" \
  | head -n "${step}" \
  | /bin/bash -e -o pipefail \
  || command_failed "${msg}"
