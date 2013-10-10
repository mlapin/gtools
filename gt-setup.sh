#!/bin/bash
#
# Defines common constants, functions, and default values
set -e
unset VERSION
unset START_TIME
readonly VERSION=0.1
readonly START_TIME=$(date +%s%N)

################################################################################
#
# Custom options (edit here)
#

# Maximum number of attempts to execute a command
# (default is 1, i.e. do not reschedule in case of failure)
MAX_ATTEMPTS="${MAX_ATTEMPTS:-1}"

# Path to the user config file
CONFIG_FILE="${CONFIG_FILE:-"${HOME}/.gtrc"}"

# Path to the logs directory
LOG_DIR="${LOG_DIR:-"/scratch/common/pool0/${USER}/logs"}"

# Expression for the name of the logs subdirectory
# If not empty, this expression will be evaluated at submission time
# and the corresponding folder will be created as a subfolder of LOG_DIR.
# Has limited support for variables:
#   only $HOME, $USER, $JOB_ID, and $JOB_NAME can be used,
#   the variables must appear exactly as given above (i.e. no curly braces),
#   avoid the underscore character (causes ambiguities in variable names).
LOG_SUBDIR="${LOG_SUBDIR:-"\$JOB_ID-\$JOB_NAME"}"

# Path to the temporary metadata storage
META_DIR="${META_DIR:-"/scratch/common/pool0/.gtools"}"

