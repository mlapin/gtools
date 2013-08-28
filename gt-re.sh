#!/bin/bash
#
# Reschedules failed jobs
set -e
name="${GT_NAME}-re"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] [all | <job_id> ...]
EOF
}

resub_all() {
  # Get job ids of failed jobs (in error state)
  myjobs=$(qstatus -u "${USER}" | gawk --re-interval '/^.{40,45}E/{print $1}')

  verbose "${myjobs}"

  if [[ -z "${myjobs}" ]]; then
    echo "${name}: no failed jobs to reschedule"
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
        show_help "re"
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
