#!/bin/bash
#
# Execute a command
set -e

. "${0%/*}/gtools-setup.sh"

MAX_ATTEMPTS="$1"
shift

read_meta

timeout -k "${TIMEOUT_KILL_DELAY}" "${TIMEOUT}" "${@}" || {
  command_failed "$@"
  exit "$?"
}
