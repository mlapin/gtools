#!/bin/bash
#
# Define common constants, functions, and default values
set -e
set -o pipefail
readonly VERSION=0.1

################################################################################
#
# Custom options (edit here)
#

# Default qsub options (see 'man qsub')
if [[ -z "${QSUB_OPT}" ]]; then
  QSUB_OPT=(-notify -r y -V -l h_rt=14400,h_vmem=6G,mem_free=1G)
fi

# Maximum number of attempts to execute a command
# (default is 2, i.e. resubmit once in case of failure)
MAX_ATTEMPTS="${MAX_ATTEMPTS:-2}"

# Path to the config file
CONFIG_FILE="${CONFIG_FILE:-"$HOME/.gtrc"}"

# Path to the scratch folder (temporary storage)
SCRATCH_DIR="${SCRATCH_DIR:-"/scratch/BS/pool1/.gtools"}"

# Path to the folder with the gtools scripts
LOCAL_DIR="${LOCAL_DIR:-"${0%/*}"}"

# Path to the manuals
MAN_DIR="${LOCAL_DIR:-"$PWD"}/man"

# Grid engine commands and hooks
DEL_CMD="${DEL_CMD:-"qdel"}"
MOD_CMD="${MOD_CMD:-"qmod"}"
STAT_CMD="${STAT_CMD:-"qstat"}"
SUBMIT_CMD="${SUBMIT_CMD:-"qsub"}"
SUBMIT_HOST="${SUBMIT_HOST:-"submit-squeeze"}"
PRE_HOOK="${PRE_HOOK:-"source /n1_grid/current/inf/common/settings.sh"}"

################################################################################

# Return codes that trigger special handling by the grid engine
RET_RESUB="${RET_RESUB:-99}"
RET_STOP="${RET_STOP:-100}"

# Timeout delays (allows the wrapper script to exit gracefully)
TIMEOUT_OFFSET=10 # subtract this amount (in seconds) from the actual timeout
TIMEOUT_KILL_DELAY=1 # wait this amount (seconds) before sending KILL

# Job statuses (regex for matching qstat output in gawk)
STAT_RUNNING="${STAT_RUNNING:-"/[rt]/"}"
STAT_WAITING="${STAT_WAITING:-"/[hw]/"}"
STAT_ERROR="${STAT_ERROR:-"/[E]/"}"

# Job and task IDs
JOB_ID="${JOB_ID:-1}"
SGE_TASK_ID="${SGE_TASK_ID:-1}"
TID="${TID:-${SGE_TASK_ID}}"


qsubmit() {
  if [[ -n "${VERBOSE}" || -n "${DRY_RUN}" ]]; then
    echo "${SUBMIT_CMD}" -b y -terse "$@" 1>&2
  fi
  JOB_ID=$(run_on_submit_host "${SUBMIT_CMD}" -b y -terse "$@" |
    sed -n -e 's/^\([0-9]\+\).*/\1/p')
  verbose "job id: ${JOB_ID}"
  update_meta
  echo "${JOB_ID}"
}

qstatus() {
  if [[ -n "${VERBOSE}" || -n "${DRY_RUN}" ]]; then
    echo "${STAT_CMD}" "$@" 1>&2
  fi
  run_on_submit_host "${STAT_CMD}" "$@"
}

qresubmit() {
  if [[ -n "${VERBOSE}" || -n "${DRY_RUN}" ]]; then
    echo "${MOD_CMD}" -cj "$@" 1>&2
  fi
  run_on_submit_host "${MOD_CMD}" -cj "$@"
}

qdelete() {
  if [[ -n "${VERBOSE}" || -n "${DRY_RUN}" ]]; then
    echo "${DEL_CMD}" "$@" 1>&2
  fi
  run_on_submit_host "${DEL_CMD}" "$@"
}

update_meta() {
  TIMEOUT=$(run_on_submit_host "${STAT_CMD}" -j "${JOB_ID}" |
    sed -n -e 's/^hard resource_list:.*h_rt=\([0-9]\+\).*/\1/p')
  verbose "timeout (${STAT_CMD}): ${TIMEOUT}"
  TIMEOUT=$((${TIMEOUT}-${TIMEOUT_OFFSET}))
  if [[ ${TIMEOUT} -le 0 ]]; then
    TIMEOUT=${TIMEOUT_OFFSET}
  fi
  verbose "timeout (adjusted): ${TIMEOUT}"
  mkdir -p "${SCRATCH_DIR}/${JOB_ID}"
  echo "${TIMEOUT}" > "${SCRATCH_DIR}/${JOB_ID}/.meta"
}

read_meta() {
  TIMEOUT=$(<"${SCRATCH_DIR}/${JOB_ID}/.meta")
}

read_config() {
  if [[ -s "${CONFIG_FILE}" ]]; then
    . "${CONFIG_FILE}" "$@"
    verbose "loaded config: ${CONFIG_FILE}"
  else
    verbose "config file is empty or does not exist: ${CONFIG_FILE}"
  fi
}

update_qsub_opt() {
  local custom_opt=
  if [[ -n "${RES_TIME}" ]]; then
    custom_opt="${custom_opt},h_rt=${RES_TIME}"
  fi
  if [[ -n "${RES_VMEMORY}" ]]; then
    custom_opt="${custom_opt},h_vmem=${RES_VMEMORY}"
  fi
  if [[ -n "${RES_MEMORY}" ]]; then
    custom_opt="${custom_opt},mem_free=${RES_MEMORY}"
  fi
  if [[ -n "${custom_opt}" ]]; then
    QSUB_OPT+=(-l "${custom_opt:1}")
  fi
  QSUB_OPT+=("$@")
}

run_on_submit_host() {
  if [[ -n "${DRY_RUN}" ]]; then
    echo "dry run: command not executed." 1>&2
    exit 1
  else
    # If there is no qsub, ssh to a submit host and run there
    command -v "${SUBMIT_CMD}" >/dev/null && "$@" || {
      local cmd
      cmd=$(printf " %q" "$@")
      ssh -x "${SUBMIT_HOST}" "${PRE_HOOK} && ${cmd}"
    }
  fi
}

command_failed() {
  # Append a dot to the job/task file, then check its size
  # to decide whether to stop or retry
  if [[ $? -eq 124 ]]; then
    log_error "TIMEOUT (${TIMEOUT} seconds)"
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

log_error() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S") ${JOB_ID}.${TID}] $@" 1>&2
}

verbose() {
  if [[ -n "${VERBOSE}" ]]; then
    echo "$1" 1>&2
    if [[ $# -gt 1 ]]; then
      print_args "${@:2}"
    fi
  fi
}

print_args() {
  for i in "$@"; do echo "  [$i]" 1>&2; done
}
