#!/bin/bash
#
# Submit a single command
set -e

cmd_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--retry|--resub|--attempt*)
      shift
      MAX_ATTEMPTS="$1"
      ;;
    --)
      shift
      break
      ;;
    *)
      cmd_args+=("$1")
      ;;
  esac
  shift
done

if [[ ${#cmd_args[@]} -eq 0 ]] ; then
  exit 0
fi

qsubmit -N "${cmd_args[0]}" ${QSUB_OPT} "$@" -b y \
"${LOCAL_DIR}/grun-cmd.sh" ${MAX_ATTEMPTS} "${cmd_args[@]}"
