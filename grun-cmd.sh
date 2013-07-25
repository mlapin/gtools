#!/bin/bash
#
# Executes a command
set -e
set -o pipefail

. "${0%/*}/gt-setup.sh"

MAX_ATTEMPTS="$1"
shift

read_meta

timeout -k "${TIMEOUT_KILL_DELAY}" "${TIMEOUT}" "${@}" || {
  command_failed "$@"
  exit "$?"
}
