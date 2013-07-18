VERSION=0.1

GDIR="${GDIR:-"/scratch/BS/pool1/.gtools"}"
MANDIR="${LOCALDIR:-$PWD}/man"
MAXRESUB=${MAXRESUB:-3}
QSUBOPT="${QSUBOPT:-"-notify -r y -V"}"
QSUBHOST="submit-squeeze"
QSUBPREHOOK="source /n1_grid/current/inf/common/settings.sh"


RETRESUB=${RETRESUB:-99}
RETSTOP=${RETSTOP:-100}
JOB_ID=${JOB_ID:-1}
SGE_TASK_ID=${SGE_TASK_ID:-1}
TID=${TID:-$SGE_TASK_ID}

qsubmit() {
    command -v qsub >/dev/null && eval "qsub $@" ||
    ssh -x submit-squeeze \
    "source /n1_grid/current/inf/common/settings.sh && qsub $@"
}

log_error() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S") $JOB_ID.$TID] $@" 1>&2
}

command_failed() {
    mkdir -p "$GDIR/$JOB_ID"
    printf '.' >> "$GDIR/$JOB_ID/$TID"
    ATTEMPTS=$(stat -c '%s' "$GDIR/$JOB_ID/$TID")
    if [ $ATTEMPTS -lt $MAXRESUB ]; then
        log_error "Attempt $ATTEMPTS/$MAXRESUB failed, RETRY: $@"
        exit $RETRESUB
    else
        log_error "Attempt $ATTEMPTS/$MAXRESUB failed, STOP: $@"
        exit $RETSTOP
    fi
}