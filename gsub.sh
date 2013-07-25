#!/bin/bash
#
# Submits grid engine jobs
set -e
name="${0##*/}"

usage() {
  cat <<EOF
usage: ${name} [--version] [--help] <command> [<args>]

Commands:
   cmd        Submit a single command
   file       Submit a set of commands listed in a file

See '${name} help <command>' for more information on a specific command.
EOF
}

unknown_command() {
  echo "${name}: '$1' is not a ${name} command. See '${name} --help'." 1>&2
  exit 1
}

help() {
  case "$1" in
    '')
      usage
      ;;
    gsub*)
      man "${MAN_DIR}/gsub.1"
      ;;
    cmd|command)
      man "${MAN_DIR}/gsub-cmd.1"
      ;;
    file)
      man "${MAN_DIR}/gsub-file.1"
      ;;
    *)
      unknown_command "$1"
      ;;
  esac
}


abspath="$(readlink -f "$0")"
LOCAL_DIR="${abspath%/*}" # used in the setup script
. "${LOCAL_DIR}/gtools-setup.sh"

if [[ -z "$1" ]]; then
  usage
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    cmd|command)
      shift
      . "${LOCAL_DIR}/gsub-cmd.sh" "$@"
      break
      ;;
    file)
      shift
      . "${LOCAL_DIR}/gsub-file.sh" "$@"
      break
      ;;
    help|--help|-h*)
      shift
      help "$@"
      break
      ;;
    --version)
      echo "${name}: gtools version $VERSION"
      break
      ;;
    *)
      unknown_command "$1"
      ;;
  esac
  shift
done
