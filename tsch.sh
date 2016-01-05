#! /bin/bash
#
# tsch.sh
# Copyright (C) 2015 djp <djp@transit>
# Distributed under terms of the MIT license.
# An urgency-driven, context-aware scheduling script for taskwarrior

TSCH_VERSION='0.8'

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

USAGE="
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

"

usage () { echo "$USAGE" ; echo -e "!!! $@" ; exit 1 ; }

##################################################################################
# Option Handling

DBG=0
BATCH_MODE=0
BATCH_LIMIT=$($TASK _get rc.sched.batch.limit)
RESCHEDULE=0
UNSCHEDULE=0
CONTEXT_CURRENT=$($TASK _get rc.context)

OPTIND=1 # This forces the index to 1. This isn't usually necessary, but I'm
         # a belt and suspenders guy.

while getopts ":hdbl:ruc:" opt; do
  case "$opt" in
    h) echo "$USAGE" ; exit  ;;
    d) DBG=1                 ;;
    b) BATCH_MODE=1          ;;
    l) BATCH_LIMIT=${OPTARG} ;;
    r) RESCHEDULE=1          ;;
    u) UNSCHEDULE=1          ;; 
    c) CONTEXT=${OPTARG}     ;;
   \?) usage "Invalid option: ${OPTARG}"  ; exit ;;
    :) usage "-${OPTARG} requires a value" ; exit ;;
    *) echo "$USAGE" ; exit  ;;
  esac
done

shift "$(($OPTIND-1))"

if [[ $RESCHEDULE -eq 1 && $UNSCHEDULE -eq 1 ]]; then
  usage "re-schedule-mode and un-schedule-mode are mutually exclusive"
fi

if [[ -z $CONTEXT ]]; then
  CONTEXT=$CONTEXT_CURRENT
elif [[ ${CONTEXT,,} == 'none' ]]; then
  CONTEXT=
#  $TASK context none
elif [[ -z $($TASK _context | grep "^$CONTEXT$") ]]; then
  usage "No such context '$CONTEXT'"
#else
#  $TASK context $CONTEXT
fi

FILTER="$@"

#cat <<EOT
#        DBG: ${DBG}
# BATCH_MODE: ${BATCH_MODE}
#BATCH_LIMIT: ${BATCH_LIMIT}
# RESCHEDULE: ${RESCHEDULE}
# UNSCHEDULE: ${UNSCHEDULE}
#    CONTEXT: ${CONTEXT}
#     FILTER: ${FILTER}
#EOT
#
#exit

##################################################################################
# Variable Setup

WIDTH=90
TASK_OPTS="rc.verbose: rc.defaultwidth:${WIDTH}"

DIVIDER='-------------------------------------'
CAND_LIST_LIMIT=$($TASK $TASK_OPTS _get rc.sched.cand.list.limit)
CAND_COUNT=$($TASK $TASK_OPTS tag.not:nosch rc.context:$CONTEXT $FILTER +READY count)
PENDING_COUNT=$($TASK $TASK_OPTS rc.context: +PENDING count)
READY_COUNT=$($TASK $TASK_OPTS rc.context: +READY +PENDING count)
SCHED_NONE_COUNT=$($TASK $TASK_OPTS +PENDING $FILTER +READY scheduled.none: count)
SCHED_OLD_COUNT=$($TASK $TASK_OPTS +PENDING $FILTER +READY scheduled.before:today count)
TARGET_LIST_LIMIT=$($TASK $TASK_OPTS _get rc.sched.target.list.limit)
TARGET_COUNT=$($TASK $TASK_OPTS $FILTER +PENDING scheduled.after:now count)
TARGET_NEXT_ID=$($TASK $TASK_OPTS rc.report.sch_target.columns=id rc.report.sch_target.labels= limit:1 sch_target)
# TODO fix the following:
DATE_FMT=rc.dateformat.report=\'$(task _get rc.sched.datefmt)\'  #for target rpt

PROMPT_TEXT=Schedule
PROMPT_BATCH=
if [[ $BATCH_MODE -eq 1 ]]; then
PROMPT_BATCH=$CAND_COUNT' tasks'
fi
if [[ $RESCHEDULE -eq 1 ]]; then PROMPT_TEXT=Re-schedule; 
elif [[ $UNSCHEDULE -eq 1 ]]; then PROMPT_TEXT=Un-schedule;
fi

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
    if [[ $RESCHEDULE -eq 1 && $BATCH_MODE -eq 1 ]]; then 
	echo -e $C1' <----- Taskwarrior Batch Re-scheduling ----->' $Cx
	elif [[ $RESCHEDULE -eq 1 && $BATCH_MODE -eq 0 ]]; then 
	     PROMPT_TEXT=Re-schedule;
	echo -e $C1' <----- Taskwarrior Re-scheduling ----->' $Cx
	elif [[ $UNSCHEDULE -eq 1 && $BATCH_MODE -eq 1 ]]; then 
	echo -e $C1' <----- Taskwarrior Batch Un-scheduling ----->' $Cx
	elif [[ $UNSCHEDULE -eq 1 && $BATCH_MODE -eq 0 ]]; then 
	echo -e $C1' <----- Taskwarrior Un-scheduling ----->' $Cx
	elif [[ $BATCH_MODE -eq 1 ]]; then 
	echo -e $C1' <----- Taskwarrior Batch Scheduling ----->' $Cx
	else echo -e $C1' <----- Taskwarrior Scheduling ----->' $Cx
    fi
    echo -e $C3'   '$READY_COUNT' ready of '$PENDING_COUNT' pending tasks'$Cx
    #$SCHED_NONE_COUNT' unscheduled, '$SCHED_OLD_COUNT' stale' 

