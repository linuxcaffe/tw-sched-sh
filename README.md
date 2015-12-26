# tw-sched-sh
a context-driven scheduling script for taskwarrior

## WHy?
With the GTD(tm) understanding of "context", the idea is that individual tasks
are really best done "in-context", that is to say, you are really only going to
do "work" task at work, "garden" tasks in the garden, and "shop" tasks while
you are out. If it were possible to "schedule" tasks (assign sched:date)
according to times of occasions when you are going to be in the correct
context, then you could stop worrying about those, for today, knowing that they
are "scheduled".

This script will also have a function to "reschedule" tasks that were not 
performed on their sched:date, or any task with a +sched tag.

## How?
well I have some ideas on how that might be implemented as a batch process;

- setting up personal contexts
    For this context-driven script to have any meaning, first the user has to
    understand and have defined some taskwarrior contexts. see: man task

- assigning +@context-opportunity tags
    Using a "@" as the first character in a tag will do 2 things, first, to
    include it in a given context, like +@garden, and secondly, to indicate
    that this task is a candidate, a context in which other garden-context
    tasks could be performed. A users regular routine, as they go from context
    to context could be set up as recurring "tasks", having +@context tags
    which act as targets for scheduling. As well, any random task with a
    due:date or a sched:date, could be made a candidate for doing other tasks
    in the same +@context. In this way, any task with a date and a +@tag
    becomes "glue" for other tasks in that context. 

3. run tsch.sh
