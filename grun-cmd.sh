#!/bin/bash
#$ -S /bin/bash
#
# Execute a command
set -e
set -o pipefail

. "$1/gt-setup.sh"

MAX_ATTEMPTS="$2"
shift 2

trap 'log_signal HUP' HUP
trap 'log_signal INT' INT
trap 'log_signal TERM' TERM
trap 'log_signal USR1' USR1
trap 'log_signal USR2' USR2
trap 'log_signal XCPU' XCPU
trap 'log_signal XFSZ' XFSZ

( eval "${@}" ) || command_failed "${@}"
