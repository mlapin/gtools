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

# Path to the scratch folder (temporary storage)
SCRATCH_DIR="${SCRATCH_DIR:-"/scratch/BS/pool1/.gtools"}"

# Path to the folder with the gtools scripts
LOCAL_DIR="${LOCAL_DIR:-"${0%/*}"}"

# Path to the manuals
MAN_DIR="${LOCAL_DIR:-"$PWD"}/man"

# Submit host and hooks
SUBMIT_HOST="${SUBMIT_HOST:-"submit-squeeze"}"
PRE_HOOK="${PRE_HOOK:-"source /n1_grid/current/inf/common/settings.sh"}"

################################################################################

# Return codes that trigger special handling by the grid engine
RET_RESUB="${RET_RESUB:-99}"
RET_STOP="${RET_STOP:-100}"

# Timeout delays
TIMEOUT_OFFSET=10 # subtract this amount (seconds) from the actual timeout
TIMEOUT_KILL_DELAY=1 # wait this amount (seconds) before sending KILL

# Job and task IDs
JOB_ID="${JOB_ID:-1}"
SGE_TASK_ID="${SGE_TASK_ID:-1}"
TID="${TID:-${SGE_TASK_ID}}"


qsubmit() {
  JOB_ID=$(run_on_submit_host qsub -b y -terse "$@" |
    sed -n -e 's/^\([0-9]\+\).*/\1/p') && echo "${JOB_ID}"
  update_meta
}

update_meta() {
  TIMEOUT=$(run_on_submit_host qstat -j "${JOB_ID}" |
    sed -n -e 's/^hard resource_list:.*h_rt=\([0-9]\+\).*/\1/p')
  TIMEOUT=$((TIMEOUT-TIMEOUT_OFFSET))
  if [[ ${TIMEOUT} -le 0 ]]; then
    TIMEOUT=${TIMEOUT_OFFSET}
  fi
  mkdir -p "${SCRATCH_DIR}/${JOB_ID}"
  echo "${TIMEOUT}" > "${SCRATCH_DIR}/${JOB_ID}/.meta"
}

read_meta() {
  TIMEOUT=$(<"${SCRATCH_DIR}/${JOB_ID}/.meta")
}

run_on_submit_host() {
  # If there is no qsub, ssh to a submit host and run there
  command -v qsub >/dev/null && "$@" || {
    local cmd
    cmd=$(printf " %q" "$@")
    ssh -x "${SUBMIT_HOST}" "${PRE_HOOK} && ${cmd}"
  }
}

log_error() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S") ${JOB_ID}.${TID}] $@" 1>&2
}

command_failed() {
  # Append a dot to the job/task file, then check its size
  # to decide whether to stop or retry
  if [[ $? -eq 124 ]]; then
    log_error "TIMEOUT (${TIMEOUT})"
  fi
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
