#!/bin/bash
#
# Defines common constants, functions, and default values
set -e
readonly VERSION=0.1

################################################################################
#
# Custom options (edit here)
#

# Maximum number of attempts to (re-)submit a command
# (default is 2, i.e. resubmit once in case of failure)
MAX_ATTEMPTS="${MAX_ATTEMPTS:-2}"

# Default qsub options
QSUB_OPT="${QSUB_OPT:-"-notify -r y -V"}"

# Path to a scratch folder (temporary storage)
SCRATCH_DIR="${SCRATCH_DIR:-"/scratch/BS/pool1/.gtools"}"

# Path to manuals
MAN_DIR="${LOCAL_DIR:-$PWD}/man"

################################################################################


# Return codes that trigger special handling by the grid engine
RET_RESUB="${RET_RESUB:-99}"
RET_STOP="${RET_STOP:-100}"

# Job and task IDs
JOB_ID="${JOB_ID:-1}"
SGE_TASK_ID="${SGE_TASK_ID:-1}"
TID="${TID:-${SGE_TASK_ID}}"


qsubmit() {
  # If there is no qsub, ssh to a submit host and submit there
  command -v qsub >/dev/null && qsub "$@" || {
    local args
    args=$(printf " '%s'" "$@")
    ssh -x submit-squeeze \
      "source /n1_grid/current/inf/common/settings.sh && qsub $args"
  }
}

log_error() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S") ${JOB_ID}.${TID}] $@" 1>&2
}

command_failed() {
  # Append a dot to the job/task file, then check its size
  # to decide whether to stop or retry
  mkdir -p "${SCRATCH_DIR}/${JOB_ID}"
  printf '.' >> "${SCRATCH_DIR}/${JOB_ID}/${TID}"
  local attempts
  attempts=$(stat -c '%s' "${SCRATCH_DIR}/${JOB_ID}/${TID}")
  if [[ ${attempts} -lt ${MAX_ATTEMPTS} ]]; then
    log_error "Attempt ${attempts}/${MAX_ATTEMPTS} failed, RETRY: $@"
    exit ${RET_RESUB}
  else
    log_error "Attempt ${attempts}/${MAX_ATTEMPTS} failed, STOP: $@"
    exit ${RET_STOP}
  fi
}
