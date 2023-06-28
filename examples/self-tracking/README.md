Some examples of working with the https://www.gibney.org/a_syntax_for_self-tracking logging format
(discussion: https://news.ycombinator.com/item?id=36492033).

If you have a.dat:

```
2020-05-28 18:41 Eat Pizza
2020-05-29 09:00 Slept with the window open
2020-05-29 09:00 Headaches
```

This is close enough to hledger's timedot format to do some reporting.
Each line is interpreted as an empty transaction:

```
$ hledger -f timedot:a.dat print 
2020-05-28 * 18:41 Eat Pizza

2020-05-29 * 09:00 Slept with the window open

2020-05-29 * 09:00 Headaches

```

And you could query those by date or description:

```
$ hledger -f timedot:a.dat print date:2020/5/28
2020-05-28 * 18:41 Eat Pizza

$ hledger -f timedot:a.dat print desc:eat
2020-05-28 * 18:41 Eat Pizza

```

Or by tag, if you added tags like so:

```
2020-05-28 18:41 Eat Pizza  ; food:
2020-05-29 09:00 Slept with the window open  ; body:, sleep:
2020-05-29 09:00 Headaches  ; body:
```
```
$ hledger -f timedot:b.dat print tag:sleep
2020-05-29 * 09:00 Slept with the window open  ; body:, sleep:

```

You could transform your format to a plain text accounting format with quantities.
Eg, make it TSV or CSV:

```
$ perl -pe '$c=0; $c++ while $c < 2 && s/ /\t/' a.dat > c.tsv
$ cat c.tsv
2020-05-28	18:41	Eat Pizza
2020-05-29	09:00	Slept with the window open
2020-05-29	09:00	Headaches
```

and use hledger CSV conversion rules to customise and enrich it:
```
$ cat c.tsv.rules
fields date, time, description

# save the time as a tag
comment time:%time

# count each item as one "event" by default
account1 (events)
amount1  1

# special cases
if pizza
 account1 (food)
 amount1  200 cal
```

Now you have a (single entry) accounting journal:
```
$ hledger -f c.tsv print

2020-05-28 Eat Pizza  ; time:18:41
    (food)         200 cal

2020-05-29 Slept with the window open  ; time:09:00
    (events)               1

2020-05-29 Headaches  ; time:09:00
    (events)               1

```

Allowing quantity reports:
```
$ hledger -f c.tsv balance -MATS cur:cal

Balance changes in 2020-05:

      ||     May    Total  Average 
======++===========================
 food || 200 cal  200 cal  200 cal 
------++---------------------------
      || 200 cal  200 cal  200 cal 
```
```
$ hledger -f c.tsv activity -D desc:headache
2020-05-28 
2020-05-29 *
```
```
$ hledger-bar -v -f c.tsv cur:cal
2020-05	       200 ++
```
```
$ hledger-ui --all -f c.tsv   # explore with a TUI
```