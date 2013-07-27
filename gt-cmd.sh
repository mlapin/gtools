#!/bin/bash
#
# Submits a single command
set -e
set -o pipefail
name="${GT_NAME}-cmd"

usage() {
  cat <<EOF
usage: ${GT_NAME} cmd [--help] [options] <command> [<args>] [-- <qsub options>]

    -a <N>    make N attempts (resubmit up to N-1 times if command fails)
    -t <T>    require h_rt=T (example: -t 00:30:00 or -t 1800)
    -m <M>    require mem_free=M (example: -m 1G)
    -v <M>    require h_vmem=M (example: -v 6G)

See 'man qsub' for qsub options.
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ "$1" = 'help' || "$1" = '--help' ]]; then
    help "cmd"
    exit 0
  fi

  while getopts ":a:t:m:v:" opt; do
    case "${opt}" in
      a) MAX_ATTEMPTS="${OPTARG}" ;;
      m) RES_MEMORY="${OPTARG}" ;;
      t) RES_TIME="${OPTARG}" ;;
      v) RES_VMEMORY="${OPTARG}" ;;
      \?) echo "${name}: unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
  done
  shift $((${OPTIND}-1))

  cmd_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift; break ;;
      *) cmd_args+=("$1") ;;
    esac
    shift
  done

  if [[ ${#cmd_args[@]} -eq 0 ]]; then
    echo "${name}: nothing to submit."
    usage
    exit 1
  fi

  update_qsub_opt "$@"

  verbose "options:" \
    "attempts: ${MAX_ATTEMPTS}" \
    "command: ${cmd_args[0]}"
  verbose "command args:" \
    "${cmd_args[@]:1}"
  verbose "qsub options:" \
    "${QSUB_OPT[@]}"

  qsubmit -N "${cmd_args[0]}" "${QSUB_OPT[@]}" \
    "${LOCAL_DIR}/grun-cmd.sh" "${MAX_ATTEMPTS}" "${cmd_args[@]}"
}

main "$@"
