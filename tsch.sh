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

TASK_OPTS="rc.defaultwidth=90"
DIVIDER='-------------------------------------'
DATA_DIR=$($TASK _get rc.data.location)
LOGFILE="${DATA_DIR/\~/$HOME}/$(basename $0).log"

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
RESET=$(tput sgr0)

BLACK_FG=$(tput setaf 0)
GREEN_BG=$(tput setab 2)
GREEN_FG=$(tput setaf 2)
RED_BG=$(tput setab 1)
WHITE_FG=$(tput setaf 7)

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

logit () { echo "${LOGIT_PREFIX} $@" >> $LOGFILE     ; }
runit () { logit "$@" ; $NOTREALLY "$@" 2>> $LOGFILE ; }
task  () { runit $TASK $TASK_OPTS "$@"               ; }
usage () { echo "$USAGE" ; error "$@" ; exit 1       ; }
error () { echo -e "!!! ${RED_BG}$@${RESET}"         ; }

__rc_context   () { task _get rc.context ; }
__context_text () { echo ${CONTEXT:=None} ; }
__filter_text  () { echo ${FILTER:=None}  ; }

__batch_limit          () { task _get rc.verbose=nothing rc.sched.batch.limit       ; }
__candidate_list_limit () { task _get rc.verbose=nothing rc.sched.cand.list.limit   ; }
__sched_datefmt        () { task _get rc.verbose=nothing rc.sched.datefmt           ; }
__sched_tag            () { task _get rc.verbose=nothing rc.sched.tag               ; }
__target_list_limit    () { task _get rc.verbose=nothing rc.sched.target.list.limit ; }

# XXX: Are ready and pending counts supposed to have no context?
# XXX: Shouldn't candidate and target counts use the same context and filter?

__candidate_count     () { task rc.verbose=nothing tag.not:nosch rc.context:$CONTEXT +READY $FILTER count ; }
__pending_count       () { task rc.verbose=nothing rc.context: +PENDING count                             ; }
__ready_count         () { task rc.verbose=nothing rc.context: +PENDING +READY count                      ; }
__target_count        () { task rc.verbose=nothing +PENDING $FILTER scheduled.after:now count             ; }

__target_ () {

  reqtype=$1
  shift

  local options
  local output
  local stripspaces
  local task_command
  local usequotes

  options="${options} $TASK_OPTS"
  usequotes=
  stripspaces=

  if [[ "$reqtype" ==  '' ]]; then
    error "${FUNCNAME} needs to know list or id"
    exit 1

  elif [[ "$reqtype" == 'list' ]]; then
    task_command='sch_target'
    usequotes='yes'
    options="${options} rc.verbose=label"
    options="${options} limit=$(__target_list_limit)"

  elif [[ "$reqtype" == 'id' ]]; then
    task_command='target_id'
    stripspaces='yes'
    options="${options} rc.report.${task_command}.columns=id"
    options="${options} rc.report.${task_command}.filter=$(task _get rc.report.sch_target.filter)"
    options="${options} rc.report.${task_command}.sort=$(task _get rc.report.sch_target.sort)"
    options="${options} rc.verbose=nothing"
    options="${options} limit=1"
    #error "XXX: validate ${PROMPT} against target list ... (issue #6)"

  else
    error "Unknown request type $reqtype"
    exit

  fi

  [[ -n $CONTEXT ]] && options="${options} rc.context=$CONTEXT"
  [[ -n $FILTER ]]  && options="${options} $FILTER"

  output="$(task $options $task_command)"

  if [[ -n $stripspaces ]]; then
    output=${output# *}
    output=${output%% *}
  fi

  echo "$output"

}

__candidate_ () {

  reqtype=$1
  shift

  local task_command
  local options
  local useprintf

  options="${options} $TASK_OPTS tag.not=nosch"
  useprintf=

  if [[ "$reqtype" == '' ]]; then
    error "${FUNCNAME} needs to know list or id"
    exit 1

  elif [[ "$reqtype" == 'list' ]]; then
    task_command='sch_cand'
    options="${options} rc.verbose=label"

  elif [[ "$reqtype" == 'id' ]]; then
    task_command='cand_id'
    useprintf='yes'
    options="${options} rc.verbose=nothing"
    options="${options} rc.report.cand_id.columns=id"
    options="${options} rc.report.cand_id.filter=$(task _get rc.report.sch_cand.filter)"
    options="${options} rc.report.cand_id.sort=$(task _get rc.report.sch_cand.sort)"

  else
    error "Unknown request type $reqtype"
    exit

  fi

  options="${options} limit=1"

  [[ -n $CONTEXT ]] && options="${options} rc.context=$CONTEXT"
  [[ -n $FILTER ]]  && options="${options} $FILTER"

  if [[ -n $useprintf ]]; then
    printf "%s" $(task $options $task_command)
  else
    task $options $task_command
  fi

}

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

  if [[ $BATCH_MODE -eq 0 ]]; then
    if [[ $CANDIDATE_COUNT -eq 0 ]]; then
      error "No tasks match! Try changing the context or filter."
      exit 1

    else
      echo -e "${BOLD}${GREEN_FG} Next of ${CANDIDATE_COUNT} Candidates${RESET}

$(__candidate_ list)"

    fi

  else

    CANDIDATE_LIST_LIMIT=$(__candidate_list_limit)

    echo -e "${BOLD}${GREEN_FG} ${CANDIDATE_COUNT} Candidates${RESET}\n"
    task rc.verbose=label rc.context:$CONTEXT $FILTER limit:$CANDIDATE_LIST_LIMIT sch_cand;
    echo

    if [[ $CANDIDATE_COUNT -gt $BATCH_LIMIT ]]; then
      echo -e "
  ${CANDIDATE_COUNT} tasks is over the batch-limit of ${BATCH_LIMIT}
  ${BOLD}${BLACK_FG}  try changing the filter and/or context,
    or override with '-l N', or change it in sched.rc${RESET}"
      exit 1
    fi

    if [[ $CANDIDATE_COUNT -gt $CANDIDATE_LIST_LIMIT ]]; then
      CAND_MORE=$(( $CANDIDATE_COUNT - $CANDIDATE_LIST_LIMIT ))
      echo -e "${BOLD}${BLACK_FG}   (and $CAND_MORE more) are matching, unscheduled tasks${RESET}"
    else
      echo -e "${BOLD}${BLACK_FG}   these are matching, unscheduled tasks${RESET}"
    fi
  fi

}

