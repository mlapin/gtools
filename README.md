Grid Engine tools
=================

'gt' is a collection of tools that make certain tasks easier when working
with the (Sun/Oracle) Grid Engine.

The common tasks include submitting a single command or a batch of commands,
checking jobs' status, and rescheduling or removing failed jobs.

For example, the 'gt' wrapper script checks the exit code of every submitted
command and if it has failed (i.e. returned a nonzero code)
the corresponding job/task will be either automatically rescheduled to re-try
or put into error state for the user to see it in the qstat output.

You can learn more about individual 'gt' commands with "gt help <command>".

Status
------
Development in progress.

Installation (GNU/Linux)
------------------------
Clone the repository:
```
git clone https://github.com/mlapin/gtools.git
```

Then either add the `gtools` folder to $PATH or create a link to `gt`
in your local bin (which should be already in $PATH):
```
ln -s /path/to/gtools/gt
```
