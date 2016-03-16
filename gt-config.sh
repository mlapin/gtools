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

# Path to gtools metadata
SUBMIT_HOST="submit-wheezy"

# Path to the logs directory
LOG_DIR="${LOG_DIR}"

# Default qsub options (see 'man qsub')
# These options are ALWAYS included in the qsub command (before any other args)
declare -a QSUB_OPT=( \\
    -cwd -V -r y -j y -l 'h_rt=14400,h_vmem=2G,mem_free=2G' \\
    -o "\${LOG_DIR}/\${LOG_SUBDIR}" -e /dev/null \\
    )

# Default user-defined qsub options (see 'man qsub')
# These options are activated via the '-u <option key>' parameter
declare -A USER_QSUB_OPT=( \\
    [4h]='-l h_rt=4::' \\
    [7d]='-l h_rt=168::' \\
    [d2]='-l reserved=D2blade|D2compute|D2parallel' \\
    [d2blade]='-l reserved=D2blade' \\
    [32threads]='-v MKL_DYNAMIC=FALSE -v MKL_NUM_THREADS=32 -v OMP_DYNAMIC=FALSE -v OMP_NUM_THREADS=32 -pe 8thread 32' \\
    [24threads]='-v MKL_DYNAMIC=FALSE -v MKL_NUM_THREADS=24 -v OMP_DYNAMIC=FALSE -v OMP_NUM_THREADS=24 -pe 8thread 24' \\
    [16threads]='-v MKL_DYNAMIC=FALSE -v MKL_NUM_THREADS=16 -v OMP_DYNAMIC=FALSE -v OMP_NUM_THREADS=16 -pe 8thread 16' \\
    [14threads]='-v MKL_DYNAMIC=FALSE -v MKL_NUM_THREADS=14 -v OMP_DYNAMIC=FALSE -v OMP_NUM_THREADS=14 -pe 8thread 14' \\
    [8threads]='-v MKL_DYNAMIC=FALSE -v MKL_NUM_THREADS=8 -v OMP_DYNAMIC=FALSE -v OMP_NUM_THREADS=8 -pe 8thread 8' \\
    [7threads]='-v MKL_DYNAMIC=FALSE -v MKL_NUM_THREADS=7 -v OMP_DYNAMIC=FALSE -v OMP_NUM_THREADS=7 -pe 8thread 7' \\
    [4threads]='-v MKL_DYNAMIC=FALSE -v MKL_NUM_THREADS=4 -v OMP_DYNAMIC=FALSE -v OMP_NUM_THREADS=4 -pe 8thread 4' \\
    [2threads]='-v MKL_DYNAMIC=FALSE -v MKL_NUM_THREADS=2 -v OMP_DYNAMIC=FALSE -v OMP_NUM_THREADS=2 -pe 8thread 2' \\
    [1threads]='-v MKL_DYNAMIC=FALSE -v MKL_NUM_THREADS=1 -v OMP_DYNAMIC=FALSE -v OMP_NUM_THREADS=1' \\
    )

# Matlab Compiler options
MCC_OPTS="-R -singleCompThread -R -nodisplay -R -nosplash -v"

EOF

  echo "${name}: configuration written to: ${CONFIG_FILE}"
}

main "$@"
