#!/bin/bash
#
# Shows the status of Grid Engine jobs and queues
set -e
set -o pipefail
name="${GT_NAME}-stat"

usage() {
  cat <<EOF
usage: ${GT_NAME} stat [--help] [<command> | <qstat options>]

Commands:
   my         Show detailed user jobs summary
   all        Show cluster summary (all users)

See 'man qstat' for qstat options.
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

  local fbold=$(tput bold)
  local fnorm=$(tput sgr0)

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|help)
        help "stat"
        exit 0
        ;;
      my)
        shift
        break
        ;;
      all)
        shift
        verbose "executing: ${LOCAL_DIR}/gt-stat-all.awk"
        qstatus -u '*' | tail -n +3 | gawk -f "${LOCAL_DIR}/gt-stat-all.awk" \
          -v fbold="${fbold}" -v fnorm="${fnorm}"
        qstatus -g c
        break
        ;;
      *)
        qstatus "$@"
        break
        ;;
    esac
    shift
  done
}

main "$@"
