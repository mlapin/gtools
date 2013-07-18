#!/bin/bash
set -e

if [ -z "$SGE_TASK_ID" ];  then
    echo '$SGE_TASK_ID is not set.'
    exit 1
fi

CMD_FILE=$1
STEP=$2
MAXRESUB=$3

FAILED=
TID=${TID:-$SGE_TASK_ID}
tail -n +$SGE_TASK_ID "$CMD_FILE" | head -n $STEP | while read LINE
do
    eval "$LINE" || {
        if [ -z $FAILED ] ; then
            FAILED=1
            ABSPATH="$(readlink -f $0)"
            LOCALDIR="${ABSPATH%/*}"
            . "$LOCALDIR/gtools-setup.sh"
        fi
        command_failed "$LINE"
    }
    TID=$((TID+1))
done
