#!/usr/bin/env python

import sys

def main():
    f = open(sys.argv[1], "r")

    print "PID io Logical_offset Length Begin_timestamp End_timestamp  Logical_tail ID Chunk_offset"
    for line in f:
        if " w " in line:
            line = line.replace("[", "")
            line = line.replace("]", "")
            vals = line.split(".")
            print ".".join(vals[0:-1]) + " " +vals[-1].strip()



    f.close()


if __name__ == "__main__":
    main()
