#!/bin/bash
# Train and evaluate U-Net models in a lung emphysemic region segmentation task.
# Foreground comprises regions of CT lung images that satisfy the RA950 criteria.

cwd=$(pwd)

pkg_loc='' # Specify location of package

if [ "$HOSTNAME" == '' ]
then
    export LD_LIBRARY_PATH=/usr/local/cuda-8.0/lib64:$LD_LIBRARY_PATH
    export PATH=/usr/local/cuda-8.0/bin:$PATH
    source ~/keras-python3/bin/activate
elif [ "$HOSTNAME" == '' ]
then
    export LD_LIBRARY_PATH=/usr/local/cuda-8.0/lib64:$LD_LIBRARY_PATH
    export PATH=/usr/local/cuda-8.0/bin:$PATH
    source ~/keras-python3/bin/activate
elif [ "$HOSTNAME" == '' ]
then
    source ~/keras-python3/bin/activate
fi

gpu=$1
cvf=$2
dataset=$3
input=$4
experiment=$5
network=$6
num_epochs=$7
im_rescale=$8
data_fraction=$9
batch_size=${10}
sample_weights=${11}

###############
# Experiments #
###############
# 1: comparing performance on original and low dose (15 mAs) scans
##########################################

if [ ! -d model_info/cfg ]
then
    mkdir model_info/cfg
fi

############
# Training #
############
cat <<EOF >model_info/cfg/train_eval.cfg
$cvf
$dataset
$input
Experiment$experiment
$network
$num_epochs
$im_rescale
$data_fraction
$batch_size
$sample_weights
EOF
directory_out=$pkg_loc'/EmphysemaScoring/model_info/Experiment'$experiment'/'$cvf'/'$network'_'$num_epochs'/'$input'/saved_model/'
if [ ! -d "$directory_out" ]
then
    cd model_info/
    CUDA_VISIBLE_DEVICES=$gpu python3 train.py
    cd $cwd
fi

####################
# Dice Coefficient #
####################
cat <<EOF >model_info/cfg/train_eval.cfg
$cvf
$dataset
$input
Experiment$experiment
$network
$num_epochs
$im_rescale
$data_fraction
$batch_size
$sample_weights
EOF
file_out=$pkg_loc'/EmphysemaScoring/evaluation/Experiment'$experiment'/'$cvf'/'$network'_'$num_epochs'/'$input'/dice_coefficient.npy'
directory_model=$pkg_loc'/EmphysemaScoring/model_info/Experiment'$experiment'/'$cvf'/'$network'_'$num_epochs'/'$input'/saved_model/'
if [ ! -f "$file_out" ] && [ -d "$directory_model" ]
then
    cd model_info
    CUDA_VISIBLE_DEVICES=$gpu python3 evaluate.py
    cd $cwd
fi

deactivate
