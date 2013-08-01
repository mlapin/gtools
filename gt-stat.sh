#!/bin/bash
#
# Show the status of Grid Engine jobs and queues
set -e
set -o pipefail
name="${GT_NAME}-stat"

usage() {
  cat <<EOF
usage: ${GT_NAME} stat [--help] [<command> [options] | <qstat options>]

Commands:
    my        Show detailed user jobs summary (default)
    all       Show cluster summary over all users

\`my' options:
    -r        display the requested resources (default)
    -w        display the working directory

\`all' options:
    -s        skip the cluster summary at the end

See \`man qstat' for qstat options.
EOF
}

show_my() {
  SHOW_FIELD='res'
  while getopts ":rw" opt; do
    case "${opt}" in
      r) SHOW_FIELD='res' ;;
      w) SHOW_FIELD='cwd' ;;
      \?) echo "${name}: unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
  done
  shift $((${OPTIND}-1))

  # Collect user job ids, count running tasks, and group jobs by status
  myjobs=$(get_my_jobs)
  verbose "${myjobs}"

  # Exit if there are no submitted jobs
  if [[ -z "${myjobs}" ]]; then
    echo "${name}: ${USER} has no submitted jobs"
    echo "  (use \`${GT_NAME} help cmd' or \`${GT_NAME} help file' to learn \
how to submit a job)"
    exit 0
  fi

  # Get the list of job ids from the first line
  read -r jobids <<< "${myjobs}"

  # Collect and display formatted job details
  show_my_details

  # Show suggestions if there are failed jobs
  if [[ "${myjobs}" =~ .*error.* ]]; then
    echo "  (use \`${GT_NAME} resub' to resubmit failed jobs \
once the problem is fixed)"
    echo "  (use \`${GT_NAME} del' to delete failed jobs)"
  fi
}

get_my_jobs() {
  qstatus -u "${USER}" \
    | gawk \
    'function print_sorted(jobs, title) {
      print title
      n = asorti(jobs, sorted)
      for (i = n; i >= 1; i--) print jobs[sorted[i]]
    }
    NR <= 2 { next }
    { t = r + e + w
      status = substr($0, 41, 5)
      common = substr($0, 1, 16) status
      rest = substr($0, 104) }
    status ~ '"${STAT_RUNNING}"' { r++; rc[$1]++; rj[$1] = common rc[$1] }
    status ~ '"${STAT_ERROR}"' { e++; ej[$1] = common rest }
    status ~ '"${STAT_WAITING}"' { w++; wj[$1] = common rest }
    t == r + e + w { o++; oj[$1] = common rest }
    END {
      if (r) for (j in rj) printf("%d,", j)
      if (w) for (j in wj) printf("%d,", j)
      if (e) for (j in ej) printf("%d,", j)
      if (o) for (j in oj) printf("%d,", j)
      if (r + w + e + o > 0) print ""
      if (r) print_sorted(rj, "running")
      if (w) print_sorted(wj, "waiting")
      if (e) print_sorted(ej, "error")
      if (o) print_sorted(oj, "other")
    }'
}

show_my_details() {
  details=$(qstatus -j "${jobids}")
  gawk \
    'function print_title(title, color) {
      printf("%s'"${FONT_UL_ON}"'%s'"${FONT_UL_OFF}:${FONT_NORM}"'\n",
        color, title)
    }
    /^job_number:/ { job = $2 }
    /^submission_time:/ { time[job] = substr($0, 29) }
    /^cwd:/ { cwd[job] = substr($0, 29) }
    /^hard resource_list:/ { res[job] = substr($0, 29) }
    /^job_name:/ { name[job] = substr($0, 29) }
    /^job-array tasks:/ { tasks[job] = substr($0, 29) }
    /^<<<end>>>$/ { report = 1 }
    /^running$/ { print_title("Running jobs", "'"${FONT_GREEN}"'") }
    /^waiting$/ { print_title("Pending jobs", "'"${FONT_YELLOW}"'") }
    /^error$/ { print_title("Failed jobs", "'"${FONT_RED}"'") }
    /^other$/ { print_title("Other jobs", "'"${FONT_BLUE}"'") }
    /^[0-9]+ / { if (report) {
      printf("%s %s %-5s %10s `'"${FONT_BOLD}"'%s'"${FONT_NORM}'"' %s\n",
        $1, $2, $3, tasks[$1], name[$1], $4);
      printf("%7s %s %s\n", "", time[$1], '"${SHOW_FIELD}"'[$1]);
      print ""
    }}' <<< "${details}"$'\n<<<end>>>\n'"${myjobs}"
}

show_all() {
  while getopts ":s" opt; do
    case "${opt}" in
      s) SKIP_SUMMARY=1 ;;
      \?) echo "${name}: unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
  done
  shift $((${OPTIND}-1))

  # Display job/task counts over all users grouped by job status
  # (a temporary multidimensional array is created for sorting by key)
  qstatus -u '*' \
    | gawk \
    'function report(total, count, title, color, report_type, prio) {
      if (total > 0) {
        delete data
        for (user in count) {
          if (report_type == 2)
            data[prio[user], user, count[user]] = 0
          else
            data[sprintf("%20s", count[user]), user] = 0
        }
        n = asorti(data, sorted);
        printf("%s'"${FONT_UL_ON}"'%s (%d)'"${FONT_UL_OFF}:${FONT_NORM}"'\n",
          color, title, total)
        for (i = n; i >= 1; i--) {
          split(sorted[i], row, SUBSEP)
          if (report_type == 2)
            printf("%7d %-12s %.5f\n", row[3], row[2], row[1]);
          else if (report_type == 1)
            printf("%7d %-12s %4.1f%%\n", row[1], row[2], 100*row[1]/total);
          else
            printf("%7d %-12s\n", row[1], row[2]);
        }
        print ""
      }
    }
    NR <= 2 { next }
    { t = r + e + w
      user = substr($0, 28, 12)
      status = substr($0, 41, 5) }
    status ~ '"${STAT_RUNNING}"' { r++; rc[user]++ }
    status ~ '"${STAT_ERROR}"' { e++; ec[user]++ }
    status ~ '"${STAT_WAITING}"' { w++; wc[user]++
      if (w == 1 || wp[user] < $2) wp[user] = $2
    }
    t == r + e + w { o++; oc[user]++ }
    END {
      report(r, rc, "Running jobs", "'"${FONT_GREEN}"'", 1)
      report(w, wc, "Pending jobs", "'"${FONT_YELLOW}"'", 2, wp)
      report(e, ec, "Failed jobs", "'"${FONT_RED}"'")
      report(o, oc, "Other jobs", "'"${FONT_BLUE}"'")
    }'

  # Display overall cluster summary
  if [[ -z "${SKIP_SUMMARY}" ]]; then
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
