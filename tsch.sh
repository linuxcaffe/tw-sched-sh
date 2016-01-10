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

TASK_OPTS="rc.verbose: rc.defaultwidth:90"

DIVIDER='-------------------------------------'

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

##################################################################################
# Color setup

# Themse could be allowed here by changing this to something like
# HEAD_TEXT_COLOR=${HEAD_TEXT_COLOR:=$(tput bold ; tput setaf 2)
# Then, if the config file doesn't have this value set, the default will work.
#
# I'm defaulting tput to 8 colors output. Testing and handling for 256 colors
# can come later.
#
# If you want to get more complicated with ansi codes then an external library
# will be necessary. See
# https://github.com/harleypig/dotfiles/blob/master/.bash_functions.d/ansi for
# ideas. There are other frameworks kicking around the web.


BOLD=$(tput bold)
GREEN_FG=$(tput setaf 2)
WHITE_FG=$(tput setaf 7)
BLACK_FG=$(tput setaf 0)
RESET=$(tput sgr0)

##################################################################################
# Functions

# XXX: Convert system calls to 'runit' for error handling.
# XXX: Add option to log output to file instead of stdout.

# These two are cut-n-paste from my snippets collection. They need to be
# tweaked for each situation.
#
# LOGIT_PREFIX is created on program start and can be as simple or complex as
# you want.
#
# NOTREALLY is used for debugging and dry-runs.
#
#logit { echo "${LOGIT_PREFIX} $@" >> $LOGFILE ; }
#
#runit {
#  logit "$@"
#  $NOTREALLY "$@" >> $LOGFILE
#
#  if [[ $? -ne 0 ]]; then
#    echo "Error executing call, exiting"
#    exit 1
#  fi
#}
#
# Something like the below to handle task calls
#
# task { runit $TASK $TASK_OPTS "$@" ; }

usage () { echo "$USAGE" ; echo -e "!!! $@" ; exit 1 ; }

# XXX: Are ready and pending counts supposed to have no context?

__rc_context    () { $TASK _get rc.context ; }

__candidate_count     () { $TASK $TASK_OPTS tag.not:nosch rc.context:$CONTEXT $FILTER +READY count ; }
__pending_count       () { $TASK $TASK_OPTS rc.context: +PENDING count                             ; }
__ready_count         () { $TASK $TASK_OPTS rc.context: +READY +PENDING count                      ; }
__schedule_none_count () { $TASK $TASK_OPTS +PENDING $FILTER +READY scheduled.none: count          ; }
__schedule_old_count  () { $TASK $TASK_OPTS +PENDING $FILTER +READY scheduled.before:today count   ; }
__target_count        () { $TASK $TASK_OPTS $FILTER +PENDING scheduled.after:now count             ; }

__candidate_list_limit () { $TASK $TASK_OPTS _get rc.sched.cand.list.limit   ; }
__target_list_limit    () { $TASK $TASK_OPTS _get rc.sched.target.list.limit ; }

__target_next_id () { $TASK $TASK_OPTS rc.report.sch_target.columns=id rc.report.sch_target.labels= limit:1 sch_target ; }

__context_text  () { echo ${CONTEXT:=None} ; }
__filter_text   () { echo ${FILTER:=None}  ; }

__schedule_text () {

  SCHEDULE_TEXT='Schedule'

  [[ $RESCHEDULE -eq 1 ]] && SCHEDULE_TEXT='Re-schedule';
  [[ $UNSCHEDULE -eq 1 ]] && SCHEDULE_TEXT='Un-schedule';

  echo $SCHEDULE_TEXT

}

__header_text () {

  HEADER_TEXT='<----- Taskwarrior'
  [[ $BATCH_MODE -eq 1 ]] &&  HEADER_TEXT="${HEADER_TEXT} Batch"
  HEADER_TEXT="${HEADER_TEXT} $(__schedule_text) ----->"

  echo $HEADER_TEXT

}

header_text () {

  # XXX: Allow option to clear screen each time header is called.

  echo -e "
${BOLD}${GREEN_FG} $(__header_text) ${RESET}
  ${BOLD}${BLACK_FG}$(__ready_count) ready of $(__pending_count) pending tasks${RESET}
$DIVIDER
 Context: $(__context_text)
 Filter : $(__filter_text)
$DIVIDER"

}

