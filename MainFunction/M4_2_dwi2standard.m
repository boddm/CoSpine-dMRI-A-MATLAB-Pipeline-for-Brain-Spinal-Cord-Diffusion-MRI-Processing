% Function: Register DWI images to standard space (brain to MNI152, spinal cord to PAM50)
% Input: 
%   data directory path, standard template path, SCT tools path
% Output: 
%   registered DWI images and deformation field files
% Example: 
%   M4_2_dwi2standard; % Execute DWI registration to standard space
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/Volumes/BODDM3/IBS-北京/nii/IBS合并_预处理';
template = '${FSLDIR}/data/standard/MNI152_T1_2mm_brain';
sctDir = '/Users/boddm/sct_7.0/bin';
templateSpinal = '/Users/boddm/sct_7.0/data/PAM50/template/PAM50_t1.nii.gz';
templateSpinalSeg = '/Users/boddm/sct_7.0/data/PAM50/template/PAM50_cord.nii.gz';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(sctDir, 'dir') == 7, 'SCT tools directory does not exist: %s', sctDir);
assert(exist(templateSpinal, 'file') == 2, 'Spinal cord template file does not exist: %s', templateSpinal);
assert(exist(templateSpinalSeg, 'file') == 2, 'Spinal cord template segmentation file does not exist: %s', templateSpinalSeg);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting DWI registration to standard space, found %d subjects\n\n', numSubjects);

