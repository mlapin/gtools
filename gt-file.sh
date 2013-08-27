#!/bin/bash
#
# Submits a set of commands listed in a file
set -e
set -o pipefail
name="${GT_NAME}-file"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] [options] <file> [-- <qsub options>]

    -g <N>    group commands into batches (N lines per group, default: N=1)
              use '-g all' to submit all commands in a single batch
    -a <N>    make N attempts (resubmit up to N-1 times if command fails)
    -t <T>    require h_rt=T (example: -t 4:: or -t 14400)
    -m <M>    require mem_free=M (example: -m 1G)
    -v <M>    require h_vmem=M (example: -v 6G)
    -u <K>    add a user-defined option (available keys: ${!USER_QSUB_OPT[@]})
    -p        profile the command (report time and resource usage)
    -M        run MATLAB compiled code

See \`man qsub' for qsub options.
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ "$1" = 'help' || "$1" = '--help' ]]; then
    show_help "file"
    exit 0
  fi

  # Parse known options
  USER_QSUB_KEY=()
  local timeit='no'
  local matlab='no'
  while getopts ":g:a:t:m:v:u:pM" opt; do
    case "${opt}" in
      g) step="${OPTARG}" ;;
      a) MAX_ATTEMPTS="${OPTARG}" ;;
      m) RES_MEMORY="${OPTARG}" ;;
      t) RES_TIME="${OPTARG}" ;;
      v) RES_VMEMORY="${OPTARG}" ;;
      u) USER_QSUB_KEY+=("${OPTARG}") ;;
      p) timeit='yes' ;;
      M) matlab='yes' ;;
      \?) echo "${name}: unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
  done
  shift $((${OPTIND}-1))

  if [[ $# -eq 0 ]]; then
    echo "${name}: nothing to submit."
    usage
    exit 1
  fi

  step="${step:-1}"
  cmd_file="${cmd_file:-"$1"}"
  cmd_name="${cmd_file##*/}"
  shift

  # Skip the optional '--'
  if [[ "$1" = "--" ]]; then
    shift
  fi

  # Perform certain sanity checks for the commands file
  if  [[ ! -e "${cmd_file}" ]]; then
    echo "${name}: file does not exist: ${cmd_file}" 1>&2
    exit 1
  fi

  if  [[ ! -r "${cmd_file}" ]]; then
    echo "${name}: cannot read file: ${cmd_file}" 1>&2
    exit 1
  fi

  if  [[ ! -s "${cmd_file}" ]]; then
    echo "${name}: file is empty: ${cmd_file}"
    exit 0
  fi

  if [[ "${cmd_file:0:1}" != '/' ]]; then
    cmd_file="${PWD}/${cmd_file}" # make the path absolute
  fi

  total=$(wc -l "${cmd_file}" | cut -f1 -d' ')

  if [[ "${step}" = "all" ]]; then
    step="${total}"
  fi

  # The rest (after --) are qsub options
  update_qsub_opt "$@"

  verbose "options:" \
    "attempts: ${MAX_ATTEMPTS}" \
    "file: ${cmd_file}" \
    "lines: ${total}" \
    "group by: ${step}"

  qsubmit -N "${cmd_name}" \
    -t "1-${total}:${step}" \
    "${QSUB_OPT[@]}" \
    "${LOCAL_DIR}/grun-file.sh" \
    "${LOCAL_DIR}" \
    "${MAX_ATTEMPTS}" \
    "${timeit}" \
    "${matlab}" \
    "${step}" \
    "${cmd_file}"
}

main "$@"
