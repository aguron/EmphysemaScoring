from __future__ import print_function
from keras.preprocessing.image import ImageDataGenerator
import numpy as np
import os
import glob
import skimage.io as io
import concurrent.futures
import warnings

def numImagesFolder(data_dir, folder):
    """Return the number of PNG images in a folder."""
    image_names = glob.glob(os.path.join(data_dir, folder, "*.png"))
    num_images  = len(image_names)
    return num_images

def dataGenerator(data_generator_info, data_dir, target_size, color_mode, folder, batch_size, seed,
                  sample_weight_flag=False, is_sample_weight=False, sample_weight_dict={}, sample_rescale=1,
                  is_test_data=False):
    """Generate an image."""
    arg_dict        = dict(shuffle=not is_test_data)
    datagen         = ImageDataGenerator(**data_generator_info)
    data_generator  = datagen.flow_from_directory(data_dir,
                                                  target_size=target_size,
                                                  color_mode=color_mode,
                                                  classes=[folder],
                                                  class_mode=None,
                                                  batch_size=batch_size,
                                                  seed=seed,
                                                  **arg_dict)
    for img in data_generator:
        if sample_weight_flag:
            if is_sample_weight:
                for sample in sample_weight_dict:
                    img[img == sample]  = sample_weight_dict[sample] * sample_rescale
                img                     = img.reshape((len(img), -1))
            else:
                img                     = img.reshape((len(img), -1, 1))
        yield img


def dataAggregator(data_path_list, image_folder, mask_folder=None, image_prefix="", mask_prefix="",
                   image_color_mode="grayscale", mask_color_mode="grayscale", save_to_dir=None,
                   seed=1, target_size=(512,512), image_rescale=1, mask_rescale=1, prob=1.0):
    """Prepare (an) array(s) or (a) folder(s) with selected images with or without corresponding (segmentation) masks.
    save_to_dir is set to None if arrays are returned; otherwise, save_to_dir is set to the location where the images
    are to be saved.
    """
    imgs = np.array([])
    image_datagen = ImageDataGenerator()
    if mask_folder:
        masks = np.array([])
        mask_datagen = ImageDataGenerator()
    
    total_num_images    = 0
    if save_to_dir:
        if not os.path.isdir(os.path.join(save_to_dir, image_folder)):
            os.mkdir(os.path.join(save_to_dir, image_folder))
        if not os.path.isdir(os.path.join(save_to_dir, mask_folder)):
            os.mkdir(os.path.join(save_to_dir, mask_folder))
    for path in data_path_list:
        image_generator = image_datagen.flow_from_directory(path,
                                                            target_size=target_size,
                                                            color_mode=image_color_mode,
                                                            classes=[image_folder],
                                                            class_mode=None,
                                                            batch_size=1,
                                                            shuffle=False,
                                                            seed=seed,
                                                            save_to_dir=None,
                                                            save_prefix=None)
        num_images = len(image_generator.filenames)
        if mask_folder:
            mask_generator = mask_datagen.flow_from_directory(path,
                                                              target_size=target_size,
                                                              color_mode=mask_color_mode,
                                                              classes=[mask_folder],
                                                              class_mode=None,
                                                              batch_size=1,
                                                              shuffle=False,
                                                              seed=seed,
                                                              save_to_dir=None,
                                                              save_prefix=None)

        if mask_folder:
            with concurrent.futures.ProcessPoolExecutor() as executor:
                for include_pair_flag, img, mask in executor.map(includeImageMaskPair,
                                                                 np.random.choice(2, num_images, p=[1-prob, prob]),
                                                                 image_generator,
                                                                 mask_generator,
                                                                 image_generator.filenames,
                                                                 mask_generator.filenames,
                                                                 [image_prefix for _ in range(num_images)],
                                                                 [mask_prefix for _ in range(num_images)],
                                                                 [image_rescale] * num_images,
                                                                 [mask_rescale] * num_images,
                                                                 [save_to_dir for _ in range(num_images)]):
                    if include_pair_flag:
                        total_num_images += 1
                        if not save_to_dir:
                            if imgs.size == 0:
                                imgs = img
                                masks = mask
                            else:
                                imgs = np.append(imgs, img, axis=0)
                                masks = np.append(masks, mask, axis=0)
        else:
            with concurrent.futures.ProcessPoolExecutor() as executor:
                for include_image_flag, img in executor.map(includeImage,
                                                            np.random.choice(2, num_images, p=[1-prob, prob]),
                                                            image_generator,
                                                            image_generator.filenames,
                                                            [image_prefix for _ in range(num_images)],
                                                            [image_rescale] * num_images,
                                                            [save_to_dir for _ in range(num_images)]):
                    if include_pair_flag:
                        total_num_images += 1
                        if not save_to_dir:
                            if imgs.size == 0:
                                imgs = img
                            else:
                                imgs = np.append(imgs, img, axis=0)

    if mask_folder:
        print("Total number of selected images (masks): %d" % total_num_images)
        if not save_to_dir:
            return imgs, masks
    else:
        print("Total number of selected images: %d" % total_num_images)
        if not save_to_dir:
            return imgs

