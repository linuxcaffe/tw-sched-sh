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
The IDs are used as sched:ID.scheduled, the list length is configurable. 

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

    date [+|- offset]	including forms like: mon, eow, 11th, Jul10, etc

    h[elp]		show this usage text

    q[uit]		exit without changes

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

    Using the "-u" flag puts tsch into Un-schedule-mode, candidates are
    matching, already-scheduled tasks, to clear or reset their sched:date.
 
## at the Schedule prompr
