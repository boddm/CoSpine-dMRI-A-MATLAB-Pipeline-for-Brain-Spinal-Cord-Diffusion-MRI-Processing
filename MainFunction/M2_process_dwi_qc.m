% Purpose: Quality control for DWI data, evaluate preprocessing results using eddy_quad
% Input: 
%   Path to data directory, path to MRtrix3 tools
% Output: 
%   Quality control result files
% Example: 
%   M2_process_dwi_qc; % Run DWI quality control assessment
% History: 
%   2025-07-01, boddm, Initial version

clc; clear;

%% Initialize parameters
dataDir = '/Users/boddm/Desktop/杂事/北京IBS/IBS合并_预处理';
mrtrix3Dir = '/home/xd/anaconda3/bin';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(mrtrix3Dir, 'dir') == 7, 'MRtrix3 tools directory does not exist: %s', mrtrix3Dir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting DWI quality control, found %d subjects\n\n', numSubjects);

%% Loop through all subjects
for subjIdx = 1:numSubjects
    subjectPath = subjectPaths(subjIdx);
    volumePaths = systemdir(fullfile(subjectPath.folder, subjectPath.name));
    numVolumes = length(volumePaths);

    fprintf('[%d/%d] Processing subject: %s (%d volumes)\n', subjIdx, numSubjects, subjectPath.name, numVolumes);
    
    %% Process each volume
    for volIdx = 1:numVolumes
        volumePath = volumePaths(volIdx);
        
        fprintf('  [%d/%d] Processing volume: %s\n', volIdx, numVolumes, volumePath.name);  
        
        %% Check DWI directories
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        dwiPreprocDir = fullfile(dwiDir, 'dwifslpreproc');
        dwiTckDir = fullfile(dwiDir, 'tractography');

        if ~isfolder(dwiTckDir) || ~isfolder(dwiPreprocDir)
            fprintf('  Warning: DWI tractography or preprocessing directory missing, skipping volume %d\n', volIdx);
            continue;
        end

        %% Locate DWI mask file
        dwiMask = fullfile(dwiTckDir, [volumePath.name, '_mask.nii.gz']);
        if ~isfile(dwiMask)
            fprintf('  Warning: DWI mask file not found, skipping volume %d\n', volIdx);
            continue;
        end

        %% Run DWI quality control assessment
        fprintf('    Starting eddy_quad quality control assessment...\n');

        originalDir = pwd;
        cd(dwiPreprocDir);

        cmdline = sprintf('$FSLDIR/bin/eddy_quad dwi_post_eddy -idx eddy_indices.txt -par eddy_config.txt -m %s -b bvals', dwiMask);
        executeCmd(cmdline, 'DWI quality control');

        fprintf('    Quality control assessment finished\n');

        cd(originalDir);
    end
end

fprintf('\nDWI quality control processing complete\n');