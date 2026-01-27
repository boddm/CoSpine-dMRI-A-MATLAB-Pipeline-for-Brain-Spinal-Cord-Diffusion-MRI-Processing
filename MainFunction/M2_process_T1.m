% Function: Process T1-weighted images, including segmentation of brain and spinal cord regions
% Input: 
%   Path to data directory, path to ANTs tools
% Output: 
%   Segmented T1 image files (brain region, spinal cord region, and corresponding masks)
% Example: 
%   M2_process_T1; % Execute T1 image processing
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/Users/boddm/Desktop/杂事/北京IBS/IBS合并_预处理';
antsDir = '/Users/boddm/ants/bin';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(antsDir, 'dir') == 7, 'ANTS tools directory does not exist: %s', antsDir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting T1 image processing, found %d subjects\n\n', numSubjects);

%% Loop through all subjects and volumes
for subjIdx = 1:numSubjects
    subjectPath = subjectPaths(subjIdx);
    volumePaths = systemdir(fullfile(subjectPath.folder, subjectPath.name));
    numVolumes = length(volumePaths);
    
    fprintf('[%d/%d] Processing subject: %s (%d volumes)\n', subjIdx, numSubjects, subjectPath.name, numVolumes);
    
    %% Process each volume
    for volIdx = 1:numVolumes
        volumePath = volumePaths(volIdx);
        
        fprintf('  Processing volume %d: %s\n', volIdx, volumePath.name);
        
        %% Check ANAT directory
        anatDir = fullfile(volumePath.folder, volumePath.name, 'ANAT');
        if ~isfolder(anatDir)
            fprintf('  Warning: ANAT directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Check T1 files
        t1Files = systemdir(fullfile(anatDir, '*T1.nii.gz'));
        if isempty(t1Files)
            fprintf('    Warning: No T1 files found in %s\n', anatDir);
            continue;
        end
        
        t1Image = fullfile(anatDir, t1Files(1).name);
        
        %% Execute T1 image preprocessing
        fprintf('    Processing T1 image: %s\n', t1Files(1).name);

        t1Preprocess(t1Image, anatDir, antsDir);
    end
end

fprintf('\nT1 image processing completed\n');