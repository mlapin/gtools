#!/bin/bash
set -e

MAXRESUB=$1
shift

$@ || {
    ABSPATH="$(readlink -f $0)"
    LOCALDIR="${ABSPATH%/*}"
    . "$LOCALDIR/gtools-setup.sh"
    command_failed "$@"
}
