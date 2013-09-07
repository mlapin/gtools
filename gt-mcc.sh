#!/bin/bash
#
# Compiles a MATLAB function into a standalone application
set -e
name="${GT_NAME}-mcc"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] [options] <MATLAB_function> [<mcc_options>...]

    -a <dir>  add all libraries from the given directory
              (equivalent to \`mcc ... -a <name>' for each file/folder in <dir>)
              (default: '${MCC_LIB_DIR}')
    -i <file> initialize MATLAB by running the given .m file before compilation
              (add the necessary \`addpath ...' statements in there)
              (default: '${MCC_INIT_FILE}')
    -c        clear the default mcc options ('${MCC_OPTS}')

  (use \`${name/-/ } <MATLAB_function> -a <lib1> [-a <lib2>...]' \
to add individual libraries)

Enter \`help mcc' at MATLAB prompt for mcc options.
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ "$1" = 'help' || "$1" = '--help' ]]; then
    show_help "mcc"
    exit 0
  fi

  # Parse known options
  while getopts ":a:i:o:" opt; do
    case "${opt}" in
      a) MCC_LIB_DIR="${OPTARG}" ;;
      i) MCC_INIT_FILE="${OPTARG}" ;;
      c) MCC_OPTS= ;;
      \?) echo "${name}: unknown option: -$OPTARG" >&2; usage; exit 1 ;;
    esac
  done
  shift $((${OPTIND}-1))

  if [[ $# -eq 0 ]]; then
    echo "${name}: nothing to compile."
    usage
    exit 1
  fi

  # File name of the function to compile
  local target="$1"
  shift

  if  [[ ! -e "${target}" ]]; then
    echo "${name}: file does not exist: ${target}" 1>&2
    exit 1
  fi

  if  [[ ! -r "${target}" ]]; then
    echo "${name}: cannot read file: ${target}" 1>&2
    exit 1
  fi

  if  [[ ! -s "${target}" ]]; then
    echo "${name}: file is empty: ${target}"
    exit 0
  fi

  # Create the init command
  local mcc_init=""
  if [[ -n "${MCC_INIT_FILE}" ]]; then
    mcc_init="if exist('${MCC_INIT_FILE}','file') \
      fprintf('Running \"${MCC_INIT_FILE}\"...\n'); run('${MCC_INIT_FILE}'); \
      end"
  fi

  # Add libraries (if any)
  local libs=""
  if [[ -n "${MCC_LIB_DIR}" && -d "${MCC_LIB_DIR}" ]]; then
    for i in "${MCC_LIB_DIR}"/*; do
      libs="${libs} -a '$i'"
    done
  fi

  local mcc_cmd="mcc ${libs} ${MCC_OPTS} -m '${target}' $@"
  verbose "mcc command: ${mcc_cmd}"

  matlab -nodisplay -nojvm -nosplash -r \
    "cd ${PWD}; ${mcc_init}; ${mcc_cmd}; quit"
}

main "$@"
