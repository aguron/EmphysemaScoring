#!/bin/bash
# From the LIDC-IDRI data, create CT data with an artificially modified dose.

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
/usr/local/MATLAB/$m/bin/matlab -r "try; preprocessdata_mAs; copyxml; catch err; displayerror(err); keyboard; end; quit"
cd $cwd
