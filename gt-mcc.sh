#!/bin/bash
#
# Compiles MATLAB function into a standalone application
set -e
name="${GT_NAME}-mcc"

usage() {
  cat <<EOF
usage: ${name/-/ } [--help] <MATLAB_function> [<mcc_options>...]

Enter \`help mcc' at MATLAB prompt for mcc options.
EOF
}

main() {
  verbose "arguments (before parsing):" "$@"

  if [[ "$1" = 'help' || "$1" = '--help' ]]; then
    show_help "mcc"
    exit 0
  fi

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

  # Make the path absolute
  target="$(readlink -f "${target}")"
  local dname="${target%/*}"
  local fname="${target##*/}"

  # Add libraries (if any)
  local libs=""
  if [[ -d "${MCC_LIB_DIR}" ]]; then
    for i in "${MCC_LIB_DIR}"/*; do
      libs="${libs} -a '$i'"
    done
  fi

  local mcc_cmd="mcc ${libs} ${MCC_OPTS} -m ${fname} $@"
  verbose "mcc command: ${mcc_cmd}"

  matlab -nodisplay -nojvm -nosplash -r "cd ${dname}; ${mcc_cmd}; quit"
}

main "$@"
