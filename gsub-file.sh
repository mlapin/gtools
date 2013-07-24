#!/bin/bash
#
# Submit a set of commands listed in a file
set -e

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--group*|--step*)
      shift
      step="$1"
      ;;
    -r|--retry|--resub|--attempt*)
      shift
      MAX_ATTEMPTS="$1"
      ;;
    *)
      break
      ;;
  esac
  shift
done

if [[ $# -eq 0 ]] ; then
  exit 0
fi

step="${step:-1}"
cmd_file="${cmd_file:-$1}"
cmd_name="${cmd_file##*/}"

shift

if [[ "$1" = "--" ]] ; then
  shift
fi

if  [[ ! -e "${cmd_file}" ]] ; then
  echo "'${cmd_file}' does not exist." 1>&2
  exit 1
fi

if  [[ ! -r "${cmd_file}" ]] ; then
  echo "'${cmd_file}' is not readable." 1>&2
  exit 1
fi

if  [[ ! -s "${cmd_file}" ]] ; then
  echo "'${cmd_file}' is empty."
  exit 0
fi

if ! echo "${cmd_file}" | grep -q ^/ ; then
  cmd_file="${PWD}/${cmd_file}"
fi

total=$(wc -l "${cmd_file}" | cut -f1 -d' ')

qsubmit -N "${cmd_name}" ${QSUB_OPT} -t "1-${total}:${step}" "$@" -b y \
"${LOCAL_DIR}/grun-file.sh" "${cmd_file}" "${step}" "${MAX_ATTEMPTS}"
