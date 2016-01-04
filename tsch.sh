#! /bin/bash
#
# tsch.sh
# Copyright (C) 2015 djp <djp@transit>
# Distributed under terms of the MIT license.
# An urgency-driven, context-aware scheduling script for taskwarrior

TSCH_VERSION='0.7'

##################################################################################
# Check Requirements

TASK=$(command -v task)

if [[ $? -ne 0 ]]; then
  echo 'Unable to find task executable'
  exit 1
fi

if [[ -n $TASKRC ]]; then
  TASK_RC=$TASKRC
elif [[ -f $HOME/.taskrc ]]; then
  TASK_RC=$HOME/.taskrc
else
  echo 'Unable to find .taskrc'
  exit 1
fi

TASK_VERSION=$(task _version)

if [[ $($TASK _get rc.sched.rc.included) != 'yes' ]]; then
  cat <<EOT
    it seems sched.rc is not found, or is somehow broken.

    try adding
    include ~/path/to/shed.rc
    to your .taskrc file

EOT

    exit 1
fi

##################################################################################
# Help Setup

USAGE=<<EOT
USAGE

${0##*/} [-d] [-h] [-b] [-l <limit>] [-r] [-u] [-c context] [task filters]

    -h          this usage text
    -d          debug mode
    -b          batch-mode
    -l limit    override default limite for batch-mode
    -r          re-schedule-mode, acts on sched:stale and +sch tags
    -u          un-schedule-mode, clear or reset currently scheduled tasks
    -c context  use specified context (default is none)
    filters     any trailing arguments are passed as task filters

    re-schedule-mode and un-schedule-mode are mutually exclusive

at the Schedule > prompt;
    ID [+|- offset] eg; 142, 217 + 15min, 67 - 2hr, 123 + 2dy, etc
    date            including forms like: mon, eow, 11th, Jul10, etc
    h[elp]          show this usage text
    q[uit]          exit without changes

EOT

usage () { echo $USAGE ; echo "!!! $@" ; exit 1 ; }

##################################################################################
# Option Handling

DBG=0
BATCH_MODE=0
BATCH_LIMIT=$($TASK _get rc.sched.cand.list.limit)
RESCHEDULE=0
UNSCHEDULE=0
CONTEXT_CURRENT=$($TASK _get rc.context)

OPTIND=1 # This forces the index to 1. This isn't usually necessary, but I'm
         # a belt and suspenders guy.

while getopts ":hdbl:ruc:" opt; do
  case "$opt" in
    h) usage                 ;;
    d) DBG=1                 ;;
    b) BATCH_MODE=1          ;;
    l) BATCH_LIMIT=${OPTARG} ;;
    r) RESCHEDULE=1          ;;
    u) UNSCHEDULE=1          ;; 
    c) CONTEXT=${OPTARG}     ;;
  esac
done

if [[ $RESCHEDULE -eq 1 && $UNSCHEDULE -eq 1 ]]; then
  usage "re-schedule-mode and un-schedule-mode are mutually exclusive"
fi

if [[ -z $CONTEXT ]]; then
  CONTEXT=$CONTEXT_CURRENT
elif [[ ${CONTEXT,,} == 'none' ]]; then
  CONTEXT=
  $TASK context none
elif [[ -z $($TASK _context | grep $CONTEXT) ]]; then
  usage "No such context $CONTEXT"
else
  $TASK context $CONTEXT
fi

FILTER="$@"

##################################################################################
# Variable Setup

WIDTH=90
TASK_OPTS="rc.verbose: rc.defaultwidth:${WIDTH}"

DIVIDER='-------------------------------------'
MODE='sched' # sched, resched, unsched
RPT_READY_UUID='rc.report.ready.columns=uuid rc.report.ready.labels= ready'

# LIST_DESC='rc.report.list.columns=description,scheduled rc.report.list.labels= list'
#CONTEXT_LIST=$(grep ^context. $TASK_RC | cut -d '.' -f 2 | cut -d '=' -f 1)

CAND_LIST_LIMIT=$($TASK $TASK_OPTS_get rc.sched.cand.list.limit)
PENDING_COUNT=$($TASK $TASK_OPTSrc.context: +PENDING count)
READY_COUNT=$($TASK $TASK_OPTSrc.context: +READY +PENDING count)
SCHED_NONE_COUNT=$($TASK $TASK_OPTS+PENDING $FILTER +READY scheduled.none: count)
SCHED_OLD_COUNT=$($TASK $TASK_OPTS+PENDING $FILTER +READY scheduled.before:today count)
TARGET_LIST_LIMIT=$(task $TASK_OPTS_get rc.sched.target.list.limit)

# function: get_candidates
CANDIDATES=$($TASK $TASK_OPTS tag.not:nosch rc.context:$CONTEXT $FILTER +READY $RPT_READY_UUID)
CANDIDATES_COUNT=$($TASK $TASK_OPTS tag.not:nosch rc.context:$CONTEXT $FILTER +READY count)

# function: get_next_target
TARGET_DATE_RANGE='sched.after:now'
TARGETS=$($TASK $TASK_OPTS $FILTER $TARGET_DATE_RANGE uuids)
TARGETS_COUNT=$(task $FILTER +PENDING scheduled.after:now count)
TARGET_ID=$(task $FILTER +PENDING scheduled.after:now limit:1 ids)

