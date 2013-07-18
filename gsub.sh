#!/bin/bash
set -e
NAME="${0##*/}"
ABSPATH="$(readlink -f $0)"
LOCALDIR="${ABSPATH%/*}"
. "$LOCALDIR/gtools-setup.sh"

usage() {
    cat <<EOF
usage: $NAME [--version] [--help] <command> [<args>]

Commands:
   cmd        Submit a single command
   file       Submit a set of commands listed in a file

See '$NAME help <command>' for more information on a specific command.
EOF
}

unknown_command() {
    echo "$NAME: '$1' is not a $NAME command. See '$NAME --help'." 1>&2
    exit 1
}

help() {
    case "$1" in
        '')
            usage
            ;;
        gsub*)
            man "$MANDIR/gsub.1"
            ;;
        cmd|command)
            man "$MANDIR/gsub-cmd.1"
            ;;
        file)
            man "$MANDIR/gsub-file.1"
            ;;
        *)
            unknown_command $1
            ;;
    esac
}

if [ -z "$1" ] ; then
    usage
    exit 1
fi

while [ $# -gt 0 ]
do
    case "$1" in
        cmd|command)
            shift
            . "$LOCALDIR/gsub-cmd.sh" "$@"
            break
            ;;
        file)
            shift
            . "$LOCALDIR/gsub-file.sh" "$@"
            break
            ;;
        -h|--help|help)
            shift
            help $@
            exit 0
            ;;
        --version)
            echo "$NAME: gtools version $VERSION"
            exit 0
            ;;
        *)
            unknown_command $1
            ;;
    esac
    shift
done
