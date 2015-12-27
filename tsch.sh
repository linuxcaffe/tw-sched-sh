#! /bin/bash
#
# tsch.sh
# Copyright (C) 2015 djp <djp@transit>
#
# Distributed under terms of the MIT license.
#

# a context-driven scheduling script for taskwarrior

# LOOK OUT! crappy pseudo-code ahead!

DBG=on

#TASKDATA
# test for taskdata
if [[ "$DBG" == on ]]; then echo 'TASKDATA = '$TASKDATA; fi

TASK='task rc.verbose: rc.defaultwidth:0' 
READY_UUIDS='rc.report.ready.columns=uuid rc.report.ready.labels= ready'

DUEDATE=`$TASK _get rc.due`
if [[ "$DBG" == on ]]; then echo 'DUEDATE = '$DUEDATE; fi

CONFIRM=`$TASK _get rc.confirmation`
if [[ "$DBG" == on ]]; then echo 'CONFIRM = '$CONFIRM; fi

# function: get_contexts
# CONTEXTS=`$TASK _context`
CONTEXTS=`cat ~/.taskrc |grep ^context. | cut -d. -f2 | cut -d= -f1`
if [[ "$DBG" == on ]]; then echo 'CONTEXTS = '$CONTEXTS; fi
CONTEXT=contact
if [[ "$DBG" == on ]]; then echo 'CONTEXT = '$CONTEXT; fi
# read contexts

# function: get_next_target
TARGETS=`$TASK +@$CONTEXT sched.after:now uuids`
if [[ "$DBG" == on ]]; then echo 'TARGETS = '$TARGETS; fi
# read +@context1 target tasks uuids
#	sort:edate+

# function: get_candidates
CANDIDATES=`$TASK rc.context=$CONTEXT $READY_UUIDS`
# if [[ $DBG == on ]]; then echo 'CANDIDATES = '$CANDIDATES; fi
#CANDIDATES_TEST=`$TASK $CANDIDATES ready`
# if [[ $DBG == on ]]; then echo 'CANDIDATES ready = '$CANDIDATES_TEST; fi
CANDIDATES_COUNT=`$TASK $CANDIDATES count`
if [[ $DBG == on ]]; then echo 'CANDIDATES count = '$CANDIDATES_COUNT; fi
# read context1 candidate tasks uuids
#	sort:urgency-

# function: apply_sched
# task $CANDIDATES mod sched:$NEXT_TARGET_DATE
