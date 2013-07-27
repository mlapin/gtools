#!/usr/bin/gawk -f
#
# Shows aggregate counts of jobs/tasks over all users
function report(total, count, title, flag, dat) {
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
    printf("%s%s (%d):%s\n", fbold, title, total, fnorm);
    for (i = n; i >= 1; i--) {
      split(sorted[i], row, SUBSEP)
      if (flag == 1) {
        printf("%7d %-10s %s\n", row[3], row[2], row[1]);
      } else if (flag == 2) {
        printf("%7d %-10s %4.1f%%\n", row[1], row[2], 100*row[1]/total);
      } else {
        printf("%7d %-10s\n", row[1], row[2]);
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
{
  if ($5 ~ /r|t/) {
    r_count[$4]++;
    r_total++;
  } else if ($5 ~ /E/) {
    e_count[$4]++;
    e_total++;
  } else if ($5 ~ /w|h|Rq/) {
    if (w_total == 0 || w_prio[$4] < $2) {
      w_prio[$4] = $2;
    }
    w_count[$4]++;
    w_total++;
  } else {
    o_count[$4]++;
    o_total++;
  }
}
END {
  report(r_total, r_count, "Running tasks", 2);
  report(w_total, w_count, "Pending jobs", 1, w_prio);
  report(e_total, e_count, "Failed jobs");
  report(o_total, o_count, "Other jobs");
}
