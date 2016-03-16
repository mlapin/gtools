#!/bin/bash
#
# Checks if gtools are ready to use
set -e
name="${GT_NAME}-check"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] [options]

    -v        display all declared variables
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ "$1" = 'help' || "$1" = '--help' ]]; then
    show_help "check"
    exit 0
  fi

  local show_vars='no'
  while getopts ":v" opt; do
    case "${opt}" in
      v) show_vars='yes' ;;
      \?) echo "${name}: unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
  done
  shift $((${OPTIND}-1))

  if [[ "${show_vars}" = "yes" ]]; then
    ( set -o posix ; set ) | less
    exit 0
  fi

  # Disable exit on error
  set +e

  local errors_occurred

  echo "${name}: verifying that the Grid Engine commands are available..."
  qstatus >/dev/null
  if [[ $? -eq 0 ]]; then
    echo "  OK: ${STAT_CMD} succeeded"
  else
    echo "  ERROR: ${STAT_CMD} failed"
    echo "  (check the grid engine section in \`${LOCAL_DIR}/gt-setup.sh')"
    errors_occurred=1
  fi
  echo

  echo "${name}: verifying that the logs directory is writable..."
  mkdir -p "${LOG_DIR}"
  if [[ -w "${LOG_DIR}" ]]; then
    echo "  OK: directory is writable: ${LOG_DIR}"
  else
    echo "  ERROR: cannot write to: ${LOG_DIR}"
    echo "  (set LOG_DIR to a writable directory in the config file)"
    errors_occurred=1
  fi
  echo

  echo "${name}: verifying that the metadata directory is writable..."
  mkdir -p "${META_DIR}"
  if [[ -w "${META_DIR}" ]]; then
    echo "  OK: directory is writable: ${META_DIR}"
  else
    echo "  ERROR: cannot write to: ${META_DIR}"
    echo "  (set META_DIR to a writable directory in the config file)"
    errors_occurred=1
  fi
  echo

  echo "${name}: verifying that the MATLAB MCR is installed..."
  if [[ -d "${MCRROOT}" && -x "${MCRROOT}/bin/mex" ]]; then
    echo "  OK: MCR directory is: ${MCRROOT}"
  else
    echo "  ERROR: cannot find MCR at: ${MCRROOT}"
    echo "  (run \`mcrinstaller' at MATLAB prompt if MCR is not installed)"
    echo "  (set MCRROOT to the corresponding path in the config file)"
    errors_occurred=1
  fi
  echo

  if [[ -z "${errors_occurred}" ]]; then
    echo "${GT_NAME} is ready!"
  else
    echo "Some setting up is required (see above)."
    echo "  (use \`${GT_NAME} config' to create a user config file if needed)"
    exit 1
  fi
}

main "$@"
