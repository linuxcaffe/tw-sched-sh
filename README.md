# tw-sched-sh

_STATUS: In development, coming along, still quite broken, BEWARE!_ 

An urgency-driven, context-aware scheduling script for taskwarrior

This script is designed to make the process of scheduling, re-scheduling and
un-scheduling even easier. Instead of a complex "algorithm", tw-sched-sh uses
taskwarrior contexts and filters and "like-with-like" to match "candidates"
with "targets". 
* Candidates are matching, +READY (+PENDING and not blocked or scheduled.after:now)
  and served up most-urgent-first. 
* Targets are matching tasks with an upcoming sched:date, sorted soonest-first.

SCREENSHOT

### Usage 

```
tsch.sh [--debug] [-b[n]] [-r] [-u] [@:[context]] [task filters]

    -b[n]	batch-mode. Use "n" to override default limit.

    -r		re-schedule-mode, acts on sched:stale and +sch tags

    -u		un-schedule-mode, clear or reset currently scheduled tasks

    @:[context] override current context, "@: " for none

    filters	any trailing arguments are passed as task filters

at the Schedule > prompt;

    ID [+|- offset]	eg; 142, 217 + 15min, 67 - 2hr, 123 + 2dy, etc

    date	including forms like: mon, eow, 11th, Jul10, etc

    h[elp]	show this usage text

    q[uit]	exit without changes

```

## Installing
    Clone this github repo. To use ~/.task/scripts/, paste this;
```
    git clone github.com/linuxcaffe/tw-sched-sh.git ~/.task/scripts/
```
    in a console, then put (or symlink) tsch.sh in your $PATH, like;
```
    ln -s ~/.task/scripts/tw-sched-sh/tsch.sh ~/.task/scripts/tsch
```
    The sched.rc file must be included from .taskrc with an entry like
```
    include ~/.task/scripts/sched.rc
```
    or tsch will exit with a message. Edit this file to set user configs.

## Modes
    By default, tsch offers up the most urgent matching and ready tasks, one at
    a time (single-mode). By using the "-b' flag (batch-mode) tsch will act on
    groups of matching tasks, up to a (sched.rc) configured limit. Override
    that batch-limit by using a numeric value, like "-b12".

    Using the "-r" flag, puts tsch into Re-schedule-mode, starting with an
    option to clear any matching, "stale" sched:dates (sched.before:today)
    while adding a (configurable) +sch tag. Then, any matching tasks, with
    the +sch tag, are listed as candidates for re-scheduling.

    Using the "-u" flag puts tsch into Un-schedule-mode, listing matching
    already-scheduled tasks, in order to clear or reset their sched:date.

## WHy?
With the GTD(tm) understanding of "context", the idea is that individual tasks
are really best done "in-context", that is to say, you are really only going to
do "work" task at work, "garden" tasks in the garden, and "shop" tasks while
you are out. If it were possible to "schedule" tasks (assign sched:date)
according to times or occasions when you are going to be in the correct
context, then you could stop worrying about those, for today, knowing that they
are "scheduled".

This script will also have a function to "reschedule" tasks that were not 
performed on their sched:date, or any task with a +sch tag.

## How?
well I have some ideas on how that might be implemented as a batch process;

1. setting up personal contexts
    For this context-driven script to have any meaning, first the user has to
    understand and have defined some taskwarrior contexts. see: man task
2. assigning +@context-opportunity tags
    Using a "@" as the first character in a tag will do 2 things, first, to
    include it in a given context, like +@garden, and secondly, to indicate
    that this task is a candidate, a context in which other garden-context
    tasks could be performed. A users regular routine, as they go from context
    to context could be set up as recurring "tasks", having +@context tags
    which act as targets for scheduling. As well, any random task with a
    due:date or a sched:date, could be made a candidate for doing other tasks
    in the same +@context. In this way, any task with a sched:date and a +@tag
    becomes "glue" for other tasks in that context. 
3. run tsch.sh
    
