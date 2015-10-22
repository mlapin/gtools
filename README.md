Grid Engine Tools (gtools)
============================

`gtools` is a collection of bash / awk scripts that make your life [much]
easier when running thousands of jobs with a Sun Grid Engine (SGE).
And I really mean hundreds of thousands of jobs.

The three most important *features* are
- transparent `ssh` to a submit host;
- detection of failed jobs;
- running Matlab compiled code.

The first feature is important because every interaction with the SGE happens
via `qsub`/`qstat`/etc. commands that can only be run on a submit host.
`gtools` do that automatically, so that you can interact with the cluster
directly from your workstation at any time.

The second feature is probably the most important.
When running dozens of array jobs each containing tens or even hundreds of
tasks, it is almost inevitable that a few of those tasks will fail.
The problem is then how to identify and resubmit only these few failed tasks
rather than the whole array job.
`gtools` do that by detecting a non-zero exit code of a failed command
and returning a special exit code to the SGE cluster,
which puts that single task into an error state.

You get an overview of _running_ / _pending_ / _failed_ jobs by running
```
gt st
```
If you want to see which tasks failed, run
```
gt st -j <job_id>
```
And if you want to simply resubmit the failed tasks, just run
```
gt re
```

Finally, the third main feature enables one to run Matlab compiled code
like a normal binary by setting all the necessary environment variables
(you may need to configure that once to set the right path to the Matlab MCR).

There is a number of other features like grouping of tasks,
custom user options, automatic resubmition of failed jobs
(which is not recommended and may be removed in future releases),
setting resource limits more conveniently, etc.

Just try `gt` to see the list of commands and
`gt help <command>` to learn more about the given command.


Installation (GNU/Linux)
------------------------
- Clone the repository:
```
git clone https://github.com/mlapin/gtools.git
```

- Make sure the `gt` script is in your `$PATH`.

Hint: either add the `gtools` folder to your `$PATH` or
create a symlink to `gt` in a folder that is already in the `$PATH`, like so:
```
ln -s /path/to/gtools/gt
```

- Run `gt check` to see if everything has been setup correctly.


Troubleshooting
------------------------

- run `gt check -v`
- check `gt-setup.sh`
- create a user config (`gt config`) and modify it according to your needs.