targets_list () {

  TARGET_COUNT=$(__target_count)
  TARGET_LIST_LIMIT=$(__target_list_limit)

  echo -e "\n$DIVIDER"

  if [[ $TARGET_COUNT -eq 0 ]]; then
    echo -e ' No matching targets found';
  else
    echo " ${BOLD}${GREEN_FG}${TARGET_COUNT} Targets${RESET}

$(__target_ list)
"
  fi

  if [[ $TARGET_COUNT -gt $TARGET_LIST_LIMIT ]]; then
    TARGETS_MORE=$(( $TARGET_COUNT - $TARGET_LIST_LIMIT ))
    echo -e "${BOLD}${BLACK_FG} (and ${TARGETS_MORE} more) are possible scheduling target dates${RESET}"
  fi

}

# XXX: The ID line should only show if there are targets.

hint_text () { echo -e "$DIVIDER

   ${BOLD}${BLACK_FG}ID   [+|- offset]  eg: 142, 123 - 2dy, 234 + 2hr, 113 - 1wk
   date [+|- offset]  eg: mon, 15th, eom - 2dy, tomorrow + 14hr
   h[elp]    display USAGE text
   q[uit]    quit without changes${RESET}
"
}

run_task_command () {

  PROMPT="$@"
  TARGET_NEXT_ID=$(__target_ id)

  local CHECK_SCHEDULE=
  local ID_REGEX='[0-9]+'
  local PROMPT_CALC=
  local PROMPT_ID=
  local SCHEDULE=
  local TASK_CMD=

  # non-empty target_next_id && target_next_id is nan.
  # empty prompt && empty target_next_id
  # empty prompt && target_next_id is id
  # prompt is not empty

  if [[ -n $TARGET_NEXT_ID ]] && [[ ! $TARGET_NEXT_ID =~ ^$ID_REGEX$ ]]; then
    error "Do not know how to handle non-numeric TARGET_NEXT_ID (${TARGET_NEXT_ID}) result."
    exit

  elif [[ -z $PROMPT ]] && [[ -z $TARGET_NEXT_ID ]]; then
    error "No targets found, please enter a date or date offset."
    exit

  elif [[ -z $PROMPT ]] && [[ -n $TARGET_NEXT_ID ]]; then
    SCHEDULE="${TARGET_NEXT_ID}.scheduled"

  elif [[ $PROMPT =~ ^($ID_REGEX)?(.*)$ ]]; then
    PROMPT_ID=${BASH_REMATCH[1]}
    PROMPT_CALC=${BASH_REMATCH[2]}

    if [[ -n $PROMPT_ID ]] && [[ -z $PROMPT_CALC ]]; then
      SCHEDULE="${PROMPT_ID}.scheduled"

    elif [[ -z $PROMPT_ID ]] && [[ -n $PROMPT_CALC ]]; then
      SCHEDULE="$PROMPT_CALC"

    elif [[ -n $PROMPT_ID ]] && [[ -n $PROMPT_CALC ]]; then
      SCHEDULE="${PROMPT_ID}.scheduled${PROMPT_CALC}"

    else
      error "If you got here the programmer is an idiot."
      exit

    fi
  else
    error "XXX: Unexpected condition not checked (PROMPT: ${PROMPT} TARGET_NEXT_ID: ${TARGET_NEXT_ID}"
    exit

  fi

  CHECK_SCHEDULE=$(task calc $SCHEDULE)

  TASK_CMD="${SCHEDULE_WHAT} modify scheduled=${SCHEDULE} rc.bulk=${BATCH_LIMIT} rc.recurrence.confirmation=no"

  echo
  read -n 1 -ep " ${GREEN_BG}task ${TASK_CMD}${RESET} (Y/n) " confirm

  if [[ -z $confirm ]] || [[ $confirm == [Yy] ]]; then
    task rc.bulk=$BATCH_LIMIT rc.recurrence.confirmation=no $TASK_CMD

  else
    error "Action cancelled, no changes made."

  fi

}

##################################################################################
# Option Handling

DBG=0
BATCH_MODE=0
BATCH_LIMIT=$(__batch_limit)
RESCHEDULE=0
UNSCHEDULE=0

OPTIND=1 # This forces the index to 1. This isn't usually necessary, but I'm
         # a belt and suspenders guy.

while getopts ":hdbl:ruc:" opt; do
  case "$opt" in
    h) echo "$USAGE" ; exit  ;;
    d) DBG=1                 ;;
#    b) BATCH_MODE=1          ;;
    b) echo "Batch mode not supported yet" ; exit ;;
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

SCHEDULE_WHAT=$(__candidate_ id)

while read -ep " ${BOLD}${GREEN_FG}Schedule ${SCHEDULE_WHAT} >${RESET} " prompt; do
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
