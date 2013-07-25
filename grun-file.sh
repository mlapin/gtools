#!/bin/bash
#
# Execute commands from a file
set -e

. "${0%/*}/gtools-setup.sh"

cmd_file="$1"
step="$2"
MAX_ATTEMPTS="$3"

read_meta

tail -n +"${SGE_TASK_ID}" "${cmd_file}" | head -n "${step}" | \
timeout -k "${TIMEOUT_KILL_DELAY}" "${TIMEOUT}" /bin/bash -e || {
  command_failed \
"file '${cmd_file}', line(s) ${SGE_TASK_ID}--$((SGE_TASK_ID+step-1))"
  exit "$?"
}
