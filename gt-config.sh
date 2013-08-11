#!/bin/bash
#
# Create a user config file
set -e
set -o pipefail
name="${GT_NAME}-config"

usage() {
  cat <<EOF
usage: ${GT_NAME} config [options]

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
    exit 1
  fi

  cat > "${CONFIG_FILE}" <<EOF
# gtools version ${VERSION} runtime configuration file
# Automatically created by ${name} on $(date "+%Y-%m-%d %H:%M:%S") using
# $(/bin/bash --version | head -n 1)

# Maximum number of attempts to execute a command
MAX_ATTEMPTS=${MAX_ATTEMPTS}

# Default qsub options (see 'man qsub')
# These options are always included in the qsub command (before any other args)
declare -a QSUB_OPT=( $(printf '%q ' ${QSUB_OPT[@]}))

# Default user-defined qsub options (see 'man qsub')
# These options are activated via the '-u <option key>' parameter
declare -A USER_QSUB_OPT=( $( \
  for key in "${!USER_QSUB_OPT[@]}"; do \
    printf "[%s]='%s' " "${key}" "${USER_QSUB_OPT[${key}]}"; \
  done; ))

# Path to the scratch folder (temporary metadata storage)
SCRATCH_DIR='${SCRATCH_DIR}'

# If not empty, automatically delete user files in the scratch folder
# when there are no user jobs in the cluster
AUTO_CLEANUP=1

EOF

  echo "${name}: configuration written to: ${CONFIG_FILE}"
}

main "$@"
