#!/usr/bin/gawk -f
#
# Show user job details grouped by job status
function print_title(title, color) {
  printf("%s%s%s%s:%s\n", color, FONT_UL_ON, title, FONT_UL_OFF, FONT_NORM);
}
/^job_number:/ { job = $2 }
/^submission_time:/ { time[job] = substr($0, 29) }
/^hard resource_list:/ { res[job] = substr($0, 29) }
/^job_name:/ { name[job] = substr($0, 29) }
/^job-array tasks:/ { tasks[job] = substr($0, 29) }
/^<<<end>>>$/ { report = 1 }
/^running$/ { print_title("Running jobs", FONT_GREEN) }
/^waiting$/ { print_title("Pending jobs", FONT_YELLOW) }
/^error$/ { print_title("Failed jobs", FONT_RED) }
/^other$/ { print_title("Other jobs", FONT_BLUE) }
/^[0-9]+ / {
  if (report) {
    printf("%s %s %-5s %10s `%s%s%s' %s\n",
      $1, $2, $3, tasks[$1], FONT_BOLD, name[$1], FONT_NORM, $4);
    printf("%7s %s %s\n", "", time[$1], res[$1]);
    print ""
  }
}
