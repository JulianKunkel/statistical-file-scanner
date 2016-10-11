#!/usr/bin/env python
#@author Julian Kunkel

import re
import sys
import numpy
import scipy
from collections import defaultdict

if len(sys.argv) < 3:
    print("Synopsis:  <sampleCountPerThread> <threadcount> <filelist1> ...")
    sys.exit(1)

sampleCount = int(sys.argv[1])
threadcount = int(sys.argv[2])

re_path = re.compile("(/.*):$")
re_file = re.compile("-[^ ]* +[0-9] +([0-9_a-zA-Z]*) +([0-9_a-zA-Z]*) +(?P<size>[0-9]+) +[0-9\-]+ +([0-9\-:]+)? +(?P<name>.*)$")

files = []
totalsize = 0

filelist = sys.argv[3:]

for filen in filelist:
    f = open(filen, 'r')
    for line in f:
        m = re_path.match(line)
        if m:
            dirname = m.group(1)
            continue
        m = re_file.match(line)
        if m:
            size = int(m.group("size"))
            name = dirname + "/" + m.group("name")
            totalsize = totalsize + size
            files.append((name, size))
            continue
    f.close()

## make the selection randomly weighted by the file size

totalsizeF = float(totalsize)
probabilities = []
for filet in files:
    probabilities.append(filet[1] / totalsizeF)

def unique(seq):
    seen = set()
    seen_add = seen.add
    return [x for x in seq if not (x in seen or seen_add(x))]

countperfile = defaultdict(int)
values = numpy.arange(0, len(files))
saved_scans = 0
totalsize = 0

for threadNum in range(1, threadcount + 1):
    f = open("thread-filelist-%d" % (threadNum)  , 'w')
    selected = numpy.random.choice(values, p=probabilities, size=sampleCount, replace=True)
    seen = set()
    seen_add = seen.add

    for s in selected:
      countperfile[s]+=1;
      w = files[s]
      if not (s in seen or seen_add(s)):
        f.write("%d %s\n" % (w[1], w[0]))
        totalsize = totalsize + w[1]
      else:
        f.write("AGAIN %s\n" % w[0])
        saved_scans = saved_scans + w[1]

    f.close()

print("done\n")

print("scan: %d MiB, saved scans: %d MiB" % (totalsize / 1024 / 1024, saved_scans / 1024 / 1024))

print("overview of the selection")

selectionsorted_byweight = sorted([ (x, countperfile[x]) for x in countperfile ], key=lambda x: x[1], reverse=True)
for selected in selectionsorted_byweight:
    w = files[selected[0]]
    print("%d %d %s" % (selected[1], w[1], w[0]))

sys.exit(0)
