#!/bin/bash
#
# Shows the status of grid engine jobs and queues
set -e
name="${GT_NAME}-st"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] [<command> [options] | <qstat options>]

Commands:
    my        Show detailed user jobs summary (default)
    all       Show cluster summary over all users

\`my' options:
    -s        display the output in the short format (one line per job)
    -r        display the requested resources (default)
    -d        display the working directory

\`all' options:
    -s        display the output in the short format (no cluster summary)

See \`man qstat' for qstat options.
EOF
}

show_my() {
  SHOW_DETAILS=1    # whether to show details or not
  SHOW_FIELD='res'  # which field to show in details
  while getopts ":srd" opt; do
    case "${opt}" in
      s) SHOW_DETAILS=0 ;;
      r) SHOW_FIELD='res' ;;
      d) SHOW_FIELD='cwd' ;;
      \?) echo "${name}: unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
  done
  shift $((${OPTIND}-1))

  # Collect user job ids, count running tasks, and group jobs by status
  myjobs=$(get_my_jobs)
  verbose "${myjobs}"

  # Exit if there are no submitted jobs
  if [[ -z "${myjobs}" ]]; then
    echo "${name}: no submitted jobs"
    echo "  (use \`${GT_NAME} help cmd' or \`${GT_NAME} help file' to learn \
how to submit a job)"

    # Remove temporary metadata files created for previous jobs (user specific)
    if [[ -n "${AUTO_CLEANUP}" ]]; then
      cleanup_metadata || exit 1
    fi

    exit 0
  fi

  # Get the list of job ids from the first line
  read -r jobids <<< "${myjobs}"

  # Collect and display formatted job details
  show_my_details

  # Show suggestions if there are failed jobs
  if [[ "${myjobs}" =~ .*error.* ]]; then
    echo "  (use \`${GT_NAME} re' to reschedule failed jobs \
once the problem is fixed)"
    echo "  (use \`${GT_NAME} rm' to remove failed jobs)"
  fi
}

get_my_jobs() {
  qstatus -u "${USER}" \
    | gawk \
    'function print_sorted(jobs, title) {
      print title
      n = asorti(jobs, sorted)
      for (i = 1; i <= n; i++) print jobs[sorted[i]]
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
  # Use the short string format unless (more) details have been requested
  local sfmt='%.20s'
  if [[ ${SHOW_DETAILS} -eq 1 ]]; then
    sfmt='%s'
  fi

  # Display job details
  details=$(qstatus -j "${jobids}")
  verbose "${details}"$'\n<<<end>>>\n'"${myjobs}"
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
    /^ +[0-9]+ / { if (report) {
      printf("%s %s %-5s %10s '"${FONT_BOLD} ${sfmt} ${FONT_NORM} ${sfmt}"'\n",
        $1, $2, $3, tasks[$1], name[$1], $4)
      if ('"${SHOW_DETAILS}"') {
        printf("%7s %s %s\n", "", time[$1], '"${SHOW_FIELD}"'[$1])
        print ""
      }
    }}' <<< "${details}"$'\n<<<end>>>\n'"${myjobs}"
}

show_all() {
  SHOW_DETAILS=1
  while getopts ":s" opt; do
    case "${opt}" in
      s) SHOW_DETAILS=0 ;;
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
      user = substr($0, 28, 12); gsub(/[ \t]+$/,"",user)
      status = substr($0, 41, 5); gsub(/[ \t]+$/,"",status)
      slots = substr($0, 102, 2); gsub(/[ \t]+$/,"",slots)
    }
    status ~ '"${STAT_RUNNING}"' { r=r+(slots); rc[user]=rc[user]+(slots) }
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
  if [[ ${SHOW_DETAILS} -eq 1 ]]; then
    qstatus -g c
  fi
}

main() {
  verbose "arguments (before parsing):" "$@"

  # Produce formatted output (colors, etc) if STDOUT is a terminal
  if [[ -t 1 ]]; then
    FONT_NORM=$(tput sgr0) #'\033[0m'
    FONT_BOLD=$(tput bold) #'\033[1m'
    FONT_UL_ON=$(tput smul) #'\033[4m'
    FONT_UL_OFF=$(tput rmul) #'\033[24m'
    FONT_RED=$(tput setaf 1) #'\033[31m'
    FONT_GREEN=$(tput setaf 2) #'\033[32m'
    FONT_YELLOW=$(tput setaf 3) #'\033[33m'
    FONT_BLUE=$(tput setaf 4) #'\033[34m'
  fi

  # Show current user jobs by default
  if [[ $# -eq 0 ]]; then
    show_my
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|help)
        show_help "st"
        break
        ;;
      my|me)
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
