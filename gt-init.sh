#!/bin/bash
#
# Create a config file
set -e
set -o pipefail
name="${GT_NAME}-init"

usage() {
  cat <<EOF
usage: ${GT_NAME} init [options]

    -f    overwrite the config file if it already exists
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ "$1" = 'help' || "$1" = '--help' ]]; then
    show_help "init"
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

  set +e

  echo "${name}: verifying that grid engine commands are available..."
  qstatus >/dev/null
  if [[ $? -eq 0 ]]; then
    echo "  OK: ${STAT_CMD} succeeded"
  else
    echo "  WARNING: ${STAT_CMD} failed"
    echo "  (check the grid engine section in \`${LOCAL_DIR}/gt-setup.sh')"
  fi
  echo

  echo "${name}: verifying that the scratch space is writable..."
  mkdir -p "${SCRATCH_DIR}"
  if [[ -w "${SCRATCH_DIR}" ]]; then
    echo "  OK: directory is writable: ${SCRATCH_DIR}"
  else
    echo "  WARNING: cannot write to: ${SCRATCH_DIR}"
    echo "  (set SCRATCH_DIR to a writable directory in the config file)"
  fi
  echo

  echo "${name}: attempting to create the config file..."
  if [[ -e "${CONFIG_FILE}" && "${FORCE}" -ne 1 ]]; then
    echo "  ERROR: file already exists: ${CONFIG_FILE}" 1>&2
    echo "  (use \`${name/-/ } -f' to overwrite the existing file)" 1>&2
    exit 1
  fi

  set -e

  cat > "${CONFIG_FILE}" <<EOF
# gtools version ${VERSION} runtime configuration file
# Automatically created by ${name} on $(date "+%Y-%m-%d %H:%M:%S") using
# $(/bin/bash --version | head -n 1)

# Default qsub options (see 'man qsub')
# NOTE: must be an array and not a string!
QSUB_OPT=($(printf '%q ' ${QSUB_OPT[@]}))

# Maximum number of attempts to execute a command
MAX_ATTEMPTS=${MAX_ATTEMPTS}

# Path to the directory to store jobs' metadata (temporarily)
SCRATCH_DIR='${SCRATCH_DIR}'

EOF

  echo "  OK: configuration written to: ${CONFIG_FILE}"
}

main "$@"
