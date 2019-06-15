%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  generate lung CT RA950 segmentation masks
%
%  adapted from code by Shiwen Shen


clc;
close all;
wkdir = pwd;

fid                     = fopen('cfg/preprocessing.cfg');
preprocessingInfo       = fgetl(fid); % line 1
dataDirectory           = preprocessingInfo;
preprocessingInfo       = fgetl(fid); % line 2
segmentationDirectory   = preprocessingInfo;
preprocessingInfo       = fgetl(fid); % line 3
r                       = str2double(preprocessingInfo);
preprocessingInfo       = fgetl(fid); % line 4
dataRangeInfo           = preprocessingInfo;
preprocessingInfo       = fgetl(fid); % line 5
augmented               = logical(str2double(preprocessingInfo));
if (augmented)
    preprocessingInfo   = fgetl(fid); % line 6
    maskDataDirectory   = preprocessingInfo;
else
    fgetl(fid); % line 6
end % if (augmented)
preprocessingInfo       = fgetl(fid); % line 7
dataType                = preprocessingInfo;
fclose(fid);
patientCaseFolderList   = dir(dataDirectory);
patientCaseFolderList   = patientCaseFolderList(cellfun(@(x)isdir([dataDirectory,x]),{patientCaseFolderList.name}));

for k = length(patientCaseFolderList):-1:1

    % remove file names starting with .
    fname = patientCaseFolderList(k).name;
    if fname(1) == '.'
        patientCaseFolderList(k) = [ ];
    end
end

load(dataRangeInfo);
patients_omitted        = [];
for i = intersect(1:numel(patientCaseFolderList), script(r).range)
    d                   = dir([segmentationDirectory, 'image/', dataType, '_', num2str(i), '_*']);
    if ~isempty(d)
        continue
    end

    patientCase         = [dataDirectory patientCaseFolderList(i).name '/'];
    if exist('maskDataDirectory', 'var')
        maskPatientCase = [maskDataDirectory patientCaseFolderList(i).name '/'];
    end % if exist('maskDataDirectory', 'var')
    patientCasef1       = dir(patientCase);
    for k = length(patientCasef1):-1:1

        % remove file names starting with .
        fname = patientCasef1(k).name;
        if fname(1) == '.'
            patientCasef1(k) = [ ];
        end
    end

    for k=1:length(patientCasef1)
     patientCase1       = [patientCase patientCasef1(k).name '/'];
     if exist('maskDataDirectory', 'var')
        maskPatientCase1= [maskPatientCase patientCasef1(k).name '/'];
     end % if exist('maskDataDirectory', 'var')
     patientCasef2      = dir(patientCase1);
     for j = length(patientCasef2):-1:1

         % remove file names starting with .
         fname = patientCasef2(j).name;
         if fname(1) == '.'
             patientCasef2(j) = [ ];
         end
     end

     for j=1:length(patientCasef2)
      d = dir([patientCase1 patientCasef2(j).name '/*.dcm']);
      flag = false;
      if numel(d) >= 65
       flag = true;
       break
      end % if numel(d) >= 65
     end
     if (flag)
      break
     end
    end

    patientCase2=[patientCase1 patientCasef2(j).name '/'];
    if exist('maskDataDirectory', 'var')
        maskPatientCase2=[maskPatientCase1 patientCasef2(j).name '/'];
    end % if exist('maskDataDirectory', 'var')
    cd(patientCase2);
    
    d = dir('*.dcm');
    if numel(d) < 65
        disp([patientCaseFolderList(i).name,' (',num2str(i),')', ': non-CT data']);
        patients_omitted    = [patients_omitted, i];
        % patientCaseFolderList(i).name
        continue
    end

    d = dir('*.xml');
    if isempty(d) % length(d)~=1
        disp([patientCaseFolderList(i).name,' (',num2str(i),')', ': missing CT metadata']);
        patients_omitted    = [patients_omitted, i];
        % patientCaseFolderList(i).name
        continue;
    end
    
    inputFile       = [patientCase2 d(1).name];
    
    cd(wkdir);
    [volume_image,sliceLocationArray,xyzSpacing,rescaleSlope,rescaleIntercept]=dataReorganize(patientCase2);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %    image -->> HU
    volume_image    = volume_image*rescaleSlope+rescaleIntercept;
    if exist('maskDataDirectory', 'var')
        volume_image2=volume_image;
        cd(wkdir);
        volume_image=dataReorganize(maskPatientCase2);
        volume_image=volume_image*rescaleSlope+rescaleIntercept;
    end % if exist('maskDataDirectory', 'var')


    cd(wkdir);
    try
     [maskImageVolume,thresh_adaptive] = segmentation( volume_image );
    catch err
     disp([patientCaseFolderList(i).name,' (',num2str(i),')', ': problem with lung segmentation']);
     patients_omitted   = [patients_omitted, i];
     continue
    end

    maskRefined         = maskRefine( maskImageVolume );
    if exist('maskDataDirectory', 'var')
        [volume_image, volume_image2] = deal(volume_image2, volume_image);
    end % if exist('maskDataDirectory', 'var')
    max_intensity       = -200;
    min_intensity       = -1200;
    maskRA950           = maskRefined & (volume_image < -950) & (volume_image >= min_intensity);

    if ~isdir(segmentationDirectory)
     mkdir(segmentationDirectory)
    end % if ~isdir(segmentationDirectory)

    percentLung         = squeeze(mean(mean(maskRefined,1),2));
    percentRA950        = squeeze(mean(mean(maskRA950,1),2));
    thresholdLung       = 0.08;
    if ~isempty(percentLung(percentLung>thresholdLung))
        for s=1:size(maskRA950,3)
            if (percentLung(s)>thresholdLung)
                im              = volume_image(:,:,s);
                im              = (im - min_intensity)/(max_intensity-min_intensity);
                if ~isdir([segmentationDirectory, 'image'])
                    mkdir([segmentationDirectory, 'image'])
                end % if ~isdir([segmentationDirectory, 'image'])
                imwrite(uint8(255*im), [segmentationDirectory, 'image/', dataType, '_', num2str(i), '_', num2str(s), '.png']);
                if ~isdir([segmentationDirectory, 'label'])
                    mkdir([segmentationDirectory, 'label'])
                end % if ~isdir([segmentationDirectory, 'label'])
                imwrite(uint8(255*maskRA950(:,:,s)), [segmentationDirectory, 'label/', dataType, '_', num2str(i), '_', num2str(s), '.png']);
            end % if (percentLung(s)>thresholdLung)
        end % for s=1:size(maskRA950,3)
    else % if ~isempty(percentLung(percentLung>thresholdLung))
        patients_omitted    = [patients_omitted, i];
    end
end

if exist([segmentationDirectory, 'patients_omitted.mat'], 'file')
    temp                    = load([segmentationDirectory, 'patients_omitted.mat']);
    patients_omitted        = unique([patients_omitted, temp.patients_omitted]);
    save([segmentationDirectory,'patients_omitted.mat'],'patients_omitted','-append')
else
    save([segmentationDirectory,'patients_omitted.mat'],'patients_omitted')
end
