#!/bin/bash
#
# Check if gtools are ready to use
set -e
set -o pipefail
name="${GT_NAME}-check"

usage() {
  cat <<EOF
usage: ${GT_NAME} check
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ "$1" = 'help' || "$1" = '--help' ]]; then
    show_help "check"
    exit 0
  fi

  # Disable exit on error
  set +e

  local errors_occurred

  echo "${name}: verifying that grid engine commands are available..."
  qstatus >/dev/null
  if [[ $? -eq 0 ]]; then
    echo "  OK: ${STAT_CMD} succeeded"
  else
    echo "  ERROR: ${STAT_CMD} failed"
    echo "  (check the grid engine section in \`${LOCAL_DIR}/gt-setup.sh')"
    errors_occurred=1
  fi
  echo

  echo "${name}: verifying that the scratch space is writable..."
  mkdir -p "${SCRATCH_DIR}"
  if [[ -w "${SCRATCH_DIR}" ]]; then
    echo "  OK: directory is writable: ${SCRATCH_DIR}"
  else
    echo "  ERROR: cannot write to: ${SCRATCH_DIR}"
    echo "  (set SCRATCH_DIR to a writable directory in the config file)"
    echo "  (use \`${GT_NAME} config' to create a user config file)"
    errors_occurred=1
  fi
  echo

  if [[ -z "${errors_occurred}" ]]; then
    echo "${GT_NAME} is ready!"
  else
    echo "Some setup is required (see above)."
    exit 1
  fi
}

main "$@"