candidates_list () {

  CANDIDATE_COUNT=$(__candidate_count)
  CANDIDATE_LIST_LIMIT=$(__candidate_list_limit)

  if [[ $BATCH_MODE -eq 0 ]]; then
    if [[ $CANDIDATE_COUNT -eq 0 ]]; then
      echo -e ' No tasks match! Try changing the context or filter'
      exit 1
    else
      echo -e "${BOLD}${GREEN_FG} Next of ${CANDIDATE_COUNT} Candidates${RESET}\n"
      $TASK rc.verbose=label rc.report.sch_cand.columns=project,tags,description,urgency rc.context:$CONTEXT $FILTER limit:1 sch_cand;
    fi

  else
    echo -e "${BOLD}${GREEN_FG} ${CANDIDATE_COUNT} Candidates${RESET}\n"
    $TASK rc.verbose=label rc.context:$CONTEXT $FILTER limit:$CANDIDATE_LIST_LIMIT sch_cand;
    echo

    if [[ $CANDIDATE_COUNT -gt $CANDIDATE_LIST_LIMIT ]]; then
      CAND_MORE=$(( $CANDIDATE_COUNT - $CANDIDATE_LIST_LIMIT ))
      echo -e "${BOLD}${BLACK_FG}   (and $CAND_MORE more) are matching, unscheduled tasks${RESET}"
    else
      echo -e "${BOLD}${BLACK_FG}   these are matching, unscheduled tasks${RESET}"
    fi
  fi

  echo -e "\n$DIVIDER"

}

targets_list () {

  TARGET_COUNT=$(__target_count)
  CANDIDATE_COUNT=$(__candidate_count)
  TARGET_LIST_LIMIT=$(__target_list_limit)

  # TODO fix the following:
  #DATE_FMT=rc.dateformat.report=\'$($TASK _get rc.sched.datefmt)\'  #for target rpt

  if [[ $TARGET_COUNT -eq 0 ]]; then
    echo -e ' No matching targets found';
  else
    echo "${BOLD}${WHITE_FG} ${TARGET_COUNT} Targets${RESET}"
  #  task rc.verbose:label rc.context:$CONTEXT $FILTER limit:$TARGET_LIST_LIMIT $DATE_FMT sch_target;
  #  task rc.verbose:label rc.context:$CONTEXT $FILTER limit:$TARGET_LIST_LIMIT rc.dateformat.report='a, b D, H:n' sch_target;
    $TASK rc.verbose:label rc.context:$CONTEXT $FILTER limit:$TARGET_LIST_LIMIT sch_target;
  fi

  if [[ $TARGET_COUNT -gt $TARGET_LIST_LIMIT ]]; then
    TARGETS_MORE=$(( $TARGET_COUNT - $TARGET_LIST_LIMIT ))
    echo -e "${BOLD}${BLACK_FG} (and ${TARGETS_MORE} more) are possible scheduling target dates${RESET}"
  fi

  echo -e $DIVIDER

  if [[ $BATCH_MODE -eq 1 && $CANDIDATE_COUNT -gt $BATCH_LIMIT ]]; then
    echo -e "
  ${CANDIDATE_COUNT} tasks is over the batch-limit of ${BATCH_LIMIT}
  ${BOLD}${BLACK_FG}  try changing the filter and/or context,
    or override with '-l N', or change it in sched.rc${RESET}"
    exit 1
  fi

  if [[ $TARGET_COUNT -gt 0 ]]; then
    echo -e "${BOLD}${BLACK_FG}   ID   [+|- offset]  eg: 142, 123 - 2dy, 234 + 2hr, 113 - 1wk${RESET}"
  fi

}

hint_text () {

  echo -e "
   ${BOLD}${BLACK_FG}date [+|- offset]  eg: mon, 15th, eom - 2dy, tomorrow + 14hr
   h[elp]    display USAGE text
   q[uit]    quit without changes${RESET}
"
}

run_task_command () {

  PROMPT="$@"
  TARGET_NEXT_ID=$(__target_next_id)

  if [[ -z $PROMPT ]] && [[ -z $TARGET ]]; then
    echo ' No targets found, please enter a date'

  elif [[ -z $PROMPT ]] && [[ $TARGET_NEXT_ID == [0-9]+ ]]; then
    TASK_CMD=$(logit $TASK $CANDIDATE_ID mod sched:${CANDIDATE_ID}.scheduled)
    echo $TASK_CMD
    read -n 1 -ep ' (Y/n) ' confirm

    if [[ -z $confirm ]] || [[ $confirm == [Yy] ]]; then
      $TASK_CMD
    else
      echo ' action cancelled, no changes made'
    fi
  fi

}

##################################################################################
# Option Handling

DBG=0
BATCH_MODE=0
BATCH_LIMIT=$($TASK _get rc.sched.batch.limit)
RESCHEDULE=0
UNSCHEDULE=0

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
  CONTEXT=$(__rc_context)
elif [[ ${CONTEXT,,} == 'none' ]]; then
  CONTEXT=
elif [[ -z $($TASK _context | grep "^$CONTEXT$") ]]; then
  usage "No such context '$CONTEXT'"
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
# main

header_text
candidates_list
targets_list
hint_text

while read -ep "${BOLD}${GREEN_FG} Schedule > ${RESET}" prompt; do
  history -s "$prompt"

  case "$prompt" in
    h|help) echo "$USAGE"                ;;
    q|quit) echo -e "Exiting\n" ; exit 0 ;;
    *) run_task_command $prompt          ;;
  esac
done

##################################################################################
## Debug

if [[ $DBG -eq 1 ]]; then
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
