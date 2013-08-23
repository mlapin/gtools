#!/bin/bash
#
# Deletes grid engine jobs
set -e
set -o pipefail
name="${GT_NAME}-rm"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] [all [-f] | failed | <job_id> ...]

    -f    do not prompt to confirm deletion of all user jobs
EOF
}

delete_all() {
  while getopts ":f" opt; do
    case "${opt}" in
      f) local force=1 ;;
      \?) echo "${name}: unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
  done
  shift $((${OPTIND}-1))

  if [[ -z "${force}" ]]; then
    read -p "Delete all ${USER}'s jobs (y/n)? " -n 1 -r
    echo
    if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
        echo "${name}: no jobs deleted"
        exit 0
    fi
  fi

  # Delete all user jobs
  qdelete -u "${USER}"
}

delete_failed() {
  # Get job ids of failed jobs (in error state)
  myjobs=$(qstatus -u "${USER}" | gawk --re-interval '/^.{40,45}E/{print $1}')

  verbose "${myjobs}"

  if [[ -z "${myjobs}" ]]; then
    echo "${name}: no failed jobs to delete"
    exit 0
  fi

  # Delete these jobs
  qdelete ${myjobs//\n/ } # no quotes, each job id is an argument
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ $# -eq 0 ]]; then
    delete_failed
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|help)
        show_help "del"
        break
        ;;
      all)
        shift
        delete_all "$@"
        break
        ;;
      fail*)
        shift
        delete_failed "$@"
        break
        ;;
      *)
        if [[ $# -eq 1 ]]; then
          qdelete ${1//,/ } # no quotes, each job id is an argument
        else
          qdelete "$@"
        fi
        break
        ;;
    esac
    shift
  done
}

main "$@"
