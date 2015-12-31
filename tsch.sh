#! /bin/bash
#
# tsch.sh
# Copyright (C) 2015 djp <djp@transit>
# Distributed under terms of the MIT license.
# a context-driven scheduling script for taskwarrior
# LOOK OUT! crappy pseudo-code ahead!
TSCH_VERSION='0.5'

WIDTH=90
DBG=''
ARGS=$*
if [[ "$1" == --debug ]]; then DBG='on'; shift; fi
if [[ "$1" == -[rui+] ]]; then FLAGS=$1; shift; fi

FILTER=$*
TASK='task rc.verbose: rc.defaultwidth:'$WIDTH
RPT_READY_UUID='rc.report.ready.columns=uuid rc.report.ready.labels= ready'
LIST_DESC='rc.report.list.columns=description,scheduled rc.report.list.labels= list'
DUEDATE=`$TASK _get rc.due`
CONFIRM=`$TASK _get rc.confirmation`
SCHED_NONE_COUNT=`$TASK +PENDING $FILTER +READY scheduled.none: count`
SCHED_OLD_COUNT=`$TASK +PENDING $FILTER +READY scheduled.before:today count`
PENDING_COUNT=`$TASK rc.context: +PENDING count`
READY_COUNT=`$TASK rc.context: +READY +PENDING count`
DIVIDER='-------------------------------------'
MODE='batch' # sched, ask, resched, unsched, according to -i -r -u flags, the default is batch


# function: get_contexts
CONTEXT_CURRENT=`task _get rc.context`
CONTEXT=$CONTEXT_CURRENT
# CONTEXT='rc.context:'$CONTEXT_CURRENT
CONTEXT_LIST=`cat ~/.taskrc |grep ^context. | cut -d. -f2 | cut -d= -f1`
#CONTEXT=work
#TASKDATA
# test for taskdata

# function: get_candidates
CANDIDATES=`$TASK tag.not:nosch rc.context:$CONTEXT $FILTER +READY $RPT_READY_UUID`
CANDIDATES_COUNT=`$TASK tag.not:nosch rc.context:$CONTEXT $FILTER +READY count`
CANDIDATES_LIMIT=12
CAND_LIST_LIMIT=3
# CANDIDATES_TEST=`$TASK $CANDIDATES ready`
#CANDIDATES_COUNT=`$CANDIDATES count`

# function: get_next_target
TARGET_DATE_RANGE='sched.after:now'
TARGETS=`$TASK $FILTER $TARGET_DATE_RANGE uuids`
if [[ "$TARGETS" == '' ]]; then 
    echo 'No targets found'; else
TARGET_LIMIT=6
TARGETS_COUNT=`$TASK $TARGETS count`
TARGET_NEXT=`echo $TARGETS |cut -d' ' -f1`
TARGET_NEXT_DESC=`$TASK $TARGET_NEXT $LIST_DESC`
    fi
# read +@context1 target tasks uuids
#	sort:edate+

    echo
    echo -e ' <----- Taskwarrior Scheduling ----->' 
#     if [[ "$MODE" == batch ]]; then 
# 	echo '          Batch Mode'
#     fi
    echo -e '    '$READY_COUNT' ready of '$PENDING_COUNT' pending tasks'
    #$SCHED_NONE_COUNT' unscheduled, '$SCHED_OLD_COUNT' stale' 
    #echo -e ' Total pending tasks \t\t: '$PENDING_COUNT
    echo -e $DIVIDER
	if [[ "$CONTEXT_CURRENT" != '' ]]; then
	    echo -e ' Context \t: '$CONTEXT_CURRENT
	fi
    echo -e ' Filter \t: '$FILTER
    echo -e $DIVIDER
    #echo -e ' Unscheduled tasks \t\t: '$SCHED_NONE_COUNT   
    #echo -e ' Tasks past scheduled date \t: '$SCHED_OLD_COUNT
    #echo -e $DIVIDER
    echo -e ' '$CANDIDATES_COUNT' Candidates'
	task rc.verbose:label rc.context:$CONTEXT $FILTER limit:$CAND_LIST_LIMIT sch-cand;
    #echo -e `$TASK $CONTEXT $FILTER limit:3 ready`
    if [[ "$CANDIDATES_COUNT" > $CAND_LIST_LIMIT ]]; then
    echo -e '.. and CAND_BATCH_LIMIT - CAND_LIST_LIMIT more'; fi
    echo -e $DIVIDER
    if [[ "$TARGETS" == '' ]]; then
	echo 'No targets found'; else
	echo ' '$TARGETS_COUNT' Targets'
	task rc.verbose:label rc.context:$CONTEXT $FILTER limit:$TARGET_LIMIT sch-target;
    # echo -e 'and the next target is "'$TARGET_NEXT_DESC'"'
	fi
    echo 'Assign this target sched date? ( Y/n/q )'
    echo

if [[ "$DBG" == on ]]; then 
    echo '============DEBUG=============';
    echo 'version = '$TSCH_VERSION;
    echo 'ARGS = '$ARGS;
    echo 'FLAGS = '$FLAGS;
    echo 'FILTER = '$FILTER;
    echo 'SCHED_NONE_COUNT = '$SCHED_NONE_COUNT;
    echo 'SCHED_OLD_COUNT = '$SCHED_OLD_COUNT;
    echo 'TASKDATA = '$TASKDATA;
    echo 'DUEDATE = '$DUEDATE; 
    echo 'CONFIRM = '$CONFIRM;
    echo 'CONTEXT_LIST = '$CONTEXT_LIST;
    echo 'TARGETS = '$TARGETS;
    echo 'CONTEXT = '$CONTEXT;
    echo 'TARGET next = '$TARGET_NEXT;
    echo 'TARGET next desc = '$TARGET_NEXT_DESC;
    echo 'TARGETS count = '$TARGETS_COUNT;
    echo 'CANDIDATES count = '$CANDIDATES_COUNT; 
    echo 'UNSCHEDULED count = '$SCHED_NONE_COUNT;
    echo '============ND DEBUG==========';
# if [[ $DBG == on ]]; then echo 'CANDIDATES = '$CANDIDATES; fi
# if [[ $DBG == on ]]; then echo 'CANDIDATES ready = '$CANDIDATES_TEST; fi
fi

# function: apply_sched
# task $CANDIDATES mod sched:$NEXT_TARGET_DATE
