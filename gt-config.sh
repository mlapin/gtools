#!/bin/bash
#
# Creates a user config file
set -e
set -o pipefail
name="${GT_NAME}-config"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] [options]

    -f    overwrite the config file if it already exists
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ "$1" = 'help' || "$1" = '--help' ]]; then
    show_help "config"
    exit 0
  fi

  while getopts ":f" opt; do
    case "${opt}" in
      f) FORCE=1 ;;
      \?) echo "${name}: unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
  done
  shift $((${OPTIND}-1))

  verbose "options:" \
    "force: ${FORCE}" \
    "config file: ${CONFIG_FILE}"

  if [[ -e "${CONFIG_FILE}" && "${FORCE}" -ne 1 ]]; then
    echo "${name}: file already exists: ${CONFIG_FILE}" >&2
    echo "  (use \`${name/-/ } -f' to overwrite the existing file)" >&2
    echo "  (delete the config file to restore default settings)" >&2
    exit 1
  fi

  cat > "${CONFIG_FILE}" <<EOF
# gtools version ${VERSION} runtime configuration file
# Automatically created by ${name} on $(date "+%Y-%m-%d %H:%M:%S") using
# $(/bin/bash --version | head -n 1)

# Maximum number of attempts to execute a command
MAX_ATTEMPTS="${MAX_ATTEMPTS}"

# Path to the logs directory
LOG_DIR="${LOG_DIR}"

# Path to the temporary metadata storage
META_DIR="${META_DIR}"

# Default qsub options (see 'man qsub')
# These options are always included in the qsub command (before any other args)
declare -a QSUB_OPT=( $(printf '%q ' ${QSUB_OPT[@]}))

# Default user-defined qsub options (see 'man qsub')
# These options are activated via the '-u <option key>' parameter
declare -A USER_QSUB_OPT=( $( \
  for key in "${!USER_QSUB_OPT[@]}"; do \
    printf "[%s]='%s' " "${key}" "${USER_QSUB_OPT[${key}]}"; \
  done; ))

EOF

  echo "${name}: configuration written to: ${CONFIG_FILE}"
}

main "$@"
