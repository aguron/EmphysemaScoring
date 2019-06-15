''' Trains a U-Net in a segmentation task for Emphysema scoring
    Author: Akinyinka Omigbodun
    '''

from __future__ import print_function

with open('cfg/train_eval.cfg', 'r') as fp:
    cross_validation_info   = fp.readline() # line 1
    cross_validation_info   = cross_validation_info.rstrip()
    dataset_info            = fp.readline() # line 2
    dataset_info            = dataset_info.rstrip()
    input_info              = fp.readline() # line 3
    input_info              = input_info.rstrip()
    experiment_info         = fp.readline() # line 4
    experiment_info         = experiment_info.rstrip()
    network_info            = fp.readline() # line 5
    network_info            = network_info.rstrip()
    epoch_info              = fp.readline() # line 6
    epoch_info              = epoch_info.rstrip()
    im_rescale_info         = fp.readline() # line 7
    im_rescale_info         = im_rescale_info.rstrip()
    data_fraction_info      = fp.readline() # line 8
    data_fraction_info      = data_fraction_info.rstrip()
    batch_size_info         = fp.readline() # line 9
    batch_size_info         = batch_size_info.rstrip()
    sample_weight_info      = fp.readline() # line 10
    sample_weight_info      = sample_weight_info.rstrip()

import numpy as np
import model
import data
import os
import math
# os.environ["CUDA_DEVICE_ORDER"] = "PCI_BUS_ID" # so the IDs match nvidia-smi
# os.environ["CUDA_VISIBLE_DEVICES"] = "0" # "0, 1" for multiple

base = os.getcwd()
base = os.path.dirname(base)

# Prepare training and validation data
train_path_list         = []
validation_path_list    = []
input_data_path         = os.path.join(base, 'input_data', dataset_info)
for i in range(10):
    if i == (int(cross_validation_info)-1):
        continue
    train_path_list.append(os.path.join(input_data_path, str(i+1) + 'a'))
    validation_path_list.append(os.path.join(input_data_path, str(i+1) + 'b'))

image_folder            = "image"
mask_folder             = "label"
sample_weight_folder    = "label" # "pixel_weight"
image_prefix            = input_info
mask_prefix             = input_info

im_rescale              = 1./int(im_rescale_info)

#np.random.seed(2222)  # for reproducibility

sample_weight_info      = sample_weight_info.split(' ')
sample_weight_flag      = int(sample_weight_info[0])
sample_weight_dict      = {}
for i in range(1, int(len(sample_weight_info)/2 + 1)):
    sample_weight_dict[int(sample_weight_info[2*i-1])] = int(sample_weight_info[2*i])

model_dir               = os.path.join(base, "model_info", experiment_info, cross_validation_info, network_info + "_" + epoch_info, input_info)
train_data_dir          = os.path.join(model_dir, "train_data")
if not os.path.isdir(train_data_dir):
    os.makedirs(train_data_dir)
    data.dataAggregator(data_path_list=train_path_list, image_folder=image_folder, mask_folder=mask_folder,
                        image_prefix=image_prefix, mask_prefix=mask_prefix, save_to_dir=train_data_dir, prob=float(data_fraction_info))

validation_data_dir     = os.path.join(model_dir, "validation_data")
if not os.path.isdir(validation_data_dir):
    os.makedirs(validation_data_dir)
    data.dataAggregator(data_path_list=validation_path_list, image_folder=image_folder, mask_folder=mask_folder,
                        image_prefix=image_prefix, mask_prefix=mask_prefix, save_to_dir=validation_data_dir, prob=float(data_fraction_info))

# Model fitting
data_generator_info = dict(rescale=im_rescale) # Assumes images are stored in an 8-bit format
target_size         = (512, 512)
batch_size          = int(batch_size_info)
color_mode          = "grayscale"
seed                = 1

train_image_generator                   = data.dataGenerator(data_generator_info, train_data_dir, target_size, color_mode,
                                                             image_folder, batch_size, seed, sample_weight_flag=sample_weight_flag)
train_mask_generator                    = data.dataGenerator(data_generator_info, train_data_dir, target_size, color_mode,
                                                             mask_folder, batch_size, seed, sample_weight_flag=sample_weight_flag)
num_train_images                        = data.numImagesFolder(train_data_dir, image_folder)
if sample_weight_flag:
    sample_generator_info               = {}
    train_sample_weight_generator       = data.dataGenerator(sample_generator_info, train_data_dir, target_size, color_mode,
                                                             sample_weight_folder, batch_size, seed, sample_weight_flag=sample_weight_flag,
                                                             is_sample_weight=True, sample_weight_dict=sample_weight_dict, sample_rescale=im_rescale)
    train_generator                     = zip(train_image_generator, train_mask_generator, train_sample_weight_generator)
else:
    train_generator                     = zip(train_image_generator, train_mask_generator)

validation_image_generator              = data.dataGenerator(data_generator_info, validation_data_dir, target_size, color_mode,
                                                             image_folder, batch_size, seed, sample_weight_flag=sample_weight_flag)
validation_mask_generator               = data.dataGenerator(data_generator_info, validation_data_dir, target_size, color_mode,
                                                             mask_folder, batch_size, seed, sample_weight_flag=sample_weight_flag)
num_validation_images                   = data.numImagesFolder(validation_data_dir, image_folder)
if sample_weight_flag:
    validation_sample_weight_generator  = data.dataGenerator(sample_generator_info, validation_data_dir, target_size, color_mode,
                                                             sample_weight_folder, batch_size, seed, sample_weight_flag=sample_weight_flag,
                                                             is_sample_weight=True, sample_weight_dict=sample_weight_dict, sample_rescale=im_rescale)
    validation_generator                = zip(validation_image_generator, validation_mask_generator, validation_sample_weight_generator)
else:
    validation_generator                = zip(validation_image_generator, validation_mask_generator)

unet                = model.unet(input_size=target_size + (1,), sample_weight_flag=sample_weight_flag)
saved_model_dir     = os.path.join(model_dir, "saved_model")
if not os.path.isdir(saved_model_dir):
    os.makedirs(saved_model_dir)
filepath            = os.path.join(saved_model_dir, "lidc_weights-improvement-{epoch:02d}-{val_loss:.2f}.hdf5")
model_checkpoint    = model.ModelCheckpoint(filepath, monitor='val_loss', verbose=1, save_best_only=True, mode='min')
callbacks_list      = [model_checkpoint]
epochs              = int(epoch_info)
history_this        = unet.fit_generator(train_generator,
                                         steps_per_epoch=math.ceil(num_train_images/batch_size),
                                         epochs=epochs,
                                         verbose=1,
                                         callbacks=callbacks_list,
                                         validation_data=validation_generator,
                                         initial_epoch=0,
                                         validation_steps=math.ceil(num_validation_images/batch_size))

unet.save(os.path.join(model_dir, network_info + ".h5"))

model.K.clear_session()
