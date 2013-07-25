#!/bin/bash
#
# Submits grid engine jobs
set -e
set -o pipefail
GT_NAME="${0##*/}"

# Enable debug mode
if [[ -n "${DEBUG}" ]]; then
  set -x
fi

usage() {
  cat <<EOF
usage: ${GT_NAME} [--version] [--help] [--config <path>] [--dry-run] [--verbose]
          <command> [<args>]

Commands:
   init       Create a config file
   cmd        Submit a single command
   file       Submit a set of commands listed in a file

See '${GT_NAME} help <command>' for more information on a specific command.
EOF
}

unknown_command() {
  echo "${GT_NAME}: '$1' is not a ${GT_NAME} command. \
See '${GT_NAME} --help'." 1>&2
}

help() {
  case "$1" in
    '')
      usage
      ;;
    gt*)
      man "${MAN_DIR}/gt.1"
      ;;
    *)
      if [[ -e "${MAN_DIR}/gt-$1.1" ]]; then
        man "${MAN_DIR}/gt-$1.1"
        break
      else
        unknown_command "$1"
        exit 1
      fi
      ;;
  esac
}

main() {
  if [[ -z "$1" ]]; then
    usage
    exit 1
  fi

  abspath="$(readlink -f "$0")"
  LOCAL_DIR="${abspath%/*}" # used in the setup script
  . "${LOCAL_DIR}/gt-setup.sh"

  read_config "$@"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        echo "${GT_NAME}: gtools version ${VERSION}"
        break
        ;;
      --help|help)
        shift
        help "$@"
        break
        ;;
      --conf*)
        shift
        CONFIG_FILE="$1"
        read_config "$@" # re-read the config
        ;;
      --dry*)
        DRY_RUN=1
        ;;
      --verbose)
        VERBOSE=1
        ;;
      *)
        if [[ -e "${LOCAL_DIR}/gt-$1.sh" ]]; then
          local cmd="$1"
          shift
          verbose "executing: ${LOCAL_DIR}/gt-${cmd}.sh"
          . "${LOCAL_DIR}/gt-${cmd}.sh" "$@"
          break
        else
          unknown_command "$1"
          exit 1
        fi
        ;;
    esac
    shift
  done
}

main "$@"
