% function to get EGI mff data and export to EEGLAB .set % .fdt

function mff_convert_to_EEGLAB(fileName)

% if the filename is not specified open a user dialog
if nargin < 1
    fileName = uigetdir('*.mff');
end

mffData = mff_import_meta_data(fileName);

% EEG structure
% `````````````
% initialise EEG structure
EEG = eeg_emptyset;

% get meta info
EEG.comments        = [ 'Original file: ' fileName ];
EEG.setname 		= 'mff file';

EEG.nbchan          = mffData.signal_binaries.num_channels;
EEG.srate           = mffData.signal_binaries.channels.sampling_rate(1);
EEG.trials          = length(mffData.epochs);
EEG.pnts            = mffData.signal_binaries.channels.num_samples(1);
EEG.xmin            = 0; 

tmp                 = mff_convert_to_chanlocs(fileName);
EEG.chanlocs        = tmp.chanlocs;
EEG.chanlocs(258:end)=[];

% get data from bin to fdt
% ````````````````````````

dataName = 'test.fdt';
% link the struct to the data file
EEG.data = dataName;

% open a file in append mode
fid = fopen(dataName, 'a+');

% open a progress bar
waitHandle = waitbar(0,'Please wait...', 'Name', 'Importing Channels');

% loop for each block individually and append to binary file
nBlocks = mffData.signal_binaries.num_blocks;
for nBlock = 1:nBlocks;
    waitbar(nBlock/nBlocks, waitHandle,sprintf('Channel %d of %d', nBlock, nBlocks))
    
    % loop each channel to avoid memory problems (ie. double tmpData)
    tmpData = zeros(EEG.nbchan, mffData.signal_binaries.blocks.num_samples(nBlock));
    for nCh = 1:EEG.nbchan
        chData = mff_import_signal_binary(mffData.signal_binaries, nCh, nBlock);
        tmpData(nCh,:) = single(chData.samples);
    end
    
    % write the block of data to the fdt file
    fwrite(fid, tmpData, 'single', 'l');
    
end
% delete the progress bar
delete(waitHandle);

% close the file
fclose(fid);

% check the eeg for consistency
EEG = eeg_checkset(EEG);

% save the dataset
EEG = pop_saveset(EEG, 'test.set');
