#!/bin/bash
#
# To run fs-test on rrz. Setting up environment, run it

flags="-nodb -io mpi -strided 1 -barriers aopen -barrier aclose"
flags1="-nodb -io mpi -strided 1 -barriers aopen -barrier aclose -deletefile"

testid1=pattern_plfs_9-15
testid2=plfs_221-9-15
fs_test_exe_1="/users/jun/installs/fs-test/bin/fs_test.x"
fs_test_exe_2=$fs_test_exe_1
backends="/panfs/scratch1/vol2/jun/.plfs_store"
plfsdir="/users/jun/mnt/plfs"
targetdir="plfs:$plfsdir"
objsize=4096





function set_pattern {
source /users/jun/workdir/plfs-tools/scripts/set_plfs_pattern_env-rrz.sh
#   echo "*******************"
#   unset LD_LIBRARY_PATH
#        plfs_map $plfsdir/$filename &> $filename.mapinfo
#   source ~/.cshrc-pattern
#   echo "PATTERN: $LD_LIBRARY_PATH"
#   which plfs
#   echo $PATH
#   env > out.1
}
function set_2.2.1 {
source /users/jun/workdir/plfs-tools/scripts/set_plfs221_vanilla-env-rrz.sh

#   echo "*******************"
#   unset LD_LIBRARY_PATH
#   export PATH=`echo $PATH | sed 's/[:]*pattern-plfs.*://'`
#   export MODULESHOME=/usr/share/Modules
#   . $MODULESHOME/init/bash
#   source ~/.cshrc-2.2.1
#   module list
#   echo "LATEST: $LD_LIBRARY_PATH"
#   echo "XXXXXX"
#   which plfs
#   echo $PATH
#   env > out.2
}

#nplist="32 64 128 256 512"
#nobjlist="8 32 128 512 2048 8192 32768 131072 524288 1048576"
nplist="16"
#nobjlist="8 32 128 512 2048 8192 32768 131072 524288 1048576"
nobjlist="262144"

for id in 1 2 3 4
do
    for np in $nplist 
    do
##    for nobj in "1 2 4 8 16 32 ... 1024*1024"
##    for nobj in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576
##    for nobj in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072
        for nobj in $nobjlist 
        do
            filename_pat=$np.$nobj.$objsize.$testid1
            filename_lat=$np.$nobj.$objsize.$testid2
        
            /bin/sync

            echo Writing......
            echo $filename_pat.$id
            echo $filename_lat.$id
             set_pattern
             mpirun -np $np $fs_test_exe_2 -type 2 -size $objsize -nobj $nobj -target $targetdir/$filename_pat -op write $flags  &> $filename_pat.log.write.$id
             set_2.2.1
             mpirun -np $np $fs_test_exe_1 -type 2 -size $objsize -nobj $nobj -target $targetdir/$filename_lat -op write $flags  &> $filename_lat.log.write.$id
        done
    done
    for np in $nplist 
    do
##    for nobj in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072
        for nobj in $nobjlist 
        do
            filename_pat=$np.$nobj.$objsize.$testid1
            filename_lat=$np.$nobj.$objsize.$testid2

            /bin/sync
            echo "Reading...... Uniform Restart"
            echo $filename_pat.$id
            echo $filename_lat.$id
            set_pattern
            mpirun -np $np $fs_test_exe_2 -type 2 -size $objsize -nobj $nobj -target $targetdir/$filename_pat -op read $flags   &> $filename_pat.log.read.uniform.$id
            set_2.2.1
            mpirun -np $np $fs_test_exe_1 -type 2 -size $objsize -nobj $nobj -target $targetdir/$filename_lat -op read $flags   &> $filename_lat.log.read.uniform.$id
        done
    done

    for np in $nplist 
    do
#    for nobj in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 
        for nobj in $nobjlist 
        do
            filename_pat=$np.$nobj.$objsize.$testid1
            filename_lat=$np.$nobj.$objsize.$testid2

            /bin/sync

            echo "Reading...... Non-Uniform Restart (half processes read)"
            echo $filename_pat.$id
            echo $filename_lat.$id
            nunobj=`expr $nobj \* 2`
            nunp=`expr $np / 2`
            set_pattern
            mpirun -np $nunp $fs_test_exe_2 -type 2 -size $objsize -nobj $nunobj -target $targetdir/$filename_pat -op read $flags   &> $filename_pat.log.read.nonuniform.$id
            set_2.2.1
            mpirun -np $nunp $fs_test_exe_1 -type 2 -size $objsize -nobj $nunobj -target $targetdir/$filename_lat -op read $flags   &> $filename_lat.log.read.nonuniform.$id
        done
    done

##for np in 16 32 64 128 256 512 
#for np in 256 
#do
#    for nobj in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576
##    for nobj in 32768 
#    do
#        filename_pat=$np.$nobj.$objsize.$testid1
#        filename_lat=$np.$nobj.$objsize.$testid2
#        echo $filename_pat
#        echo $filename_lat
#
#        /bin/sync
#
#        echo "Reading...... Archive (4 processes read)"
#        nunobj=1
#        nunp=4
#        nuobjsize=`expr $np \* $nobj \* $objsize / $nunp`  # so each proc reads 1/4 of the whole file
#        threshhold=4194304
#        if [ $nuobjsize -gt $threshhold ]
#        then
#            k=`expr $nuobjsize / $threshhold`
#            nunobj=$k
#            nuobjsize=$threshhold
#        fi
#        set_pattern
#        mpirun -np $nunp $fs_test_exe_2 -type 2 -size $nuobjsize -nobj $nunobj -target $targetdir/$filename_pat -op read $flags1   &> $filename_pat.log.read.archive
#        set_2.2.1
#        mpirun -np $nunp $fs_test_exe_1 -type 2 -size $nuobjsize -nobj $nunobj -target $targetdir/$filename_lat -op read $flags1   &> $filename_lat.log.read.archive
#    done
#done
done
