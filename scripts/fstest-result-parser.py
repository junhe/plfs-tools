#!/usr/bin/python

import sys
import re

if __name__ == '__main__':
    filename = sys.argv[1]
    perfnames = ['Effective.Bandwidth', 'File_Read_Open.Time', 'File_Read_Wait.Time', 'File_Write_Open.Time', 'File_Write_Wait.Time', 'Read.Bandwidth', 'Read.Time', 'Read_File_Sync.Time', 'Total.Time', 'Write.Bandwidth', 'Write.Time', 'Write_Barrier_wait.Time']
    print perfnames
    results = open(filename, 'r')

    
    perfs = {} # used to store the performance
    for line in results:
        m = re.search(r'=== (.*) \(min .*: ([0-9\.e\+]+) \[ *\d+\]\s*([0-9\.e\+]+)\s*([0-9\.e\+]+)', 
                      line, re.I|re.M)
        if m:
            # extrat val out
            tname = m.group(1).lstrip().replace(" ", ".")
            perfs[ tname + '.min' ] = m.group(2)
            perfs[ tname + '.avg'] = m.group(3)
            perfs[ tname + '.max'] = m.group(4)
            #perfnames.append(perfdict['name'])
        
        if "=== Completed IO Write." in line:
            # finished parsing one run -> output results
            header = []
            nums = []
            for p in perfnames:
                vals = ['min', 'avg', 'max']
                for v in vals:
                    key = p+'.'+v
                    header.append(key)
                    if perfs.has_key(key):
                        nums.append( perfs[key] )
                    else:
                        nums.append("NA")
            perfs = {}
            print ' '.join(header)
            print ' '.join(nums) 

    #print len(perfnames)
    #print len(set(perfnames))
    #perfnames = sorted(set(perfnames))
    #print perfnames
