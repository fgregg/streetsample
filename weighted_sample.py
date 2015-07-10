import sys
import csv
import numpy

def floatify(string) :
    try :
        return float(string)
    except ValueError :
            return float(int(string))
        
reader = csv.reader(sys.stdin)
next(reader)

choices, weights = zip(*(reader))

choices = numpy.array(choices, dtype='i4')
weights = numpy.array([floatify(weight) for weight in weights])
weights /= numpy.sum(weights)

sample = numpy.random.choice(choices, int(sys.argv[1]), replace=False, p=weights)

print("(" + ", ".join(sample.astype(str)) + ")")

