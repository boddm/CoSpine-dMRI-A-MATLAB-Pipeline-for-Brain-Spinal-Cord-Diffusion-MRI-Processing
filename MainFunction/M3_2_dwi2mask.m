% Purpose: Generate brain and spinal cord segmentation masks from DWI data
% Inputs: 
%   data directory path, SCT tools path, MRtrix3 tools path
% Outputs: 
%   brain and spinal cord mask files for DWI data
% Example: 
%   M3_2_dwi2mask; % Run DWI mask generation
% History: 
%   2025-07-01, boddm, Initial version
clc; clear;

%% Initialize parameters
dataDir = '/Volumes/BODDM3/IBS-北京/nii/IBS合并_预处理';
sctDir = '/Users/boddm/sct_7.0/bin';
mrtrix3Dir = '/usr/local/bin';
inputFile = 'Big_4D_preproc.nii';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(sctDir, 'dir') == 7, 'SCT tools directory does not exist: %s', sctDir);
assert(exist(mrtrix3Dir, 'dir') == 7, 'MRtrix3 tools directory does not exist: %s', mrtrix3Dir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting DWI mask generation, found %d subjects\n\n', numSubjects);

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

        %% Check DWI directory
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        
        if ~isfolder(dwiDir)
            fprintf('  Warning: DWI directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end

        %% Locate preprocessed DWI file
        dwiApPreprocFiles = systemdir(fullfile(dwiDir, 'Big_4D_preproc.mif.gz'));
        if isempty(dwiApPreprocFiles)
            fprintf('  Warning: DWI preprocessed file does not exist, skipping volume %d\n', volIdx);
            continue;
        end
        dwiApPreproc = fullfile(dwiApPreprocFiles.folder, dwiApPreprocFiles.name);
        
        %% Step 1: Read brainstem value parameter
        bs = readBSValue(dwiDir);
        if isnan(bs)
            fprintf('    Warning: Unable to read brainstem value for %s, skipping\n', dwiDir);  
            continue;
        end
        
        %% Step 2: Prepare gradient files and convert format
        bvec = fullfile(dwiDir, 'bvec');
        bval = fullfile(dwiDir, 'bval');
        dwiApPreprocNii = fullfile(dwiDir, inputFile);
        
        if ~isfile(dwiApPreprocNii)
            cmdline = sprintf('mrconvert %s %s -export_grad_fsl %s %s -force', dwiApPreproc, dwiApPreprocNii, bvec, bval);
            executeCmd(fullfile(mrtrix3Dir, cmdline), 'Convert DWI file format');
        end
        
        %% Step 3: Process brain data
        dwiBrainDir = fullfile(dwiDir, 'brain');
        if ~isfolder(dwiBrainDir)
            mkdir(dwiBrainDir);
        end
        
        dwiBrain = fullfile(dwiBrainDir, [volumePath.name, '_brain.nii.gz']);
        dwiBrainMask = fullfile(dwiBrainDir, [volumePath.name, '_brain_brain.nii.gz']);
        
        cmdline = sprintf('$FSLDIR/bin/fslroi %s %s 0 -1 0 -1 %d -1', dwiApPreprocNii, dwiBrain, bs);
        executeCmd(cmdline, 'Extract brain data');
        
        cmdline = sprintf('${FSLDIR}/bin/bet %s %s -f 0.2 -m', dwiBrain, dwiBrainMask);
        executeCmd(cmdline, 'Generate brain mask');
        
        %% Step 4: Process spinal cord data
        dwiSpinalDir = fullfile(dwiDir, 'spinal');
        dwiSpinal = fullfile(dwiSpinalDir, [volumePath.name, '_spinal.nii.gz']);
        if ~isfolder(dwiSpinalDir)
            mkdir(dwiSpinalDir);
        end
        
        cmdline = sprintf('$FSLDIR/bin/fslroi %s %s 0 -1 0 -1 0 %d', dwiApPreprocNii, dwiSpinal, bs);
        executeCmd(cmdline, 'Extract spinal cord data');
        
        [~, ~, ~, ~] = dwiSpinalPreproc(dwiSpinal, bvec, dwiSpinalDir, volumePath.name, sctDir);
        
        %% Step 5: Clean up temporary files
        if isfile(dwiApPreprocNii)
            delete(dwiApPreprocNii);
        end
    end
end

fprintf('\nDWI mask generation processing complete\n');