TARGET_ID=$(echo $TARGETS |cut -d' ' -f1)
# TARGET_NEXT_DESC=`$TASK $TASK_OPTS $TARGET_NEXT $LIST_DESC`

## COLORS
declare -A title=([value]="[1;32m" [alt]="[38;5;10m[48;5;232m" [end]="[0m")
    C1=${title[value]}  # bold green
    C1a=${title[alt]}  # bold green on gray
declare -A heading=([value]="[1;37m" [alt]="^[[38;5;242m" [end]="[0m")
    C2=${heading[value]}  #bold white
declare -A comment=([value]="[38;5;245m" [alt]="^[[38;5;242m" [end]="[0m")
    C3=${comment[value]}  #gray13
declare -A warning=([value]="[32;40m" [alt]="^[[38;5;242m" [end]="[0m")  # yellow
    Cx=${title[end]}  #end color rule

## Report
### Header

    echo
    echo -e $C1' <----- Taskwarrior Scheduling ----->' $Cx
#     if [[ "$MODE" == batch ]]; then 
# 	echo '          Batch Mode'
#     fi
    echo -e $C3'   '$READY_COUNT' ready of '$PENDING_COUNT' pending tasks'$Cx
    #$SCHED_NONE_COUNT' unscheduled, '$SCHED_OLD_COUNT' stale' 
    echo -e $DIVIDER

### Context & Filter
#### Context
	if [[ "$CONTEXT_CURRENT" != '' ]]; then
	    echo -e ' Context \t: '$CONTEXT_CURRENT
	fi

#### Filter
	if [[ "$FILTER" != '' ]]; then
	    echo -e ' Filter \t: '$FILTER
	    echo -e $DIVIDER
	fi

#### No context or filter
	if [[ "$BATCH_MODE" == on ]] && [[ "$CONTEXT_CURRENT" == '' ]] && [[ "$FILTER" == '' ]]; then
	    echo -e ' This command has no filter or context'
	    echo ' and would apply to ALL tasks,'
	    echo -e ' so it has been disabled'
	    echo -e ' USAGE'
	    echo
	    echo -e $DIVIDER
	fi
    #echo -e ' Unscheduled tasks \t\t: '$SCHED_NONE_COUNT   
    #echo -e ' Tasks past scheduled date \t: '$SCHED_OLD_COUNT
    #echo -e $DIVIDER

## Candidates list 
if [[ "$BATCH_MODE" == off ]]; then
    echo -e $C2' Next of '$CANDIDATES_COUNT' Candidates'$Cx
    CAND_ID=`task rc.verbose=label rc.context:$CONTEXT $FILTER limit:1 ids`;
    task rc.verbose=label rc.context:$CONTEXT $FILTER limit:1 sch_cand;
elif [[ "$BATCH_MODE" == on ]]; then
    echo -e $C2' '$CANDIDATES_COUNT' Candidates'$Cx
	task rc.verbose=label rc.context:$CONTEXT $FILTER limit:$CAND_LIST_LIMIT sch_cand;
    if [[ "$CANDIDATES_COUNT" -gt "$CAND_LIST_LIMIT" ]]; then
	CAND_MORE=$(( $CANDIDATES_COUNT - $CAND_LIST_LIMIT ))
    echo -e $C3' (and '$CAND_MORE' more) are matching, unscheduled tasks'$Cx; else
    echo -e $C3' these are matching, unscheduled tasks'$Cx
    fi
fi
    echo -e $DIVIDER

## Targets list
    if [[ "$TARGETS" == '' ]]; then
	echo -e ' No matching targets found'; else
	echo $C2' '$TARGETS_COUNT' Targets'$Cx
	task rc.verbose:label rc.context:$CONTEXT $FILTER limit:$TARGET_LIST_LIMIT sch_target;
    fi
    if [[ "$TARGETS_COUNT" -gt "$TARGET_LIST_LIMIT" ]]; then
	TARGETS_MORE=$(( $TARGETS_COUNT - $TARGET_LIST_LIMIT ))
	echo -e $C3' and '$TARGETS_MORE' more) are possible scheduling target dates'$Cx; 
    fi
	echo -e $DIVIDER
    echo ' (enter target-ID#, date or "y" or "n" or "q"'
    read -ep $C1' Schedule > '$Cx prompt
if [[ "$prompt" == '' ]] && [[ "$TARGET_ID" == '' ]]; then
    echo ' No targets found, please enter a date'
    # TODO cycle prompt
elif [[ "$prompt" == '' ]] && [[ "$TARGET_ID" = [0-9]+ ]]; then
    TASK_CMD=`echo -e 'task '$CAND_ID' mod sched:'$CAND_ID'.scheduled'`
    echo $TASK_CMD
    read -ep ' (Y/n)' conf_prompt
	if [[ "$conf_prompt" == [yY] ]] || [[ "$conf_prompt" == '' ]]; then
	$TASK_CMD
	else echo ' action cancelled, no changes made'; exit 0;
	fi
fi
    # elif prompt = [0-9]4'
    # else prompt = 

# TASK_CMD='task $CONTEXT $FILTER ..'
    # echo ' $ task '$CONTEXT $FILTER' mod sched:TARGET_UUID.scheduled'
    echo

## Debug
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
fi
exit 0
