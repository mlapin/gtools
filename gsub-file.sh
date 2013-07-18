#!/bin/bash
set -e

while [ $# -gt 0 ]
do
    case "$1" in
        -g|--group*)
            shift
            GROUP=$1
            ;;
        -r|--retry|--resub|--attempt)
            shift
            MAXRESUB=$1
            ;;
        *)
            break
            ;;
    esac
    shift
done

if [ $# -eq 0 ] ; then
    exit 0
fi

GROUP=${GROUP:-1}
CMD_FILE=${CMD_FILE:-$1}
CMD_NAME="${CMD_FILE##*/}"

shift

if [ "$1" = "--" ] ; then
    shift
fi

if  [ ! -e "$CMD_FILE" ] ; then
    echo "'$CMD_FILE' does not exist." 1>&2
    exit 1
fi

if  [ ! -r "$CMD_FILE" ] ; then
    echo "'$CMD_FILE' is not readable." 1>&2
    exit 1
fi

if  [ ! -s "$CMD_FILE" ] ; then
    echo "'$CMD_FILE' is empty."
    exit 0
fi

if ! echo "$CMD_FILE" | grep -q ^/ ; then
    CMD_FILE="$PWD/$CMD_FILE"
fi

MAX=$(wc -l $CMD_FILE | cut -f1 -d' ')
STEP=$(((MAX+GROUP-1)/GROUP)) # ceiling($MAX/$GROUP)

qsubmit -N "$CMD_NAME" $QSUBOPT -t 1-$MAX:$STEP "$@" -b y \
"$LOCALDIR/grun-file.sh" "$CMD_FILE" $STEP $MAXRESUB

