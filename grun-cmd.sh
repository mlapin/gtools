#!/bin/bash
#
# Execute a command
set -e

MAX_ATTEMPTS="$1"
shift

$@ || {
  abspath="$(readlink -f "$0")"
  LOCAL_DIR="${abspath%/*}" # used in the setup script
  . "${LOCAL_DIR}/gtools-setup.sh"
  command_failed "$@"
  exit "$?"
}
