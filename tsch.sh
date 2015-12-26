#! /bin/sh
#
# tsch.sh
# Copyright (C) 2015 djp <djp@transit>
#
# Distributed under terms of the MIT license.
#

# a context-driven scheduling script for taskwarrior

# LOOK OUT! crappy pseudo-code ahead!

# TASKDATA
# test for taskdata

# DUEDATE

# CONTEXTS=`task _context`
# read contexts

# TARGETS=`task +@$CONTEXT \( due > now or sched > now \) uuids`
# read +@context1 target tasks uuids
#	sort:edate+

# CANDIDATES=`task rc.context=$CONTEXT \( sched < today or sched.none \)`
# read context1 candidate tasks uuids
#	sort:urgency-
