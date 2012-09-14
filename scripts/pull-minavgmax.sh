#!/bin/bash

# This is a shell script that pull out the min, avg, max value of
# fs-test output.

testid=envtest_pattern_8-8
#testid=envtest_2.2.1_8-8

# pos : min 9; avg 12; max 13
extract_one () {
    keyword=$1
    pos=$2
    op=$3
    filename=$4
    rtype=$5

    str=`sh -c "grep \"$keyword\"  $filename.log.$op$rtype"`
    #echo $str
    val=`echo $str | cut -d ' ' -f $pos`
    if [ -z $val ] 
    then
        val=NA
    fi

    echo $val
}


extract_all_write () {
    filename=$1
    
    open_min=`extract_one "File_Write_Open Time" 9 "write" $filename`
    echo $open_min
    open_avg=`extract_one "File_Write_Open Time" 12 "write" $filename`
    echo $open_avg
    open_max=`extract_one "File_Write_Open Time" 13 "write" $filename`
    echo $open_max

    band_min=`extract_one "Write Bandwidth" 9 "write" $filename`
    echo $band_min
    band_avg=`extract_one "Write Bandwidth" 12 "write" $filename`
    echo $band_avg
    band_max=`extract_one "Write Bandwidth" 13 "write" $filename`
    echo $band_avg

    eband_min=`extract_one "Effective Bandwidth" 9 "write" $filename`
    echo $eband_min
    eband_avg=`extract_one "Effective Bandwidth" 12 "write" $filename`
    echo $eband_avg
    eband_max=`extract_one "Effective Bandwidth" 13 "write" $filename`
    echo $eband_max

    close_min=`extract_one "Write_File_Close_Wait Time" 9 "write" $filename`
    echo $close_min
    close_avg=`extract_one "Write_File_Close_Wait Time" 12 "write" $filename`
    echo $close_avg
    close_max=`extract_one "Write_File_Close_Wait Time" 13 "write" $filename`
    echo $close_max
}

extract_all_read () {
    filename=$1
    rtype=".$2"
    
    open_min=`extract_one "File_Read_Open Time" 9 "read" $filename $rtype`
    echo $open_min
    open_avg=`extract_one "File_Read_Open Time" 12 "read" $filename $rtype`
    echo $open_avg
    open_max=`extract_one "File_Read_Open Time" 13 "read" $filename $rtype`
    echo $open_max

    band_min=`extract_one "Read Bandwidth" 9 "read" $filename $rtype`
    echo $band_min
    band_avg=`extract_one "Read Bandwidth" 12 "read" $filename $rtype`
    echo $band_avg
    band_max=`extract_one "Read Bandwidth" 13 "read" $filename $rtype`
    echo $band_avg

    eband_min=`extract_one "Effective Bandwidth" 9 "read" $filename $rtype`
    echo $eband_min
    eband_avg=`extract_one "Effective Bandwidth" 12 "read" $filename $rtype`
    echo $eband_avg
    eband_max=`extract_one "Effective Bandwidth" 13 "read" $filename $rtype`
    echo $eband_max

    close_min=`extract_one "Read_File_Close_Wait Time" 9 "read" $filename $rtype`
    echo $close_min
    close_avg=`extract_one "Read_File_Close_Wait Time" 12 "read" $filename $rtype`
    echo $close_avg
    close_max=`extract_one "Read_File_Close_Wait Time" 13 "read" $filename $rtype`
    echo $close_max
}



echo np nobj objsize testid \
     wopen.min wopen.avg wopen.max \
     wband.min wband.avg wband.max \
     ewband.min ewband.avg ewband.max \
     wclose.min wclose.avg wclose.max \
     ropen.min.uni ropen.avg.uni ropen.max.uni \
     rband.min.uni rband.avg.uni rband.max.uni \
     erband.min.uni erband.avg.uni erband.max.uni \
     rclose.min.uni rclose.avg.uni rclose.max.uni \
     ropen.min.nonuni ropen.avg.nonuni ropen.max.nonuni \
     rband.min.nonuni rband.avg.nonuni rband.max.nonuni \
     erband.min.nonuni erband.avg.nonuni erband.max.nonuni \
     rclose.min.nonuni rclose.avg.nonuni rclose.max.nonuni \
     ropen.min.archive ropen.avg.archive ropen.max.archive \
     rband.min.archive rband.avg.archive rband.max.archive \
     erband.min.archive erband.avg.archive erband.max.archive \
     rclose.min.archive rclose.avg.archive rclose.max.archive 

objsize=4096
for np in 8 64 256 
#for np in 1 2 4 8 32 64 128 256 512 
do
    for nobj in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 
    do
        filename=$np.$nobj.$objsize.$testid
        
        writeperf=`extract_all_write $filename`
        readuniform=`extract_all_read $filename uniform`
        readnonuniform=`extract_all_read $filename nonuniform`
        #readarchive=`extract_all_read $filename archive`
        echo $np $nobj $objsize $testid \
             $writeperf $readuniform $readnonuniform $readarchive
    done
done

