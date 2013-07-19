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

failed=
TID=${TID:-${SGE_TASK_ID}}
while read line; do
  eval "$line" || {
    if [[ -z ${failed} ]] ; then
      # lazy initialization
      failed=1
      abspath="$(readlink -f "$0")"
      LOCAL_DIR="${abspath%/*}" # used in the setup script
      . "${LOCAL_DIR}/gtools-setup.sh"
    fi
    command_failed "$line"
    exit "$?"
  }
  TID=$((TID+1))
done < <(tail -n +"${SGE_TASK_ID}" "${cmd_file}" | head -n "${step}")
