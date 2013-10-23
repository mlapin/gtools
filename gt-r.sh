#!/bin/bash
#
# Run a command on submit host
set -e
name="${GT_NAME}-r"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] <Grid Engine command>

See Grid Engine documentation for available commands.
EOF
}


main() {
  verbose "arguments (before parsing):" "$@"

  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|help)
        show_help "r"
        break
        ;;
      *)
        run_on_submit_host "$@"
        break
        ;;
    esac
    shift
  done
}

main "$@"
