% Parallel computing setup
plComputing             = true;
if (plComputing) && ~exist('pl2','var')
 pl                     = parcluster;
 pl.NumWorkers          = 12;
 pl2                    = parpool(pl);
end

% Copy XML files from DICOM (original dose/thickness) to DICOM (modified dose/thickness)
%%
% New mAs or slice thickness

type                      = 'mAs';
switch(type)
 case 'mAs'
  mAs_range                 = 15; % [1.5 15];
 case 'z'
  z_range                   = [2 3];
end % switch(type)

% Location of DICOM (modified dose)
location                    = ''; % Specify location of CT data
switch(type)
 case 'mAs'
  if numel(mAs_range) > 1
  dataDir                   = [location, '/pbda_mAs'];
  else
  dataDir                	= [location, sprintf('/%g_mAs', mAs_range)];
  end
 case 'z'
  if numel(z_range) > 1
  dataDir                   = [location, '/pbda_z'];
  else
  dataDir                	= [location, sprintf('/%g_z', z_range)];
  end
end % switch(type)
d1                        = dir(dataDir);
d_temp                   	= dir([dataDir, '/.*']);
d1(ismember({d1.name},{d_temp.name}))...
                          = [];

% Location of LIDC-IDRI datasets
dataDir2                  = [location, '/orig_mAs'];

nPatients                 = numel(d1);
parfor i=1:nPatients % Patients
 d2                       = dir([dataDir, '/', d1(i).name]);
 d_temp                  	= dir([dataDir, '/', d1(i).name, '/.*']);
 d2(ismember({d2.name},{d_temp.name}))...
                          = [];
 nModalities              = numel(d2);
 for j=1:nModalities % Modality
  d3                      = dir([dataDir,...
                                 '/', d1(i).name,...
                                 '/', d2(j).name]);
  d_temp                	= dir([dataDir,...
                                 '/', d1(i).name,...
                                 '/', d2(j).name, '/.*']);
  d3(ismember({d3.name},{d_temp.name}))...
                          = [];
  nSeries                 = numel(d3);
  for k=1:nSeries % Series
   d4                     = dir([dataDir2,...
                                 '/', d1(i).name,...
                                 '/', d2(j).name,...
                                 '/', d3(k).name,...
                                 '/*.xml']);

   % Copy one of the XML files
   copyfile([dataDir2,...
             '/', d1(i).name,...
             '/', d2(j).name,...
             '/', d3(k).name,...
             '/', d4(1).name],...
            [dataDir,...
             '/', d1(i).name,...
             '/', d2(j).name,...
             '/', d3(k).name,...
             '/', d4(1).name])
  end % for k=1:nSeries % Series
 end % for j=1:nModalities % Modality
end % parfor i=1:nPatients % Patients
%%
% Parallel computing tidying up
if (plComputing)
 delete(gcp('nocreate'))
 clear pl pl2
end % if (plComputing)
%%
