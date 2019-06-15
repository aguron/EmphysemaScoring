%%
% The following script changes the effective doses (mAs) of the
% LIDC-IDRI CT data. This code was adapted from noise Injection
% code written by Scott Hsieh (https://github.com/scotthsiehucla)
%
%%
% Parallel computing setup
plComputing             = true;
if (plComputing) && ~exist('pl2','var')
pl                     = parcluster;
pl.NumWorkers          = 12;
pl2                    = parpool(pl);
end

% Convert DICOM to DICOM (with specified mAs)
%%
% Location of LIDC-IDRI datasets
location                = ''; % Specify location of CT data
dataDir                 = [location, '/orig_mAs'];
d{1}                    = dir(dataDir);
d_temp                  = dir([dataDir, '/.*']);
d{1}(ismember({d{1}.name},{d_temp.name}))...
= [];

% New mAs
mAs_range                 = [15];


% Location for saving DICOM files generated from CT series data
if numel(mAs_range) > 1
dataDir2                  = [location, '/pbda_mAs'];
else
dataDir2                  = [location, sprintf('/%g_mAs', mAs_range)];
end

nPatients                 = numel(d{1});
% N.B. 8 out of 1010 patients have 2 CT series (e.g. LIDC-IDRI-0132, etc.)

% cancellous bone (e.g. ribs) at 700 HU
% air at -1000 HU
cutoff                    = [-1000 1000];

mAs_list                    = [];
for i=1:nPatients % Patients
new_mAs                   = mAs_range(1) + diff(mAs_range)*betarnd(1,5);
d{2}                     = dir([dataDir, '/', d{1}(i).name]);
d_temp                      = dir([dataDir, '/', d{1}(i).name, '/.*']);
d{2}(ismember({d{2}.name},{d_temp.name}))...
= [];
nModalities              = numel(d{2});
for j=1:nModalities % Modality
d{3}                    = dir([dataDir,...
                               '/', d{1}(i).name,...
                               '/', d{2}(j).name]);
d_temp                    = dir([dataDir,...
                                 '/', d{1}(i).name,...
                                 '/', d{2}(j).name, '/.*']);
d{3}(ismember({d{3}.name},{d_temp.name}))...
= [];
nSeries                 = numel(d{3});
for k=1:nSeries % Series
d{4}                   = dir([dataDir,...
                              '/', d{1}(i).name,...
                              '/', d{2}(j).name,...
                              '/', d{3}(k).name,...
                              '/*.dcm']);
nSlices                = numel(d{4});
parfor l=1:nSlices % Slices
metaInfo              = dicominfo([dataDir,...
                                   '/', d{1}(i).name,...
                                   '/', d{2}(j).name,...
                                   '/', d{3}(k).name,...
                                   '/', d{4}(l).name]);
if strcmp(metaInfo.Modality,'CT')
if ~isdir([dataDir2,'/',d{1}(i).name,'/',d{2}(j).name,'/',d{3}(k).name])
mkdir([dataDir2,'/',d{1}(i).name,'/',d{2}(j).name,'/',d{3}(k).name]);
end
if exist([dataDir2,'/',d{1}(i).name,'/',d{2}(j).name,'/',d{3}(k).name,'/',d{4}(l).name], 'file')
disp([dataDir2,'/',d{1}(i).name,'/',d{2}(j).name,'/',d{3}(k).name,'/',d{4}(l).name ' already exists']);
continue
end

CT                      = dicomread([dataDir,...
                                     '/', d{1}(i).name,...
                                     '/', d{2}(j).name,...
                                     '/', d{3}(k).name,...
                                     '/', d{4}(l).name]);

%% Noise Injection
PHOTON_FUDGE_FACTOR  = 15/25 / 1.02;

% Extract key parameters:
pixelSize            = metaInfo.PixelSpacing(1); % in mm
if (pixelSize < 0.976 || pixelSize > 0.977)
disp('pixelSize has to match the water cylinder protocol to be 100% accurate');
end

if isfield(metaInfo, 'ExposureTime')
mAs                   = metaInfo.XrayTubeCurrent * metaInfo.ExposureTime / 1000;
if (l == 1)
disp(['Existing mAs = ' num2str(mAs)]);
end
end % if isfield(metaInfo, 'ExposureTime')

% Forward project to get simulated raw data
scaleFactor          = 0.2 / 1000 * pixelSize/10;
viewSet              = 0.5:0.5:180;
sino                 =...
radon(scaleFactor * double(CT - cutoff(1) + metaInfo.RescaleIntercept), viewSet);
% path lengths of tissue that rays pass through
%      imshow(sino, []);
%      keyboard;

% spektr_v3 reports that for a 120 kVp spectrum with 3 mm Al, we have
% 2.2e6 photons/mm2/mAs at 1 m. Ignoring photons below 40 keV, this is
% 1.8e6. Note that slice thickness matters here too
PHOTONS_PER_MAS      = 1.8e6;

N_PHOTONS            =...
metaInfo.SliceThickness * PHOTONS_PER_MAS * pixelSize *...
new_mAs / numel(viewSet) * PHOTON_FUDGE_FACTOR;

% Calculate bowtie filter prefiltration
% bowtie filter thickness interpolated from SE McKenney et al, Med Phys 2011
filterThickness      = [0 10 40 70 85 100];
filterAngle          = 0:5:25; % sampled 6 datapoints of the curve by hand
% would be better to run a script to digitize this plot automatically
pmmaMultiplier          = 0.19 * 1.18 / 10; % convert PMMA thickness to attenuation

% Map channel index approximately to bowtie thickness
channelAngle         = (1:size(sino,1)) .* pixelSize / 1000 * 180/pi;
channelAngle         = channelAngle - mean(channelAngle(:));

% bowtieAttenuation holds the amount of material each ray is pre-filtered with
bowtieAttenuation    = interp1(filterAngle, filterThickness * pmmaMultiplier, abs(channelAngle), 'pchip');
bowtieAttenuation    = bowtieAttenuation';

photonMultiplier     = 1;
% fold bowtieAttenuation into the raw data
sinoLength           = bsxfun(@plus, sino, bowtieAttenuation);
% figure out how many photons are in each ray
sinoPhotons          = N_PHOTONS * photonMultiplier * exp(-sinoLength);
sinoI_0              = N_PHOTONS * photonMultiplier * exp(-bsxfun(@plus, sino*0, bowtieAttenuation));
% add Poisson noise to these photons
sinoNoisyPhotons     = poissrnd(sinoPhotons);
sinoNoisyPhotons(sinoNoisyPhotons == 0)...
= 0.1; % apply clipping
% convert back
sinoNoisy            = -log(sinoNoisyPhotons ./ sinoI_0);
%      sinoDiff             = sinoNoisy - sino;
%      imshow(sinoDiff, []);
%      keyboard;

% ADJUSTMENTS ----
filterType           = 'Ram-Lak';
dSino                = sinoNoisy - sino;
dSino                = imfilter(dSino, fspecial('gaussian', 5, 0.43));

noiseInject          = iradon(dSino, viewSet, filterType) ./ scaleFactor;

noiseAddedCT         = double(CT) + noiseInject(2:end-1,2:end-1);
%      imshow([CT, noiseAddedCT], [0 1200]);
%      keyboard;

dicomwrite(int16(noiseAddedCT),...
           [dataDir2,...
            '/', d{1}(i).name,...
            '/', d{2}(j).name,...
            '/', d{3}(k).name,...
            '/', d{4}(l).name],...
           metaInfo);
else % if strcmp(metaInfo.Modality,'DX')
continue % break
end
end % parfor l=1:nSlices % Slices
end % for k=1:nSeries % Series
end % for j=1:nModalities % Modality
mAs_list            = [mAs_list, new_mAs];
end % for i=1:nPatients % Patients

save([dataDir2, '/mAs_list.mat'], 'mAs_list')

%%
% Parallel computing tidying up
if (plComputing)
delete(gcp('nocreate'))
clear pl pl2
end % if (plComputing)
%%