### Context & Filter
#### Context
echo -e $DIVIDER
    if [[ "$CONTEXT" != '' ]]; then
	echo -e ' Context \t: '$CONTEXT
    fi

#### Filter
    if [[ "$FILTER" != '' ]]; then
	echo -e ' Filter \t: '$FILTER
    fi

#### No context or filter
    if [[ "$CONTEXT" == '' ]] && [[ "$FILTER" == '' ]]; then
	echo -e ' No filters or context'
    fi
    
## Candidates list 
echo -e $DIVIDER
if [[ "$BATCH_MODE" == 0 ]]; then
    if [[ $CAND_COUNT == '0' ]]; then
	echo -e ' No tasks match! Try changing the context or filter'
	exit 1
    else
    echo -e $C2' Next of '$CAND_COUNT' Candidates'$Cx
    task rc.verbose=label rc.report.sch_cand.columns=project,tags,description,urgency rc.context:$CONTEXT $FILTER limit:1 sch_cand;
    fi
elif [[ "$BATCH_MODE" == 1 ]]; then
    echo -e $C2' '$CAND_COUNT' Candidates'$Cx
    task rc.verbose=label rc.context:$CONTEXT $FILTER limit:$CAND_LIST_LIMIT sch_cand;
    if [[ "$CAND_COUNT" -gt "$CAND_LIST_LIMIT" ]]; then
	CAND_MORE=$(( $CAND_COUNT - $CAND_LIST_LIMIT ))
	echo -e $C3'   (and '$CAND_MORE' more) are matching, unscheduled tasks'$Cx;
    else
	echo -e $C3'   these are matching, unscheduled tasks'$Cx
    fi
fi
    echo -e $DIVIDER

## Targets list
    if [[ "$TARGET_COUNT" == '' ]]; then
	echo -e ' No matching targets found'; 
    else
	echo $C2' '$TARGET_COUNT' Targets'$Cx
#	task rc.verbose:label rc.context:$CONTEXT $FILTER limit:$TARGET_LIST_LIMIT $DATE_FMT sch_target;
#	task rc.verbose:label rc.context:$CONTEXT $FILTER limit:$TARGET_LIST_LIMIT rc.dateformat.report='a, b D, H:n' sch_target;
	task rc.verbose:label rc.context:$CONTEXT $FILTER limit:$TARGET_LIST_LIMIT sch_target;
    fi
    if [[ "$TARGET_COUNT" -gt "$TARGET_LIST_LIMIT" ]]; then
	TARGETS_MORE=$(( $TARGET_COUNT - $TARGET_LIST_LIMIT ))
	echo -e $C3' and '$TARGETS_MORE' more) are possible scheduling target dates'$Cx; 
    fi


## Prompt
echo -e $DIVIDER
if [[ $BATCH_MODE -eq 1 && $CAND_COUNT -gt $BATCH_LIMIT ]];then 
    echo -e '    '$CAND_COUNT' tasks is over the batch-limit of '$BATCH_LIMIT
    echo -e $C3'    try changing the filter and/or context,
    or override with "-l N", or change it in sched.rc'$Cx
    echo
    exit 1
fi
if [[ $TARGET_COUNT -gt '0' ]]; then
    echo -e $C3'   ID   [+|- offset]	eg: 142, 123 - 2dy, 234 + 2hr, 113 - 1wk'$Cx 	
fi
    echo -e $C3'   date [+|- offset]	eg: mon, 15th, eom - 2dy, tomorrow + 14hr
   h[elp]		display USAGE text
   q[uit]		quit without changes
 '$Cx
    read -ep $C1' Schedule > '$Cx prompt
if [[ "$prompt" == '' ]] && [[ "$TARGET_NEXT_ID" == '' ]]; then
    echo ' No targets found, please enter a date'
    # TODO cycle prompt
elif [[ "$prompt" == '' ]] && [[ "$TARGET_NEXT_ID" = [0-9]+ ]]; then
    TASK_CMD=`echo -e 'task '$CAND_ID' mod sched:'$CAND_ID'.scheduled'`
    echo $TASK_CMD
    read -ep ' (Y/n)' conf_prompt
	if [[ "$conf_prompt" == [yY] ]] || [[ "$conf_prompt" == '' ]]; then
	$TASK_CMD
	else echo ' action cancelled, no changes made'; exit 0;
	fi
fi

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
    echo 'TARGETS count = '$TARGET_COUNT;
    echo 'CAND count = '$CAND_COUNT; 
    echo 'UNSCHEDULED count = '$SCHED_NONE_COUNT;
    echo '============ND DEBUG==========';
fi
exit 0
