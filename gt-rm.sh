#!/bin/bash
#
# Removes grid engine jobs
set -e
name="${GT_NAME}-rm"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] [all [-f] | failed | <job_id>...]

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
    read -p "Remove all ${USER}'s jobs (y/n)? " -n 1 -r
    echo
    if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
        echo "${name}: no jobs removed"
        exit 0
    fi
  fi

  # Delete all user jobs
  qdelete -u "${USER}"
}

delete_failed() {
  # Get all user jobs that are in the error state and are not running
  local failed
  failed=$(qstatus -u "${USER}" \
    | gawk \
    'BEGIN { rj[""] = "" }
    NR <= 2 { next }
    { status = substr($0, 41, 5) }
    status ~ '"${STAT_RUNNING}"' { rj[$1] = $1 }
    status ~ '"${STAT_ERROR}"' && !($1 in rj) { print $1 }')

  verbose "${failed}"

  if [[ -z "${failed}" ]]; then
    echo "${name}: no failed jobs to remove"
    echo "  (failed jobs that are still running are excluded)"
    echo "  (use \`${name/-/ } <job_id>...' to delete specific jobs)"
    echo "  (use \`${name/-/ } all' to delete all user jobs)"
    exit 0
  fi

  # Delete these jobs
  qdelete ${failed//\n/ } # no quotes, each job id is an argument
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
