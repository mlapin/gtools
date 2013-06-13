#!/bin/bash

jid=1 # $SGE_JOB_ID
tid=1 # $SGE_TASK_ID
verbose=1

cmds=$(cat)

source consts.sh

fn="$DOT_DIR/$jid/$tid"
function new_attempt() {
    mkdir -p $(dirname $fn)
    touch $fn
    local attempt_n=$(cat $fn)
    if [ "$attempt_n" == "" ]; then
        attempt_n=1
    else
        attempt_n=$(($attempt_n + 1))
    fi
    echo $attempt_n > $fn
    if [ "$verbose" != "" ]; then
        echo "job id $jid, task id $tid, bookkeeping file $fn"
        echo "running attempt number $attempt_n"
    fi
}

function try_resub() {
    local attempt_n=$(cat $fn)
    if [ $attempt_n -lt $NUM_RESUB ]; then
        return 1
    else
        return 0
    fi
}

function cleanup() {
    if [ "$verbose" != "" ]; then
        echo "deleting $fn"
    fi
    rm -f $fn
}

new_attempt
( $cmds )
task_retcode=$?

if [ "$task_retcode" == 0 ]; then
    if [ "$verbose" != "" ]; then
        echo "program exited normally"
    fi
    cleanup
    exit 0
else
    if [ "$verbose" != "" ]; then
        echo "program exited with error code $task_retcode"
    fi
    try_resub
    do_resub=$?
    if [ "$do_resub" == 1 ]; then
        exit $RETCODE_RESUB
    else
        cleanup
        exit $RETCODE_NORESUB
    fi
fi
