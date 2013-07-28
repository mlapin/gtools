#!/usr/bin/gawk -f
#
# Show aggregate counts of jobs/tasks over all users
function report(total, count, title, color, flag, dat) {
  if (total > 0) {
    # Create a tmp multidimensional array for sorting by key
    delete data
    for (name in count) {
      if (flag == 1) {
        data[dat[name], name, count[name]] = 0
      } else {
        data[sprintf("%20s", count[name]), name] = 0
      }
    }
    n = asorti(data, sorted);
    printf("%s%s%s (%d)%s:%s\n",
      color, FONT_UL_ON, title, total, FONT_UL_OFF, FONT_NORM);
    for (i = n; i >= 1; i--) {
      split(sorted[i], row, SUBSEP)
      if (flag == 1) {
        printf("%7d %-12s %.5f\n", row[3], row[2], row[1]);
      } else if (flag == 2) {
        printf("%7d %-12s %4.1f%%\n", row[1], row[2], 100*row[1]/total);
      } else {
        printf("%7d %-12s\n", row[1], row[2]);
      }
    }
    print ""
  }
}
BEGIN {
  r_total = 0;
  w_total = 0;
  e_total = 0;
  o_total = 0;
}
NR > 2 {
  # any field after $2 is not safe since job names may contain spaces
  user = substr($0, 28, 12)
  stat = substr($0, 41, 5);
  if (stat ~ STAT_RUNNING) {
    r_count[user]++;
    r_total++;
  } else if (stat ~ STAT_ERROR) {
    e_count[user]++;
    e_total++;
  } else if (stat ~ STAT_WAITING) {
    if (w_total == 0 || w_prio[user] < $2) {
      w_prio[user] = $2;
    }
    w_count[user]++;
    w_total++;
  } else {
    o_count[user]++;
    o_total++;
  }
}
END {
  report(r_total, r_count, "Running jobs", FONT_GREEN, 2);
  report(w_total, w_count, "Pending jobs", FONT_YELLOW, 1, w_prio);
  report(e_total, e_count, "Failed jobs", FONT_RED);
  report(o_total, o_count, "Other jobs", FONT_BLUE);
}
