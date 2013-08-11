#!/bin/bash
#
# Define common constants, functions, and default values
set -e
set -o pipefail
unset VERSION
unset START_TIME
readonly VERSION=0.1
readonly START_TIME=$(date +%s%N)

################################################################################
#
# Custom options (edit here)
#

# Maximum number of attempts to execute a command
# (default is 2, i.e. resubmit once in case of failure)
MAX_ATTEMPTS="${MAX_ATTEMPTS:-2}"

# Default qsub options (see 'man qsub')
# These options are always included in the qsub command (before any other args)
if [[ -z "${QSUB_OPT}" ]]; then
  declare -a QSUB_OPT=(-cwd -V -r y -l h_rt=14400,h_vmem=4G,mem_free=1G)
fi

# Default user-defined qsub options (see 'man qsub')
# These options are activated via the '-u <option key>' parameter
if [[ -z "${USER_QSUB_OPT}" ]]; then
  declare -A USER_QSUB_OPT=( \
    [4h]='-l h_rt=4::' \
    [7d]='-l h_rt=168::' \
    [d2]='-l reserved=D2blade|D2compute|D2parallel' \
    )
fi

# Path to the config file
CONFIG_FILE="${CONFIG_FILE:-"$HOME/.gtrc"}"

# Path to the scratch folder (temporary metadata storage)
SCRATCH_DIR="${SCRATCH_DIR:-"/scratch/common/pool0/.gtools"}"

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
PRE_HOOK="${PRE_HOOK:-"cd '${PWD}' && \
source /n1_grid/current/inf/common/settings.sh"}"

# If not empty, automatically delete user files in the scratch folder
# when there are no user jobs in the cluster
AUTO_CLEANUP=1

# Show a notification message after specified number of seconds
# if an interactive command is taking longer to complete
NOTIFY_AFTER=1

################################################################################

# Return codes that trigger special handling by the grid engine
RET_RESUB="${RET_RESUB:-99}"
RET_STOP="${RET_STOP:-100}"

# Job statuses (regex for matching qstat output in gawk)
STAT_RUNNING="${STAT_RUNNING:-"/[rt]/"}"
STAT_WAITING="${STAT_WAITING:-"/^[Rhqw ]*$/"}"
STAT_ERROR="${STAT_ERROR:-"/[E]/"}"

# Job and task IDs
JOB_ID="${JOB_ID:-1}"
SGE_TASK_ID="${SGE_TASK_ID:-1}"
TID="${TID:-${SGE_TASK_ID}}"
if [[ "${TID}" = "undefined" ]]; then
  TID=1
fi


qsubmit() {
  JOB_ID=$(run_on_submit_host "${SUBMIT_CMD}" -notify -terse "$@" |
    sed -n -e 's/^\([0-9]\+\).*/\1/p')
  verbose "job id: ${JOB_ID}"
  echo "${JOB_ID}"
}

qstatus() {
  run_on_submit_host "${STAT_CMD}" "$@"
}

qresubmit() {
  run_on_submit_host "${MOD_CMD}" -cj "$@"
}

qdelete() {
  run_on_submit_host "${DEL_CMD}" "$@"
}

run_on_submit_host() {
  if [[ -n "${VERBOSE}" || -n "${DRY_RUN}" ]]; then
    echo "command to execute:" >&2
    verbose "$@"
  fi
  if [[ -n "${DRY_RUN}" ]]; then
    echo "dry run: command not executed." >&2
    exit 1
  else
    # If there is no qsub, ssh to a submit host and run there
    command -v "${SUBMIT_CMD}" >/dev/null && "$@" || {
      local cmd="$(printf ' %q' "$@")"
      verbose "ssh -x ${SUBMIT_HOST} ${PRE_HOOK} && ${cmd}"
      ssh -x "${SUBMIT_HOST}" "${PRE_HOOK} && ${cmd}"
    }
  fi
}

read_config() {
  if [[ -s "${CONFIG_FILE}" && -f "${CONFIG_FILE}" ]]; then
    . "${CONFIG_FILE}" "$@"
    verbose "loaded config: ${CONFIG_FILE}"
  else
    verbose "config file is empty or does not exist: ${CONFIG_FILE}"
  fi
}

update_qsub_opt() {
  # Add user-defined options from USER_QSUB_OPT
  for key in "${USER_QSUB_KEY[@]}"; do
    QSUB_OPT+=(${USER_QSUB_OPT[${key}]}) # no quotes, need word splitting
  done

  # Add custom options from the shortcuts
  local custom_opt
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

  # Add any other options given directly in the command line
  QSUB_OPT+=("$@")
}

command_failed() {
  # Append a dot to the job/task file, then check its size
  # to decide whether to stop or retry
  mkdir -p "${SCRATCH_DIR}/${JOB_ID}"
  printf '.' >> "${SCRATCH_DIR}/${JOB_ID}/${TID}"
  local attempts=$(<"${SCRATCH_DIR}/${JOB_ID}/${TID}")
  if [[ ${#attempts} -lt ${MAX_ATTEMPTS} ]]; then
    log_error "RETRY (${#attempts}/${MAX_ATTEMPTS}): $@"
    exit ${RET_RESUB}
  else
    log_error "STOP (${#attempts}/${MAX_ATTEMPTS}): $@"
    exit ${RET_STOP}
  fi
}

cleanup_scratch() {
  local user1
  user1=$(/usr/bin/whoami)
  if [[ ! "${USER}" = "${user1}" ]]; then
    echo "${name}: cannot clean up for ${USER}" >&2
    exit 1
  fi
  local pid
  { sleep "${NOTIFY_AFTER}"; echo "${name}: performing cleanup..." >&2; } \
    & pid=$!
  find "${SCRATCH_DIR}/" -user "${user1}" "${@}" -delete 2>&1 \
    | grep 'cannot' >&2
  kill "${pid}" >/dev/null 2>&1
}

log_error() {
  local ms=$((($(date +%s%N)-START_TIME)/1000000))
  printf "[%03d:%02d:%02d.%03.0f ${JOB_ID}.${TID}] " \
    $((ms/3600000)) $((ms/1000%3600/60)) $((ms/1000%60)) $((ms%1000)) >&2
  echo "$@" >&2
}

log_signal() {
  log_error "$1 (received signal)"
}

verbose() {
  if [[ -n "${VERBOSE}" ]]; then
    echo "$1" >&2
    if [[ $# -gt 1 ]]; then
      print_args "${@:2}"
    fi
  fi
}

print_args() {
  for i in "$@"; do echo "  [$i]" >&2; done
}
