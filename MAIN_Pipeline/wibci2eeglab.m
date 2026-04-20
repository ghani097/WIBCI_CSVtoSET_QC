function EEG = wibci2eeglab(filePath, fillMissingPackets)
%WiBCI2EEGLAB Takes a WiBCI file and returns data in EEGLAB format.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%I HAVE updated
% this (USMAN.G)
% Input arguments:
% filePath is the full path of the WiBCI data file.
% fillMissing: 0 = Missing packets are included in the data as NaNs. 1 =
% Missing packets are filled using Matlab's fillmissing function with pchip
% method. Default is 1.
%
% Output:
% EEG is the EEGLAB structure

if nargin < 2
    fillMissingPackets = 1;
end

%% Dataset parameters
setname                         = 'WiBCI Data';
[~, filename]                   = fileparts(filePath);

%% Load the file
loadedData                      = loadWiBCIData_UG(filePath, fillMissingPackets);
eegData                         = loadedData.channelData(:, [4 6 7 8 10 11 12 14 15 16]);
accelData                       = loadedData.channelData(:, 20:22);
eventData                       = loadedData.channelData(:, 23:24);
sampleRate                      = 250;
timeVect                        = (1:length(eegData))./ sampleRate;
eegChannels                     = loadedData.channelNames([4 6 7 8 10 11 12 14 15 16]);

%% Get channel location file
electrodeSetupAscFile           = fullfile(fileparts(which('eeglab')), 'functions', 'supportfiles', 'Standard-10-5-Cap385.sfp');
locFile                         = readlocs(electrodeSetupAscFile);

%% Prepare event vector — rising-edge detection for trigger onsets
softEventAVector                = find(diff([0; eventData(:, 1) >= 100]) == 1);
softEventBVector                = find(diff([0; eventData(:, 2) >= 100]) == 1);

hardEventAVector                = find(diff([0; (eventData(:, 1) >= 1) & (eventData(:, 1) < 100)]) == 1);
hardEventBVector                = find(diff([0; (eventData(:, 2) >= 1) & (eventData(:, 2) < 100)]) == 1);

%% Extract numeric code values at each event onset sample
softEventACodes                 = eventData(softEventAVector, 1);
softEventBCodes                 = eventData(softEventBVector, 2);
hardEventACodes                 = eventData(hardEventAVector, 1);
hardEventBCodes                 = eventData(hardEventBVector, 2);

%% Ignore Non-eeglab channles
includedChannels = strcmpIND(eegChannels, transpose({locFile(:).labels}));
ignoredChannels = setdiff(1:size(eegData, 2), includedChannels);
ignoredChannelNames = eegChannels(ignoredChannels);

warning('Ignoring following non-eeglab channels: %s', strjoin(ignoredChannelNames, ', '));

eegData = eegData(:, includedChannels);
eegChannels = eegChannels(includedChannels);

%% Prepare channel locs
chanLocs = locFile(strcmpIND(transpose({locFile(:).labels}), eegChannels));
urChanLocs = locFile(strcmpIND(transpose({locFile(:).labels}), eegChannels));

%% Prepared EEG struct
EEG.setname                     = setname;
EEG.filename                    = filename;
EEG.filepath                    = filePath;
EEG.subject                     = 101;
EEG.group                       = '';
EEG.condition                   = '';
EEG.session                     = 101;
EEG.comments                    = '';
EEG.nbchan                      = size(eegData, 2);
EEG.trials                      = 1;
EEG.pnts                        = size(eegData, 1);
EEG.srate                       = sampleRate;
EEG.xmin                        = 1 / EEG.srate;
EEG.xmax                        = EEG.pnts / EEG.srate;
EEG.times                       = timeVect;
EEG.data                        = permute(eegData, [2 1]);
EEG.icaact                      = [];
EEG.icawinv                     = [];
EEG.icasphere                   = [];
EEG.icaweights                  = [];
EEG.icachansind                 = [];
EEG.chanlocs                    = chanLocs;
EEG.urchanlocs                  = urChanLocs;
EEG.chaninfo                    = [];
EEG.ref                         = 'common';
EEG.event                       = eegLabEventStructW(softEventAVector, softEventBVector, hardEventAVector, hardEventBVector, ...
                                                     softEventACodes, softEventBCodes, hardEventACodes, hardEventBCodes);
EEG.urevent                     = EEG.event;
EEG.eventdescription            = {};
EEG.epoch                       = [];
EEG.epochdescription            = {};
EEG.reject                      = [];
EEG.stats                       = [];
EEG.specdata                    = [];
EEG.specicaact                  = [];
EEG.splinefile                  = '';
EEG.icasplinefile               = '';
EEG.dipfit                      = [];
EEG.history                     = {'WiBCI2EEGLAB'};
EEG.saved                       = 'no';
EEG.etc                         = [];
EEG.paradigm                    = '';
end

