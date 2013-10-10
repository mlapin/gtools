#!/bin/bash
#
# Creates a user config file
set -e
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

# Default qsub options (see 'man qsub')
# These options are ALWAYS included in the qsub command (before any other args)
declare -a QSUB_OPT=( \
    -cwd -V -r y -j y -l 'h_rt=14400,h_vmem=2G,mem_free=2G' \
    -o "\${LOG_DIR}/\${LOG_SUBDIR}" -e "\${LOG_DIR}/\${LOG_SUBDIR}" \
    )

# Default user-defined qsub options (see 'man qsub')
# These options are activated via the '-u <option key>' parameter
declare -A USER_QSUB_OPT=( \
    [4h]='-l h_rt=4::' \
    [7d]='-l h_rt=168::' \
    [d2]='-l reserved=D2blade|D2compute|D2parallel' \
    )

EOF

  echo "${name}: configuration written to: ${CONFIG_FILE}"
}

main "$@"