def includeImageMaskPair(include_pair_flag, img, mask, img_filename, mask_filename, image_prefix, mask_prefix, image_rescale, mask_rescale, save_to_dir, verbose=False):
    if include_pair_flag and img_filename.split("/")[-1].startswith(image_prefix) and mask_filename.split("/")[-1].startswith(mask_prefix):
        img = img * image_rescale
        mask = mask * mask_rescale
        if not save_to_dir:
            return include_pair_flag, img, mask
        else:
            with warnings.catch_warnings():
                if verbose:
                    warnings.simplefilter("ignore")
                io.imsave(os.path.join(save_to_dir, img_filename), img[0,:,:,0].astype(np.uint))
                io.imsave(os.path.join(save_to_dir, mask_filename), mask[0,:,:,0].astype(np.uint))
    return include_pair_flag, None, None

def includeImage(include_image_flag, img, img_filename, image_prefix, image_rescale, save_to_dir, verbose=False):
    if include_image_flag and img_filename.split("/")[-1].startswith(image_prefix):
        img = img * image_rescale
        if not save_to_dir:
            return include_image_flag, img
        else:
            with warnings.catch_warnings():
                if verbose:
                    warnings.simplefilter("ignore")
                io.imsave(os.path.join(save_to_dir, img_filename), img[0,:,:,0].astype(np.uint))
    return include_image_flag, None


def prepareSampleWeights(sample_weight_dict, save_to_dir, masks, sample_weight_folder):
    """Prepare images with values corresponding to the training loss weighting for different samples."""
    if type(masks) is np.ndarray:
        sample_weights = []
        with concurrent.futures.ProcessPoolExecutor() as executor:
            for sample_weight in executor.map(prepareSampleWeight,
                                              [sample_weight_dict] * num_images,
                                              list(masks),
                                              [masks for _ in range(num_images)],
                                              [sample_weight_folder for _ in range(num_images)]):
                if sample_weights.size == 0:
                    sample_weights = sample_weight
                else:
                    sample_weights = np.append(sample_weights, sample_weight, axis=0)
        return sample_weights
    elif type(masks) is str and save_to_dir:
        mask_name_array     = sorted(glob.glob(os.path.join(save_to_dir, masks, "*.png")))
        num_images          = len(mask_name_array)
        if not os.path.isdir(os.path.join(save_to_dir, sample_weight_folder)):
            os.mkdir(os.path.join(save_to_dir, sample_weight_folder))
            with concurrent.futures.ProcessPoolExecutor() as executor:
                for sample_weight in executor.map(prepareSampleWeight,
                                                  [sample_weight_dict] * num_images,
                                                  mask_name_array,
                                                  [masks for _ in range(num_images)],
                                                  [sample_weight_folder for _ in range(num_images)]):
                    pass
    return None

def prepareSampleWeight(sample_weight_dict, mask, mask_folder, sample_weight_folder, verbose=False):
    if type(mask) is np.ndarray:
        for sample in sample_weight_dict:
            mask[mask == sample] = sample_weight_dict[sample]
        return mask
    elif type(mask) is str:
        im_mask = io.imread(mask, as_gray = True)
        for sample in sample_weight_dict:
            im_mask[im_mask == sample] = sample_weight_dict[sample]
        with warnings.catch_warnings():
            if verbose:
                warnings.simplefilter("ignore")
            io.imsave(mask.replace('/' + mask_folder, '/' + sample_weight_folder), im_mask.astype(np.uint))
    return None

