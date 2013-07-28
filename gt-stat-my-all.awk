#!/usr/bin/gawk -f
#
# Show user job ids and job details grouped by job status
function print_jobs(total, jobs, title) {
  if (total > 0) {
    if (title) {
      print title
      for (job in jobs) {
        print jobs[job]
      }
    } else {
      for (job in jobs) {
        printf("%d,", job)
      }
    }
  }
}
BEGIN {
  r_total = 0;
  w_total = 0;
  e_total = 0;
  o_total = 0;
}
NR > 2 {
  stat = substr($0, 41, 5);
  if (stat ~ STAT_RUNNING) {
    r_count[$1]++;
    r_jobs[$1] = substr($0, 1, 16) stat r_count[$1];
    r_total++;
  } else if (stat ~ STAT_ERROR) {
    e_jobs[$1] = substr($0, 1, 16) stat substr($0, 104);
    e_total++;
  } else if (stat ~ STAT_WAITING) {
    w_jobs[$1] = substr($0, 1, 16) stat substr($0, 104);
    w_total++;
  } else {
    o_jobs[$1] = substr($0, 1, 16) stat substr($0, 104);
    o_total++;
  }
}
END {
  print_jobs(r_total, r_jobs);
  print_jobs(w_total, w_jobs);
  print_jobs(e_total, e_jobs);
  print_jobs(o_total, o_jobs);
  if (r_total > 0 || w_total > 0 || e_total > 0 || o_total > 0) {
    print ""
  }
  print_jobs(r_total, r_jobs, "running");
  print_jobs(w_total, w_jobs, "waiting");
  print_jobs(e_total, e_jobs, "error");
  print_jobs(o_total, o_jobs, "other");
}
