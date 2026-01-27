% Purpose: Register T1 images to standard space (brain to MNI152, spinal cord to PAM50)
% Input: 
%   data directory path, SCT tools path, standard template path
% Output: 
%   registered T1 images and deformation field files
% Example: 
%   M4_1_t12standard; % perform T1 registration to standard template
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/Volumes/BODDM3/IBS-北京/nii/IBS合并_预处理';
sctDir = '/Users/boddm/sct_7.0/bin';
templateRef = '${FSLDIR}/data/standard/MNI152_T1_2mm_brain';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(sctDir, 'dir') == 7, 'SCT tools directory does not exist: %s', sctDir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting T1 registration to standard template, found %d subjects\n\n', numSubjects);

%% Loop over all subjects and volumes
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
        
        %% Step 1: Process brain T1 image registration
        t1BrainDir = fullfile(anatDir, 'brain');
        if isfolder(t1BrainDir)
            t1BrainFiles = systemdir(fullfile(t1BrainDir, '*T1_brain.nii*'));
            t1BrainMaskedFiles = systemdir(fullfile(t1BrainDir, '*T1_brain_brain.nii*'));
            
            if ~isempty(t1BrainFiles) && ~isempty(t1BrainMaskedFiles)
                t1BrainMasked = fullfile(t1BrainDir, t1BrainMaskedFiles(1).name);
            
                fprintf('      Processing brain T1 image registration to MNI152 standard template\n');
                t1Brain2standard(t1BrainMasked, templateRef, t1BrainDir);
            else
                fprintf('      Warning: brain T1 files incomplete, skipping registration\n');
            end
        end
        
        %% Step 2: Process spinal cord T1 image registration
        t1SpinalDir = fullfile(anatDir, 'spinal');
        if isfolder(t1SpinalDir)
            t1SpinalDiscFiles = systemdir(fullfile(t1SpinalDir, '*disc.nii*'));
            t1SpinalFiles = systemdir(fullfile(t1SpinalDir, '*_spinal.nii*'));
            t1SpinalSegFiles = systemdir(fullfile(t1SpinalDir, '*_spinal_seg.nii*'));

            if ~isempty(t1SpinalFiles) && ~isempty(t1SpinalSegFiles)
                t1Spinal = fullfile(t1SpinalDir, t1SpinalFiles(1).name);
                t1SpinalSeg = fullfile(t1SpinalDir, t1SpinalSegFiles(1).name);
                
                if ~isempty(t1SpinalDiscFiles)
                    t1SpinalDisc = fullfile(t1SpinalDir, t1SpinalDiscFiles(1).name);
                end
                
                fprintf('      Processing spinal cord T1 image registration to PAM50 template\n');
                t1Spinal2Template(t1Spinal, t1SpinalSeg, t1SpinalDisc, t1SpinalDir, sctDir);
            else
                fprintf('      Warning: spinal cord T1 files incomplete, skipping registration\n');
            end
        end
    end
end

fprintf('\nT1 registration to standard template processing completed\n');