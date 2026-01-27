% Function: Generate tractography seed points for brain and spinal regions
% Input: 
%   data directory path, standard template path, SCT tools path, seed template directory
% Output: 
%   Seed point files required for tractography
% Example: 
%   M6_1_Tract_seed_edit; % Execute seed point generation
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = 'example';
templateRef = '${FSLDIR}/data/standard/MNI152_T1_2mm_brain';
sctDir = '/Users/boddm/sct_7.0/bin';
templateSeedDir = '/Users/boddm/Desktop/杂事/北京IBS/script/ROI/AAL/ROI';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(sctDir, 'dir') == 7, 'SCT tools directory does not exist: %s', sctDir);
assert(exist(templateSeedDir, 'dir') == 7, 'Seed directory does not exist: %s', templateSeedDir);

%% Acquire subject list and template seed list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting tractography seed point processing, found %d subjects\n\n', numSubjects);

templateBrainSeeds = systemdir(templateSeedDir);
numTemplateSeeds = length(templateBrainSeeds);

%% Loop through all subjects and volumes
for subjIdx = 1:numSubjects
    subjectPath = subjectPaths(subjIdx);
    volumePaths = systemdir(fullfile(subjectPath.folder, subjectPath.name));
    numVolumes = length(volumePaths);
    
    fprintf('[%d/%d] Processing subject: %s (%d volumes)\n', subjIdx, numSubjects, subjectPath.name, numVolumes);
    
    %% Process each volume
    for volIdx = 1:numVolumes
        volumePath = volumePaths(volIdx);
        
        fprintf('  [%d/%d] Processing volume: %s\n', volIdx, numVolumes, volumePath.name);
        
        %% Check directories
        anatDir = fullfile(volumePath.folder, volumePath.name, 'ANAT');
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        dwiTckDir = fullfile(dwiDir, 'tractography');
        
        if ~isfolder(anatDir) || ~isfolder(dwiDir)
            fprintf('  Warning: ANAT or DWI directory does not exist, skipping volume %d\n', volIdx);
            continue;
        elseif ~isfolder(dwiTckDir)
            mkdir(dwiTckDir);
        end
        
        %% Step 1: Merge brain and spinal cord masks
        fprintf('    Step 1: Merge brain and spinal cord masks\n');
        
        dwiMask = fullfile(dwiTckDir, [volumePath.name, '_mask.nii.gz']);
        dwiSpinalSegFiles = systemdir(fullfile(dwiDir, 'spinal', '*_spinal_dwi_mean_seg.nii.gz'));
        dwiBrainMaskFiles = systemdir(fullfile(dwiDir, 'brain', '*_brain_brain_mask.nii.gz'));
        
        if ~isempty(dwiSpinalSegFiles) && ~isempty(dwiBrainMaskFiles)
            dwiSpinalSeg = fullfile(dwiDir, 'spinal', dwiSpinalSegFiles(1).name);
            dwiBrainMask = fullfile(dwiDir, 'brain', dwiBrainMaskFiles(1).name);
            
            cmdline = sprintf('${FSLDIR}/bin/fslmerge -z %s %s %s', ...
                dwiMask, dwiSpinalSeg, dwiBrainMask);
            executeCmd(cmdline, 'Merge brain and spinal cord masks');
        else
            fprintf('    Warning: Brain or spinal cord mask file does not exist, skipping mask merge\n');
            continue;
        end

        warpStd2Diff = fullfile(dwiDir, 'brain', 'warp_standard2diff.nii.gz');
       
        %% Step 2: Process brain seed points
        fprintf('    Step 2: Process brain seed points (%d seeds)\n', numTemplateSeeds);
        
        if isfile(dwiBrainMask) && isfile(warpStd2Diff)
            for seedIdx = 1:numTemplateSeeds
                templateBrainSeed = fullfile(templateBrainSeeds(seedIdx).folder, templateBrainSeeds(seedIdx).name);
                
                dwiBrainSeed = fullfile(dwiTckDir, ['Seed_brain_', num2str(seedIdx), '.nii.gz']);
                dwiBrainSeedBin = fullfile(dwiTckDir, ['Seed_brain_', num2str(seedIdx), '_thr_bin.nii.gz']);
                
                cmdline1 = sprintf('${FSLDIR}/bin/applywarp -i %s -r %s -o %s -w %s', ...
                    templateBrainSeed, dwiBrainMask, dwiBrainSeed, warpStd2Diff);
                executeCmd(cmdline1, sprintf('Apply warp to convert standard space seed point %d to DWI space', seedIdx));
                
                cmdline2 = sprintf('${FSLDIR}/bin/fslmaths %s -thr 0.2 -bin %s', ...
                    dwiBrainSeed, dwiBrainSeedBin);
                executeCmd(cmdline2, sprintf('Threshold and binarize seed point %d', seedIdx));
            end
        else
            fprintf('    Warning: DWI brain mask or warp field does not exist, skipping brain seed processing\n');
        end
        
        %% Step 3: Process spinal cord seed points
        fprintf('    Step 3: Process spinal cord seed points\n');
        
        dwiSpinalMocoFiles = systemdir(fullfile(dwiDir, 'spinal', '*moco_dwi_mean.*'));
        warpT12Dmri = fullfile(dwiDir, 'spinal', 'warp_T12dmri.nii.gz');

        if ~isempty(dwiSpinalMocoFiles) && isfile(warpT12Dmri)
            dwiSpinalMoco = fullfile(dwiDir, 'spinal', dwiSpinalMocoFiles(1).name);
            pam50LevelsFile = fullfile(anatDir, 'spinal', 'label/template/PAM50_levels.nii.gz');
            
            if isfile(pam50LevelsFile)
                dwiSpinalSeed = fullfile(dwiTckDir, 'Seed_spinal.nii.gz');
                
                cmdline = sprintf('sct_apply_transfo -i %s -d %s -w %s -x nn -o %s', ...
                    pam50LevelsFile, dwiSpinalMoco, warpT12Dmri, dwiSpinalSeed);
                executeCmd(fullfile(sctDir, cmdline), 'Transform PAM50 spinal level template to DWI space');
                
                if isfile(dwiSpinalSeed)
                    fprintf('    Generating C6 and C1 spinal level seed ROIs\n');
                    [dwiSeedSpinalC6, ~, ~] = generateSpinalSeed(dwiSpinalSeed, 6, dwiDir, dwiTckDir, volumePath.name, 'C6');
                    [dwiSeedSpinalC1, ~, ~] = generateSpinalSeed(dwiSpinalSeed, 1, dwiDir, dwiTckDir, volumePath.name, 'C1');
                end
            else
                fprintf('    Warning: PAM50 spinal level template file does not exist, skipping spinal seed transformation\n');
            end
        else
            fprintf('    Warning: DWI spinal cord file or warp field does not exist, skipping spinal seed processing\n');
        end
    end
end

fprintf('\n纤维束追踪种子点处理完成\n');