%% Loop over all subjects and volumes
for subjIdx = 1%:numSubjects
    subjectPath = subjectPaths(subjIdx);
    volumePaths = systemdir(fullfile(subjectPath.folder, subjectPath.name));
    numVolumes = length(volumePaths);

    fprintf('[%d/%d] Processing subject: %s (%d volumes)\n', subjIdx, numSubjects, subjectPath.name, numVolumes);

    %% Process each volume
    for volIdx = 1:numVolumes
        volumePath = volumePaths(volIdx);
 
        fprintf('  Processing volume %d: %s\n', volIdx, volumePath.name);

        %% Check DWI/anat directories
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        anatDir = fullfile(volumePath.folder, volumePath.name, 'ANAT');
        if ~isfolder(dwiDir) || ~isfolder(anatDir)
            fprintf('  Warning: DWI or ANAT directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end

        %% Step 1: Process brain DWI registration
        dwiBrainDir = fullfile(dwiDir, 'brain');
        t1BrainDir = fullfile(anatDir, 'brain');
        
        if isfolder(dwiBrainDir) && isfolder(t1BrainDir)
            t1BrainMaskedFiles = systemdir(fullfile(t1BrainDir, '*_brain_brain.nii*'));  % Find T1 brain masked files
            dwiBrainMaskedFiles = systemdir(fullfile(dwiBrainDir, '*_brain_brain.nii*'));  % Find DWI brain masked files
            dwiBrainMaskFiles = systemdir(fullfile(dwiBrainDir, '*_brain_mask.nii*'));  % Find DWI brain mask files
            
            if ~isempty(dwiBrainMaskedFiles) && ~isempty(t1BrainMaskedFiles) && ~isempty(dwiBrainMaskFiles)
                t1BrainMasked = fullfile(t1BrainDir, t1BrainMaskedFiles(1).name);
                dwiBrainMasked = fullfile(dwiBrainDir, dwiBrainMaskedFiles(1).name);
                dwiBrainMask = fullfile(dwiBrainDir, dwiBrainMaskFiles(1).name);

                %% Step 1a: Process brain DWI to standard space registration
                fprintf('        Step 1a: Processing brain DWI to standard space registration\n');
                dwiBrain2standard(dwiBrainMasked, dwiBrainMask, t1BrainMasked, dwiBrainDir, t1BrainDir, template);
            else
                fprintf('      Warning: Brain processing files incomplete, skipping brain registration\n');
                continue;
            end
        else
            fprintf('      Warning: Brain processing files incomplete, skipping brain registration\n');
            continue;
        end

        %% Step 2: Process spinal cord DWI registration
        dwiSpinalDir = fullfile(dwiDir, 'spinal');
        t1SpinalDir = fullfile(anatDir, 'spinal');

        if isfolder(dwiSpinalDir) && isfolder(t1SpinalDir)
            dwiSpinalMocoFiles = systemdir(fullfile(dwiSpinalDir, '*moco_dwi_mean.nii*'));  % Find DWI spinal cord motion-corrected files
            dwiSpinalSegFiles = systemdir(fullfile(dwiSpinalDir, '*dwi_mean_seg.nii*'));  % Find DWI spinal cord segmentation files
            t1SpinalFiles = systemdir(fullfile(t1SpinalDir, '*_T1_spinal.nii*'));  % Find T1 spinal cord files
            t1SpinalSegFiles = systemdir(fullfile(t1SpinalDir, '*_spinal_seg.nii*'));  % Find T1 spinal cord segmentation files

            if ~isempty(dwiSpinalMocoFiles) && ~isempty(dwiSpinalSegFiles) && ~isempty(t1SpinalFiles) && ~isempty(t1SpinalSegFiles)
                dwiSpinalMoco = fullfile(dwiSpinalMocoFiles.folder, dwiSpinalMocoFiles.name);  % Path to motion-corrected DWI spinal cord image
                dwiSpinalSeg = fullfile(dwiSpinalSegFiles.folder, dwiSpinalSegFiles.name);  % Path to DWI spinal cord segmentation image
                t1Spinal = fullfile(t1SpinalFiles.folder, t1SpinalFiles.name);  % Path to T1 spinal cord image
                t1SpinalSeg = fullfile(t1SpinalSegFiles.folder, t1SpinalSegFiles.name);  % Path to T1 spinal cord segmentation image

                %% Step 2a: Process spinal cord DWI registration
                fprintf('        Step 2a: Processing spinal cord DWI registration\n');
                [warpDmri2T1, warpT12Dmri] = dwiSpinal2t1(t1Spinal, t1SpinalSeg, dwiSpinalMoco, dwiSpinalSeg, dwiSpinalDir, sctDir);

                %% Step 2b: Apply transformation to register DWI spinal cord to standard spinal cord template
                fprintf('        Step 2b: Applying transformation from DWI spinal cord to standard spinal cord template\n');

                warpAnat2Template = fullfile(t1SpinalDir, 'warp_anat2template.nii.gz');

                [~, baseName, ext] = getFileExtension(dwiSpinalMoco);  % Get filename and extension
                outputReg2 = fullfile(dwiSpinalDir, [baseName, '_reg2.', ext]);

                cmdline = sprintf('sct_apply_transfo -i %s -d %s -w %s %s -o %s', dwiSpinalMoco, templateSpinal, warpDmri2T1, warpAnat2Template, outputReg2);
                executeCmd(fullfile(sctDir, cmdline), 'Applying transformation: register DWI spinal cord to standard spinal cord template');

                %% Step 2c: Apply transformation to register DWI spinal cord segmentation to standard spinal cord template
                fprintf('        Step 2c: Applying transformation from DWI spinal cord segmentation to standard spinal cord template\n');

                [~, baseNameSeg, extSeg] = getFileExtension(dwiSpinalSeg);
                outputSegReg2 = fullfile(dwiSpinalDir, [baseNameSeg, '_reg2.', extSeg]);

                cmdline = sprintf('sct_apply_transfo -i %s -d %s -w %s %s -x linear -o %s', dwiSpinalSeg, templateSpinal, warpDmri2T1, warpAnat2Template, outputSegReg2);
                executeCmd(fullfile(sctDir, cmdline), 'Applying transformation: register DWI spinal cord segmentation to standard spinal cord template');

            else
                fprintf('      Warning: Spinal cord processing files incomplete, skipping spinal cord registration\n');
                continue;
            end
        else
            fprintf('      Warning: Spinal cord processing files incomplete, skipping spinal cord registration\n');
            continue;
        end
    end
end

fprintf('\nDWI registration to standard space completed\n');