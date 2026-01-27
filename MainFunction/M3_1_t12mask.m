% Function: Generate brain and spinal cord segmentation masks from T1 images
% Input: 
%   data directory path, SCT tool path, DeepBet tool path
% Output: 
%   Brain and spinal cord mask files for T1 images
% Example: 
%   M3_1_t12mask; % Execute T1 mask generation
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/Volumes/BODDM3/IBS-北京/nii/IBS合并_预处理';
sctDir = '/Users/boddm/sct_7.0/bin';
deepbetDir = '/Users/boddm/anaconda3/bin';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(sctDir, 'dir') == 7, 'SCT tool directory does not exist: %s', sctDir);
assert(exist(deepbetDir, 'dir') == 7, 'DeepBet tool directory does not exist: %s', deepbetDir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting T1 mask generation, found %d subjects\n', numSubjects);

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

        %% Step 1: Read brainstem value parameter
        bs = readBSValue(anatDir);

        %% Step 2: Create brain output directory
        t1BrainDir = fullfile(anatDir, 'brain');
        if ~isfolder(t1BrainDir)
            mkdir(t1BrainDir);
        end
        
        %% Step 3: Extract brain data
        [~, t1Name, ~] = getFileExtension(t1Image);
        t1Brain = fullfile(t1BrainDir, [t1Name '_brain.nii.gz']);
        
        cmdline = sprintf('$FSLDIR/bin/fslroi %s %s 0 -1 0 -1 %d -1', t1Image, t1Brain, bs);
        executeCmd(cmdline, 'Extract brain volume');
        
        %% Step 4: Brain segmentation and mask generation
        t1BrainMasked = fullfile(t1BrainDir, [t1Name '_brain_brain.nii.gz']);
        t1BrainMask = fullfile(t1BrainDir, [t1Name '_brain_mask.nii.gz']);

        cmdline = sprintf('deepbet-cli -i %s -o %s -m %s -g', t1Brain, t1BrainMasked, t1BrainMask);
        executeCmd(fullfile(deepbetDir, cmdline), 'Brain segmentation and mask');
        
        %% Step 5: Create spinal cord output directory
        t1SpinalDir = fullfile(anatDir, 'spinal');
        if ~isfolder(t1SpinalDir)
            mkdir(t1SpinalDir);
        end
        
        %% Step 6: Extract spinal cord data
        t1Spinal = fullfile(t1SpinalDir, [t1Name '_spinal.nii.gz']);

        cmdline = sprintf('$FSLDIR/bin/fslroi %s %s 0 -1 0 -1 0 %d', t1Image, t1Spinal, bs);
        executeCmd(cmdline, 'Extract spinal cord volume');
        
        %% Step 7: Spinal cord segmentation
        t1SpinalSeg = fullfile(t1SpinalDir, [t1Name '_spinal_seg.nii.gz']);
        
        cmdline = sprintf('sct_deepseg spinalcord -i %s -o %s -c t1', t1Spinal, t1SpinalSeg);
        executeCmd(fullfile(sctDir, cmdline), 'Spinal cord segmentation');
    end
end

fprintf('\nT1 mask generation processing completed\n');