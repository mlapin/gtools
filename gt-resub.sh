#!/bin/bash
#
# Resubmit failed jobs
set -e
set -o pipefail
name="${GT_NAME}-resub"

usage() {
  cat <<EOF
usage: ${GT_NAME} resub [--help] [all | <job_id> ...]
EOF
}

resub_all() {
  # Get job ids of failed jobs (in error state)
  myjobs=$(qstatus -u "${USER}" | gawk --posix '/^.{40,45}E/{print $1}')

  verbose "${myjobs}"

  if [[ -z "${myjobs}" ]]; then
    echo "${name}: no failed jobs to resubmit"
    exit 0
  fi

  # Clear error state of these jobs (makes them eligible for rescheduling)
  qresubmit ${myjobs//\n/ } # no quotes, each job id is an argument
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ $# -eq 0 ]]; then
    resub_all
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|help)
        show_help "resub"
        break
        ;;
      all)
        shift
        resub_all "$@"
        break
        ;;
      *)
        if [[ $# -eq 1 ]]; then
          qresubmit ${1//,/ } # no quotes, each job id is an argument
        else
          qresubmit "$@"
        fi
        break
        ;;
    esac
    shift
  done
}

main "$@"
