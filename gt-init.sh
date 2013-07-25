#!/bin/bash
#
# Creates a config file
set -e
set -o pipefail
name="${GT_NAME}-init"

usage() {
  cat <<EOF
usage: ${GT_NAME} init [options]

    -f    overwrite an existing file (if any)
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

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
    echo "${name}: file already exists: ${CONFIG_FILE}" 1>&2
    exit 1
  fi

  cat > "${CONFIG_FILE}" <<EOF
# gtools version ${VERSION} runtime configuration file
# Automatically created by ${name} at $(date "+%Y-%m-%d %H:%M:%S") using
# $(/bin/bash --version | head -n 1)

# Default qsub options (see 'man qsub')
# QSUB_OPT must be an array (see http://tldp.org/LDP/abs/html/arrays.html)
QSUB_OPT=(${QSUB_OPT[@]})

# Maximum number of attempts to execute a command
MAX_ATTEMPTS=${MAX_ATTEMPTS}

# Path to the config file
CONFIG_FILE='${CONFIG_FILE}'

# Path to the scratch folder (temporary storage)
SCRATCH_DIR='${SCRATCH_DIR}'
EOF

  echo "${name}: default config written to: ${CONFIG_FILE}"
}

main "$@"
