%%
%
% The following script changes the slice thicknesses of the LIDC-IDRI CT data.
%
%%
% Parallel computing setup
plComputing             = true;
if (plComputing) && ~exist('pl2','var')
 pl                     = parcluster;
 pl.NumWorkers          = 12;
 pl2                    = parpool(pl);
end

% Convert DICOM to DICOM (with specified z-spacing factor)
%%
% Location of LIDC-IDRI datasets
location                  = ''; % Specify location of CT data
dataDir                   = [location, '/orig_mAs'];
d{1}                      = dir(dataDir);
d_temp                   	= dir([dataDir, '/.*']);
d{1}(ismember({d{1}.name},{d_temp.name}))...
                          = [];

% Meta-information
load('metaInfo','PatientIndex','ModalityIndex','SeriesIndex','SliceLocation')

% Z-spacing factor
z_range                     = [2];

if any(mod(z_range,1) ~= 0) || any(z_range <= 0)
 error('z_range must be positive integers');
end

% Location for saving DICOM files generated from CT series data
if numel(z_range) > 1
dataDir2                  = [location, '/pbda_z'];
else
dataDir2                  = [location, sprintf('/%d_z', z_range)];
end

nPatients                 = numel(d{1});
% N.B. 8 out of 1010 patients have 2 CT series (e.g. LIDC-IDRI-0132, etc.)

z_list                    = [];
for i=1:nPatients % Patients
 new_z                      = z_range(randi(numel(z_range)));
 dataDir3                   = [location, sprintf('/%d_z', new_z)];
 if isdir([dataDir3, '/', d{1}(i).name]) && ~isdir([dataDir2, '/', d{1}(i).name])
 mkdir([dataDir2, '/', d{1}(i).name])
 copyfile([dataDir3, '/', d{1}(i).name], [dataDir2, '/', d{1}(i).name])
 continue
 end
 d{2}                       = dir([dataDir, '/', d{1}(i).name]);
 d_temp                  	= dir([dataDir, '/', d{1}(i).name, '/.*']);
 d{2}(ismember({d{2}.name},{d_temp.name}))...
                          = [];
 % nModalities            = numel(d{2});
 modalities               = unique(ModalityIndex(PatientIndex==i));
 nModalities              = numel(d{2});
 for j=modalities % Modality
  d{3}                    = dir([dataDir,...
                                 '/', d{1}(i).name,...
                                 '/', d{2}(j).name]);
  d_temp                	= dir([dataDir,...
                                 '/', d{1}(i).name,...
                                 '/', d{2}(j).name, '/.*']);
  d{3}(ismember({d{3}.name},{d_temp.name}))...
                          = [];
  % nSeries              	= numel(d{3});
  series                  = unique(SeriesIndex(PatientIndex==i & ModalityIndex==j));
  for k=series % Series
   d{4}                   = dir([dataDir,...
                                 '/', d{1}(i).name,...
                                 '/', d{2}(j).name,...
                                 '/', d{3}(k).name,...
                                 '/*.dcm']);
   nSlices                = numel(d{4});
   z                      = SliceLocation(PatientIndex==i & ModalityIndex==j & SeriesIndex==k);
   if (nSlices ~= numel(z))
    error('Mismatch in the number of slices');
   else
    [~, r]                = sort(z,'ascend');
   end % if (nSlices ~= numel(z))

   metaInfo               = dicominfo([dataDir,...
                                       '/', d{1}(i).name,...
                                       '/', d{2}(j).name,...
                                       '/', d{3}(k).name,...
                                       '/', d{4}(1).name]);
   if strcmp(metaInfo.Modality,'CT')
    if ~isdir([dataDir2,'/',d{1}(i).name,'/',d{2}(j).name,'/',d{3}(k).name])
     mkdir([dataDir2,'/',d{1}(i).name,'/',d{2}(j).name,'/',d{3}(k).name]);
    end

    parfor l=1:floor(nSlices/new_z)
     if exist([dataDir2,'/',d{1}(i).name,'/',d{2}(j).name,'/',d{3}(k).name,...
               '/',d{4}(r(l*new_z)).name], 'file')
      for m=1:new_z
       disp([dataDir2,'/',d{1}(i).name,'/',d{2}(j).name,'/',d{3}(k).name,...
             '/',d{4}(r((l-1)*new_z+m)).name ' already exists']);
      end % for m=1:new_z
      continue
     end
     CT                   = zeros(512);
     for m=1:new_z
      CT                	= CT + double(dicomread([dataDir,...
                                                   '/', d{1}(i).name,...
                                                   '/', d{2}(j).name,...
                                                   '/', d{3}(k).name,...
                                                   '/', d{4}(r((l-1)*new_z+m)).name]));
     end % for m=1:new_z
     CT                   = CT/new_z;
     for m=1:new_z
      metaInfo            = dicominfo([dataDir,...
                                       '/', d{1}(i).name,...
                                       '/', d{2}(j).name,...
                                       '/', d{3}(k).name,...
                                       '/', d{4}(r((l-1)*new_z+m)).name]);
      dicomwrite(int16(CT),...
               	 [dataDir2,...
                  '/', d{1}(i).name,...
                  '/', d{2}(j).name,...
                  '/', d{3}(k).name,...
                  '/', d{4}(r((l-1)*new_z+m)).name],...
                 metaInfo);
     end % for m=1:new_z
    end % parfor l=1:floor(nSlices/new_z)
    l                     = ceil(nSlices/new_z);
    for m=1:mod(nSlices,new_z)
     metaInfo            	= dicominfo([dataDir,...
                                       '/', d{1}(i).name,...
                                       '/', d{2}(j).name,...
                                       '/', d{3}(k).name,...
                                       '/', d{4}(r((l-1)*new_z+m)).name]);
     CT                   = double(dicomread([dataDir,...
                                            	'/', d{1}(i).name,...
                                              '/', d{2}(j).name,...
                                              '/', d{3}(k).name,...
                                              '/', d{4}(r((l-1)*new_z+m)).name]));
     dicomwrite(int16(CT),...
                [dataDir2,...
                 '/', d{1}(i).name,...
                 '/', d{2}(j).name,...
                 '/', d{3}(k).name,...
                 '/', d{4}(r((l-1)*new_z+m)).name],...
                metaInfo);
    end % for m=1:mod(nSlices,new_z)
   else % if strcmp(metaInfo.Modality,'DX')
    continue
   end
  end % for k=series % Series
 end % for j=modalities % Modality
 z_list            = [z_list, new_z];
end % for i=1:nPatients % Patients

save([dataDir2, '/z_list.mat'], 'z_list')

%%
% Parallel computing tidying up
if (plComputing)
 delete(gcp('nocreate'))
 clear pl pl2
end % if (plComputing)
%%