# Path to the folder with the gtools scripts
LOCAL_DIR="${LOCAL_DIR:-"${0%/*}"}"

# Path to the manuals
MAN_DIR="${MAN_DIR:-"${LOCAL_DIR}/man"}"

# Default qsub options (see 'man qsub')
# These options are always included in the qsub command (before any other args)
if [[ -z "${QSUB_OPT}" ]]; then
  declare -a QSUB_OPT=( \
    -cwd -V -r y -j y -l 'h_rt=14400,h_vmem=2G,mem_free=2G' \
    -o "${LOG_DIR}/${LOG_SUBDIR}" -e "${LOG_DIR}/${LOG_SUBDIR}" \
    )
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

# Grid engine commands and hooks
DEL_CMD="${DEL_CMD:-"qdel"}"
MOD_CMD="${MOD_CMD:-"qmod"}"
STAT_CMD="${STAT_CMD:-"qstat"}"
ALTER_CMD="${ALTER_CMD:-"qalter"}"
SUBMIT_CMD="${SUBMIT_CMD:-"qsub"}"
SUBMIT_HOST="${SUBMIT_HOST:-"submit-wheezy"}"
PRE_HOOK="${PRE_HOOK:-"cd '${PWD}'"}"

# The command for measuring running time and resource usage
TIMEIT_CMD="${TIMEIT_CMD:-"/usr/bin/time -v"}"

# If not empty, automatically delete user files in the metadata folder
# when there are no user jobs in the cluster
AUTO_CLEANUP=1

# Show a notification message after the specified number of seconds
# if an interactive command is taking longer to complete
NOTIFY_AFTER=1


#
# MATLAB related options
#

# Matlab Compiler (mcc) options
# Run this file in Matlab before running mcc (allows to addpath)
MCC_INIT_FILE=""
# Add all libraries in this folder by default (uses the -a mcc option)
MCC_LIB_DIR=
# Use these mcc options
MCC_OPTS="-R -singleCompThread -R -nodisplay -R -nosplash -v"

# Matlab Compiler Runtime (MCR) options
MCR_CACHE_ROOT="/var/tmp"
MCR_CACHE_SIZE="256M"

MCRROOT="/local/gridengine/general/MATLAB_Compiler_Runtime/v81"
if [[ ! -d "${MCRROOT}" ]]; then
  MCRROOT="/BS/opt/local/MATLAB_Compiler_Runtime/v81"
fi

MCRJRE="${MCRROOT}/sys/java/jre/glnxa64/jre/lib/amd64"
MCR_XAPPLRESDIR="${MCRROOT}/X11/app-defaults"
MCR_LD_LIBRARY_PATH=".\
:${MCRROOT}/runtime/glnxa64\
:${MCRROOT}/bin/glnxa64\
:${MCRROOT}/sys/os/glnxa64\
:${MCRJRE}/native_threads\
:${MCRJRE}/server\
:${MCRJRE}/client\
:${MCRJRE}"

################################################################################

# Return codes that trigger special handling by the grid engine
RET_RESUB="${RET_RESUB:-99}"  # reschedules the job/task
RET_STOP="${RET_STOP:-100}"   # sets the job into error state

# Job statuses (regex for matching qstat output in gawk)
STAT_RUNNING="${STAT_RUNNING:-"/^[hR]*[rt ]+$/"}"
STAT_WAITING="${STAT_WAITING:-"/^R?[hqw ]+$/"}"
STAT_ERROR="${STAT_ERROR:-"/[E]/"}"

# Job and task IDs
JOB_ID="${JOB_ID:-1}"
SGE_TASK_ID="${SGE_TASK_ID:-1}"
TID="${TID:-${SGE_TASK_ID}}"
if [[ "${TID}" = "undefined" ]]; then
  TID=1
fi


unknown_command() {
  echo "${name}: '$1' is not a ${name} command. See \`${name/-/ } --help'." >&2
}

qsubmit() {
  # Parse the given options and set the corresponding environment variables
  # (these variables can be used e.g. in the LOG_SUBDIR)
  parse_qsub_opt "$@"

  # -notify enables USR2 signal, which is fired e.g. when the h_rt limit is hit
  # the wrapper scripts handle this as if the command failed (nonzero exit code)
  # -terse forces qsub to output only the job id upon successful submission
  JOB_ID=$(run_on_submit_host "${SUBMIT_CMD}" -notify -terse "$@" |
    sed -n -e 's/^\([0-9]\+\).*/\1/p')
  verbose "job id: ${JOB_ID}"

  # If LOG_SUBDIR is not empty, eval it to perform variable substitution
  # and attempt to create the corresponding subdirectory
  # (the Grid Engine does not create directories, hence this workaround)
  if [[ -n "${LOG_SUBDIR}" ]]; then
    eval "subdir=${LOG_SUBDIR}"
    mkdir -p "${LOG_DIR}/${subdir}"
  fi

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

qalter() {
  run_on_submit_host "${ALTER_CMD}" "$@"
}

run_on_submit_host() {
  if [[ -n "${VERBOSE}" || -n "${DRY_RUN}" ]]; then
    echo "command to execute:" >&2
    verbose_nocheck "$@"
  fi
  if [[ -n "${DRY_RUN}" ]]; then
    echo "dry run: command not executed." >&2
    exit 1
  else
    # If there is no qsub, ssh to a submit host and try there
    command -v "${SUBMIT_CMD}" >/dev/null && "$@" || {
      # Quoting is required to correctly pass the command
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

parse_qsub_opt() {
  # Cannot use getopts because it would stop at the first non-option argument
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -N) shift; JOB_NAME="$1" ;;
    esac
    shift
  done
}

update_qsub_opt() {
  # First, start with the default qsub options
  # (see the definition of QSUB_OPT)

  # Second, add any user-defined options if requested by the -u <key> option
  for key in "${USER_QSUB_KEY[@]}"; do
    QSUB_OPT+=(${USER_QSUB_OPT[${key}]}) # no quotes, need word splitting
  done

  # Third, add resource limits from the shortcut options (e.g. -t <time>)
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

  # Finally, add any other options given directly in the command line
  # (these typically appear after the '--' at the end)
  QSUB_OPT+=("$@")
}

command_failed() {
  local code=$?

  # Skip the retry/stop workflow and just exit
  if [[ ${MAX_ATTEMPTS} -lt 1 ]]; then
    log_error "ERROR: ${code}: $@"
    exit ${code}
  fi

  # Append a dot '.' to the job/task file to count the number of attempts,
  # then check its size to decide whether to stop or retry
  mkdir -p "${META_DIR}/${JOB_ID}"
  local fname="${META_DIR}/${JOB_ID}/${TID}"
  printf '.' >> "${fname}"

  # Read the file into a local variable
  local attempts
  attempts=$(<"${fname}") || log_error "Cannot read metadata: ${fname}"

  # Decide whether to stop or retry (reschedule)
  if [[ ${#attempts} -lt ${MAX_ATTEMPTS} ]]; then
    log_error "ERROR: ${code}: RETRY (${#attempts}/${MAX_ATTEMPTS}): $@"
    exit ${RET_RESUB}
  else
    log_error "ERROR: ${code}: STOP (${#attempts}/${MAX_ATTEMPTS}): $@"
    exit ${RET_STOP}
  fi
}

cleanup_metadata() {
  # Check that the $USER variable is not overriden
  local user1
  user1=$(/usr/bin/whoami) || echo "${name}: whoami failed" >&2
  if [[ ! "${USER}" = "${user1}" ]]; then
    echo "${name}: cannot clean up for ${USER}" >&2
    exit 1
  fi

  # Show a notification message if the command is taking too long
  { sleep "${NOTIFY_AFTER}"; echo "${name}: performing cleanup..." >&2; } &
  local pid=$!

  # Delete all files/folders of the current user in the metadata directory
  # (but not the metadata folder itself)
  find "${META_DIR}" -user "${user1}" -not -path "${META_DIR}" \
    -delete 2>&1 | grep 'cannot' >&2

  # Kill the notification subprocess if it hasn't quit yet
  kill "${pid}" >/dev/null 2>&1 || :
}

log_error() {
  # Show the timestamp since the job/task is started (ms precision)
  local ms=$((($(date +%s%N)-START_TIME)/1000000))
  printf "[%03d:%02d:%02d.%03.0f ${JOB_ID}.${TID}] " \
    $((ms/3600000)) $((ms/1000%3600/60)) $((ms/1000%60)) $((ms%1000)) >&2
  echo "$@" >&2
}

log_signal() {
  log_error "$@ (received signal)"
}

verbose() {
  if [[ -n "${VERBOSE}" ]]; then
    verbose_nocheck "$@"
  fi
}

verbose_nocheck() {
  echo "$1" >&2
  if [[ $# -gt 1 ]]; then
    print_args "${@:2}"
  fi
}

print_args() {
  for i in "$@"; do echo "  [$i]" >&2; done
}
