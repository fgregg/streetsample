import sys
import csv
import numpy
from collections import defaultdict

def floatify(string) :
    try :
        return float(string)
    except ValueError :
            return float(int(string))
        
reader = csv.reader(sys.stdin)
next(reader)

cells = defaultdict(lambda : ([], []))
 
for row, col, street_gid, weight in reader :
    cells[row, col][0].append(street_gid) 
    cells[row, col][1].append(weight) 

sample = []

for choices, weights in cells.values() :
    choices = numpy.array(choices, dtype='i4')
    weights = numpy.array([floatify(weight) for weight in weights])
    weights = numpy.sqrt(weights + 1)
    weights /= numpy.sum(weights)

    sample += numpy.random.choice(choices, int(sys.argv[1]), replace=False, p=weights).astype(str).tolist()

print("(" + ", ".join(sample) + ")")

