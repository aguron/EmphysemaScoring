#!/bin/bash
# Script for generating a MATLAB variable with information on how the LIDC-IDRI CT data
# should be partitioned into data for training, validation, and testing.
cwd=$(pwd)

if [ "$HOSTNAME" == '' ]
then
    m=R2018a
elif [ "$HOSTNAME" == '' ]
then
    m=R2017a
else
    m=R2017a
fi

cd preprocessing
/usr/local/MATLAB/$m/bin/matlab -r "try; script(1).range = 1:80; script(2).range = 81:101; for i=2:10; script(2*i-1).range = script(2*(i-1)-1).range + 101; script(2*i).range = script(2*(i-1)).range + 101; end; save('cfg/script_lidc.mat', 'script'); catch err; displayerror(err); keyboard; end; quit"
cd $cwd
