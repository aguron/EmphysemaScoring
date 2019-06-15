''' Evaluates a trained U-Net model in a segmentation task for Emphysema scoring
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
import prediction
import os
import glob
import math
# os.environ["CUDA_DEVICE_ORDER"] = "PCI_BUS_ID" # so the IDs match nvidia-smi
# os.environ["CUDA_VISIBLE_DEVICES"] = "0" # "0, 1" for multiple

base = os.getcwd()
base = os.path.dirname(base)

# Prepare test data
test_path_list              = []
input_data_path             = os.path.join(base, 'input_data', dataset_info)
test_path_list.append(os.path.join(input_data_path, cross_validation_info + 'a'))
test_path_list.append(os.path.join(input_data_path, cross_validation_info + 'b'))

image_folder    = "image"
mask_folder     = "label"
image_prefix    = input_info
mask_prefix     = input_info

im_rescale      = 1./int(im_rescale_info)

model_dir       = os.path.join(base, "model_info", experiment_info, cross_validation_info, network_info + "_" + epoch_info, input_info)
test_data_dir   = os.path.join(model_dir, "test_data")
if not os.path.isdir(test_data_dir):
    os.makedirs(test_data_dir)
    data.dataAggregator(data_path_list=test_path_list, image_folder=image_folder, mask_folder=mask_folder,
                        image_prefix=image_prefix, mask_prefix=mask_prefix, save_to_dir=test_data_dir, prob=float(data_fraction_info))

# Model predictions
target_size         = (512, 512)
sample_weight_info  = sample_weight_info.split(' ')
sample_weight_flag  = int(sample_weight_info[0])
unet                = model.unet(input_size=target_size + (1,), sample_weight_flag=sample_weight_flag)

saved_model_dir     = os.path.join(model_dir, "saved_model")
weightsFile         = max([os.path.basename(x) for x in glob.glob(os.path.join(saved_model_dir, "*.hdf5"))],
                          key=lambda f: os.path.getctime("{}/{}".format(saved_model_dir, f)))
weightsFile         = os.path.join(saved_model_dir, weightsFile)
print('evaluating with file ' + weightsFile)
unet.load_weights(weightsFile)

data_generator_info = dict(rescale=im_rescale) # Assumes images are stored in an 8-bit format
color_mode          = "grayscale"
image_folder        = "image"
batch_size          = int(batch_size_info)
seed                = 1

test_image_generator    = data.dataGenerator(data_generator_info, test_data_dir, target_size, color_mode,
                                             image_folder, batch_size, seed, sample_weight_flag=sample_weight_flag,
                                             is_test_data=True)
num_test_images         = data.numImagesFolder(test_data_dir, image_folder)

predictions             = unet.predict_generator(test_image_generator,
                                                 steps=math.ceil(num_test_images/batch_size),
                                                 verbose=1)


prediction_folder       = "prediction"
prediction.savePredictions(predictions,
                           target_size,
                           data_path_list=[test_data_dir],
                           prediction_folder=prediction_folder,
                           image_folder=image_folder,
                           image_prefix=image_prefix,
                           prediction_image_scale=int(im_rescale_info),
                           sample_weight_flag=sample_weight_flag)
prediction_prefix       = input_info
score                   = prediction.averageDice(predictions=[test_data_dir], masks=[test_data_dir],
                                                 prediction_folder=prediction_folder, mask_folder=mask_folder,
                                                 prediction_prefix=prediction_prefix, mask_prefix=mask_prefix)

print("Dice coefficient is %f" % score)
evaluation_dir          = os.path.join(base, "evaluation", experiment_info, cross_validation_info, network_info + "_" + epoch_info, input_info)
if not os.path.isdir(evaluation_dir):
    os.makedirs(evaluation_dir)
np.save(os.path.join(evaluation_dir, "dice_coefficient.npy"), score)

model.K.clear_session()
