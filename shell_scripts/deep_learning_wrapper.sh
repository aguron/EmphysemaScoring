#!/bin/bash
# Train and evaluate U-Net models in a lung emphysemic region segmentation task.
# Foreground comprises regions of CT lung images that satisfy the RA950 criteria.

gpu=3
for cvf in {1..1} # {1..10}
do
    dataset=LIDC
    for input in orig # 15_mAs
    do
        experiment=1
        network=unet
        num_epochs=5
        im_rescale=255 # working with 8-bit images
        data_fraction=0.05
        batch_size=4
        # working with 8-bit images:
        #   sample of background (0) mapped to training loss weight 127
        #   sample of foreground (255) mapped to training loss weight of 255
        sample_weights="1 0 127 255 255"
        bash shell_scripts/deep_learning.sh $gpu $cvf $dataset $input $experiment $network $num_epochs $im_rescale $data_fraction $batch_size "$sample_weights"
    done
done
