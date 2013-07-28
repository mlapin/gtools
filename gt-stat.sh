#!/bin/bash
#
# Show the status of Grid Engine jobs and queues
set -e
set -o pipefail
name="${GT_NAME}-stat"

usage() {
  cat <<EOF
usage: ${GT_NAME} stat [--help] [<command> | <qstat options>]

Commands:
   my         Show detailed user jobs summary
   all        Show cluster summary (all users)

See \`man qstat' for qstat options.
EOF
}

show_my() {
  # 1st call to qstat (get an overview):
  # Collect user job ids, count running tasks, and group jobs by status
  verbose "executing: ${LOCAL_DIR}/gt-stat-my-all.awk"
  myjobs=$(qstatus -u "${USER}" \
    | gawk -f "${LOCAL_DIR}/gt-stat-my-all.awk" \
    -v STAT_RUNNING="${STAT_RUNNING}" -v STAT_WAITING="${STAT_WAITING}" \
    -v STAT_ERROR="${STAT_ERROR}")

  verbose "${myjobs}"

  if [[ -z "${myjobs}" ]]; then
    echo "${name}: ${USER} has no submitted jobs"
    echo "  (use \`${GT_NAME} help cmd' or \`${GT_NAME} help file' to learn \
how to submit a job)"
    exit 0
  fi

  # Get the list of job ids from the first line
  read -r jobids <<< "${myjobs}"

  # 2nd call to qstat (get job details): name, requested resources, etc.
  details=$(qstatus -j "${jobids}")

  # Parse qstat output and display formatted job details
  # Previous output is appended at the end
  verbose "executing: ${LOCAL_DIR}/gt-stat-my-details.awk"
  gawk -f "${LOCAL_DIR}/gt-stat-my-details.awk" \
    -v FONT_BOLD="${FONT_BOLD}" -v FONT_NORM="${FONT_NORM}" \
    -v FONT_UL_ON="${FONT_UL_ON}" -v FONT_UL_OFF="${FONT_UL_OFF}" \
    -v FONT_RED="${FONT_RED}" -v FONT_GREEN="${FONT_GREEN}" \
    -v FONT_YELLOW="${FONT_YELLOW}" -v FONT_BLUE="${FONT_BLUE}" \
    <<< "${details}"$'\n<<<end>>>\n'"${myjobs}"

  if [[ "${myjobs}" =~ .*error.* ]]; then
    echo "  (use \`${GT_NAME} resub' to resubmit failed jobs \
once the problem is fixed)"
    echo "  (use \`${GT_NAME} del' to delete failed jobs)"
  fi
}

show_all() {
  # Count jobs over all users grouped by status
  # Display formatted overview
  verbose "executing: ${LOCAL_DIR}/gt-stat-all.awk"
  qstatus -u '*' | gawk -f "${LOCAL_DIR}/gt-stat-all.awk" \
    -v STAT_RUNNING="${STAT_RUNNING}" -v STAT_WAITING="${STAT_WAITING}" \
    -v STAT_ERROR="${STAT_ERROR}" \
    -v FONT_BOLD="${FONT_BOLD}" -v FONT_NORM="${FONT_NORM}" \
    -v FONT_UL_ON="${FONT_UL_ON}" -v FONT_UL_OFF="${FONT_UL_OFF}" \
    -v FONT_RED="${FONT_RED}" -v FONT_GREEN="${FONT_GREEN}" \
    -v FONT_YELLOW="${FONT_YELLOW}" -v FONT_BLUE="${FONT_BLUE}"

  # Display overall cluster summary as well
  if [[ "$1" != '--no-summary' ]]; then
    qstatus -g c
  fi
}

main() {
  verbose "arguments (before parsing):" "$@"

  FONT_BOLD=$(tput bold)
  FONT_NORM=$(tput sgr0)
  FONT_UL_ON=$(tput smul)
  FONT_UL_OFF=$(tput rmul)
  FONT_RED=$(tput setaf 1)
  FONT_GREEN=$(tput setaf 2)
  FONT_YELLOW=$(tput setaf 3)
  FONT_BLUE=$(tput setaf 4)

  if [[ $# -eq 0 ]]; then
    show_my
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|help)
        show_help "stat"
        break
        ;;
      my)
        shift
        show_my "$@"
        break
        ;;
      all)
        shift
        show_all "$@"
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
