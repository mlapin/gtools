#!/bin/bash
set -e

CMDARGS=()
while [ $# -gt 0 ]
do
    case "$1" in
        -r|--retry|--resub|--attempt)
            shift
            MAXRESUB=$1
            ;;
        --)
            shift
            break
            ;;
        *)
            CMDARGS+=("$1")
            ;;
    esac
    shift
done

if [ ${#CMDARGS[@]} -eq 0 ] ; then
    exit 0
fi

qsubmit -N "${CMDARGS[0]}" $QSUBOPT "$@" -b y \
"$LOCALDIR/grun-cmd.sh" $MAXRESUB "${CMDARGS[@]}"
