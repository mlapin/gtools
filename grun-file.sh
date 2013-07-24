#!/bin/bash
#
# Execute commands from a file
set -e

if [[ -z "${SGE_TASK_ID}" ]]; then
  echo '$SGE_TASK_ID is not set.'
  exit 1
fi

cmd_file="$1"
step="$2"
MAX_ATTEMPTS="$3"

tail -n +"${SGE_TASK_ID}" "${cmd_file}" | head -n "${step}" | /bin/bash -e || {
  abspath="$(readlink -f "$0")"
  LOCAL_DIR="${abspath%/*}" # used in the setup script
  . "${LOCAL_DIR}/gtools-setup.sh"
  command_failed \
"file '${cmd_file}', line(s) ${SGE_TASK_ID}--$((SGE_TASK_ID+step-1))"
  exit "$?"
}

