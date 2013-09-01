#!/bin/bash
#
# Modifies grid engine jobs
set -e
name="${GT_NAME}-alter"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] <qalter options>

See \`man qalter' for qalter options.
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
        show_help "alter"
        break
        ;;
      *)
        qalter "$@"
        break
        ;;
    esac
    shift
  done
}

main "$@"
