#!/bin/bash
# Script for partitioning LIDC-IDRI into CT data for training, validation, and testing
#
cwd=$(pwd)

data_loc='' # Specify location of CT data
pkg_loc='' # Specify location of package

if [ "$HOSTNAME" == '' ]
then
    m=R2018a
elif [ "$HOSTNAME" == '' ]
then
    m=R2017a
else
    m=R2017a
fi

type=$1 # CT parameter

for r in $(eval echo {$2..$3})
do

if [ $(($r % 2)) == 1 ]
then
    s=$(($(($r / 2)) + 1))a
else
    s=$(($r / 2))b
fi

if [ "$type" == 'mAs' ]
then
    declare -a arr=('orig' 'pbda' '15' '1.5') # mAs-modified dose
    declare -a arr2=(0 1 1 1) # set to 0 for preprocessing; otherwise, set to 1
elif [ "$type" == 'z' ]
then
    declare -a arr=('pbda' '2' '3') # slice thickness modification
    declare -a arr2=(1 1 1) # set to 0 for preprocessing; otherwise, set to 1
fi

count=0
for d in "${arr[@]}"
do

dataType=$d
if [ "$dataType" != 'orig' ]
then
    dataType=${dataType}_$type
fi

if [ "$d" == 'orig' ]
then
    b=0
else
    b=1
fi

########################
# Generate RA950 Masks #
########################
if [ "$d" == 'orig' ]
then
    for loc in CT
    do
        cd $data_loc/$loc
            for par in mAs z
            do
                if [ -d orig_$par ] && [ ! -d orig_$type ]
                then
                    ln -s orig_$par orig_$type
                    break
                fi
            done
        cd $cwd
    done
fi

if [ ${arr2[$count]} != 1 ]
then

cat <<EOF >preprocessing/cfg/preprocessing.cfg
$data_loc/CT/${d}_${type}/
$pkg_loc/EmphysemaScoring/input_data/LIDC/$s/
$r
cfg/script_lidc.mat
$b
$data_loc/orig_${type}/
$dataType
EOF
cd preprocessing
/usr/local/MATLAB/$m/bin/matlab -r 'try;  segment_RA950; catch err; displayerror(err); keyboard; end; quit'
cd $cwd

fi

count=$(( $count + 1 ))
done
done
