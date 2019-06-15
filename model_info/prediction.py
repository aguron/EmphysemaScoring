from __future__ import print_function
import numpy as np
import os
import glob
import skimage.io as io
import warnings

def averageDice(predictions, masks, prediction_folder="", mask_folder="", prediction_prefix="", mask_prefix=""):
    score = 0
    i = 0
    if type(predictions) is np.ndarray and type(masks) is np.ndarray:
        for i, _ in enumerate(predictions):
            segmentation = np.asarray(predictions[i,:,:,0]).astype(np.bool)
            ground_truth = np.asarray(masks[i,:,:,0]).astype(np.bool)
            score += dice(segmentation, ground_truth)
    elif type(predictions[0]) is str and type(masks[0]) is str and type(predictions) is not str and type(masks) is not str:
        for path1, path2 in zip(predictions, masks):
            prediction_name_arr = sorted(glob.glob(os.path.join(path1, prediction_folder, prediction_prefix + "*.png")))
            label_name_arr = sorted(glob.glob(os.path.join(path2, mask_folder, mask_prefix + "*.png")))
            if len(prediction_name_arr) != len(label_name_arr):
                raise ValueError("prediction_name_arr and label_name_arr must have the same length.")
            for name1, name2 in zip(prediction_name_arr, label_name_arr):
                segmentation = io.imread(name1, as_gray = True)
                ground_truth = io.imread(name2, as_gray = True)
                segmentation = np.asarray(segmentation).astype(np.bool)
                ground_truth = np.asarray(ground_truth).astype(np.bool)
                score += dice(segmentation, ground_truth)
                i += 1
    else:
        raise TypeError("Type mismatch: predictions and masks must either both be numpy arrays or arrays of strings (indicating directories).")
    
    return score / (i + 1)

def dice(im1, im2, empty_score=1.0):
    if im1.shape != im2.shape:
        raise ValueError("Shape mismatch: im1 and im2 must have the same shape.")
    im_sum = im1.sum() + im2.sum()
    if im_sum == 0:
        return empty_score
    intersection = np.logical_and(im1, im2)
    return 2. * intersection.sum() / im_sum

def savePredictions(predictions, target_size, data_path_list, prediction_folder, image_folder, image_prefix="", prediction_image_scale=255,
                    sample_weight_flag=False, verbose=False):
    j = 0
    for path in data_path_list:
        image_name_arr = glob.glob(os.path.join(path, image_folder, image_prefix + "*.png"))
        for name in image_name_arr:
            if sample_weight_flag:
                item = predictions[j,:,0]
                item = item.reshape(target_size)
            else:
                item = predictions[j,:,:,0]
        
            img                 = np.zeros(item.shape)
            img[item > 0.5]     = prediction_image_scale
            img[item <= 0.5]    = 0
            name                = name.split("/")[-1].split(".")[0]
            if not os.path.isdir(os.path.join(path, prediction_folder)):
                os.mkdir(os.path.join(path, prediction_folder))
            with warnings.catch_warnings():
                if verbose:
                    warnings.simplefilter("ignore")
                io.imsave(os.path.join(path, prediction_folder, "%s.png" % name), img.astype(np.uint))
            j += 1
