%-------------------------------------------------------------------------------
% startPreprocessing: preparation and reading EDF files for one subject, 
%   preprocessing and creating saving files
%
% Syntax: preprocessedData = init_Preprocessing(patient_folder,fs_new,ElectricFreq)
%
% Inputs: 
%     patient_folder   - directory of EDF files
%     fs_new           - resampling frequency
%     ElectricFreq     - electricity frequency
%
% Outputs: 
%     preprocessedData - a cell consist of preprocessed EEG and other
%                           important information
%
% Example:
%     patient_folder='./NOGIN_1101/'; 
%
% Saeed Montazeri M., University of Helsinki
% Started: 10-11-2019
%-------------------------------------------------------------------------------
function [preprocessedData]=init_Preprocessing(patient_folder,fs_new,ElectricFreq)

if(nargin<2 || isempty(fs_new)), fs_new = []; end
if(nargin<3 || isempty(ElectricFreq)), ElectricFreq=50; end

% Create output directory if it doesn't exist
[~, patient_name] = fileparts(patient_folder);
output_dir = fullfile(patient_folder, 'preprocessed');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% find .edf files
try
    exam_names = getsortedfiles(patient_folder,'edf');
catch ME
    warning('patient_folder is not valid (should be a valid address, organized as the provided example data)')
    rethrow(ME)
end

preprocessedData = cell(1,5);
for j= 1:size(exam_names,2)
    disp(j)
    try
        % read EEG data
        [dat, hdr, labels, fs, scle, offs, duration, start] = read_edf([patient_folder exam_names{1,j}]);
    catch ME
        rethrow(ME)
    end
    
    if isempty(fs_new)
        fs_new = fs(1);
    end
    
    if ~isempty(dat) && ~isempty(labels) && ~isempty(fs) && ~isempty(scle) && ~isempty(offs) && ~isempty(start)
        fs = fs(1); %sampling frequency
        % preprocessing function
        [eeg_data, ArtifactPercPerCh, channelList] = preprocess(dat,fs,scle,offs,labels,fs_new,ElectricFreq);
        preprocessedData(j,:) = {[eeg_data],[ArtifactPercPerCh],[fs_new],[start j],[channelList]};
    else
        warning(['Error in file' exam_names{1,j}])
    end
    
end
% Save summary file
summary_filename = fullfile(output_dir, [patient_name '_preprocessing_summary.mat']);
summary = struct();
summary.preprocessedData = preprocessedData;
summary.processing_parameters = struct('fs_new', fs_new, ...
                                     'ElectricFreq', ElectricFreq, ...
                                     'processed_files', {exam_names}, ...
                                     'processing_date', datetime('now'));

save(summary_filename, '-struct', 'summary', '-v7.3');
disp(['Saved preprocessing summary to: ' summary_filename]);

% Create a text summary
txt_summary = fullfile(output_dir, [patient_name '_preprocessing_report.txt']);
fid = fopen(txt_summary, 'w');
fprintf(fid, 'Preprocessing Summary\n');
fprintf(fid, '====================\n\n');
fprintf(fid, 'Patient: %s\n', patient_name);
fprintf(fid, 'Processing Date: %s\n\n', datestr(now));
fprintf(fid, 'Parameters:\n');
fprintf(fid, '- Resampling frequency: %d Hz\n', fs_new);
fprintf(fid, '- Power line frequency: %d Hz\n\n', ElectricFreq);
fprintf(fid, 'Processed Files:\n');

for j = 1:size(exam_names,2)
    if ~isempty(preprocessedData{j,1})
        artifact_mean = mean(preprocessedData{j,2});
        fprintf(fid, '%d. %s\n   - Channels: %d\n   - Mean artifact %%: %.2f%%\n\n', ...
            j, exam_names{1,j}, size(preprocessedData{j,1},1), artifact_mean*100);
    else
        fprintf(fid, '%d. %s\n   - Processing failed\n\n', j, exam_names{1,j});
    end
end

fclose(fid);
disp(['Created preprocessing report: ' txt_summary]);

end
