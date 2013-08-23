#!/bin/bash
#
# Submits a single command
set -e
set -o pipefail
name="${GT_NAME}-cmd"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] [options] <command> [<args>] [-- <qsub options>]

    -a <N>    make N attempts (resubmit up to N-1 times if command fails)
    -t <T>    require h_rt=T (example: -t 4:: or -t 14400)
    -m <M>    require mem_free=M (example: -m 1G)
    -v <M>    require h_vmem=M (example: -v 6G)
    -u <K>    add a user-defined option (available keys: ${!USER_QSUB_OPT[@]})
    -p        profile the command (report running time and resource usage)

See \`man qsub' for qsub options.
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ "$1" = 'help' || "$1" = '--help' ]]; then
    show_help "cmd"
    exit 0
  fi

  # Parse known options
  USER_QSUB_KEY=()
  local timeit='no'
  while getopts ":a:t:m:v:u:p" opt; do
    case "${opt}" in
      a) MAX_ATTEMPTS="${OPTARG}" ;;
      t) RES_TIME="${OPTARG}" ;;
      m) RES_MEMORY="${OPTARG}" ;;
      v) RES_VMEMORY="${OPTARG}" ;;
      u) USER_QSUB_KEY+=("${OPTARG}") ;;
      p) timeit='yes' ;;
      \?) echo "${name}: unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
  done
  shift $((${OPTIND}-1))

  # The rest (before --) is treated as a command with its args
  cmd_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift; break ;;
      *)
        # Since the command will be eval'ed, command args are double-quoted
        # (which also enables variable substitution at eval time)
        if [[ ${#cmd_args[@]} -ge 1 ]]; then
          local esc_bslash="${1//\\/\\\\}"
          local esc_dquote="${esc_bslash//\"/\\\"}"
          cmd_args+=("\"${esc_dquote}\"")
        else
          cmd_args+=("$1")
        fi
        ;;
    esac
    shift
  done

  if [[ ${#cmd_args[@]} -eq 0 ]]; then
    echo "${name}: nothing to submit."
    usage
    exit 1
  fi

  cmd_name="${cmd_args[0]}"
  cmd_name="${cmd_name##*/}"

  # The rest (after --) are qsub options
  update_qsub_opt "$@"

  verbose "options:" \
    "attempts: ${MAX_ATTEMPTS}" \
    "command: ${cmd_args[0]}"
  verbose "command args:" \
    "${cmd_args[@]:1}"

  qsubmit -N "${cmd_name}" "${QSUB_OPT[@]}" \
    "${LOCAL_DIR}/grun-cmd.sh" "${LOCAL_DIR}" "${MAX_ATTEMPTS}" "${timeit}" \
    "${cmd_args[@]}"
}

main "$@"
