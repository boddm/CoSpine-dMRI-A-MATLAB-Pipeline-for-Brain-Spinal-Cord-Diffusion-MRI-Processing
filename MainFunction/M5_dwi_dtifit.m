% Function: Fit diffusion tensor imaging (DTI) to DWI data and compute metrics FA, AD, MD, RD, etc.
% Input: 
%   Path to data directory, path to MRtrix3 tools
% Output: 
%   DTI-fitted metric files (FA, AD, MD, RD, etc.)
% Example: 
%   M5_dwi_dtifit; % Run DWI DTI fitting
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = 'example';
mrtrix3Dir = '/home/xd/anaconda3/bin';
preprocBaseName = 'Big_4D_preproc.nii';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(mrtrix3Dir, 'dir') == 7, 'MRtrix3 tools directory does not exist: %s', mrtrix3Dir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting DWI DTI fitting, found %d subjects\n\n', numSubjects);

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
        
        %% Check DWI directory
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        if ~isfolder(dwiDir)
            fprintf('  Warning: DWI directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Locate pre-processed DWI file
        dwiPreprocFiles = systemdir(fullfile(dwiDir, 'Big_4D_preproc.mif.gz'));
        if isempty(dwiPreprocFiles)
            fprintf('  Warning: Pre-processed DWI file not found, skipping volume %d\n', volIdx);
            continue;
        end
        
        dwiApPreprocMif = fullfile(dwiDir, dwiPreprocFiles(1).name);
        
        %% Step 1: Convert MRtrix3 format to NIfTI format
        dwiApPreprocNii = fullfile(dwiDir, preprocBaseName);
        bvec = fullfile(dwiDir, 'bvec');
        bval = fullfile(dwiDir, 'bval');
        
        cmdline = sprintf('mrconvert %s %s -export_grad_fsl %s %s -force', dwiApPreprocMif, dwiApPreprocNii, bvec, bval);
        executeCmd(fullfile(mrtrix3Dir, cmdline), 'Convert MRtrix3 format to NIfTI format and export gradient files');
        
        %% Step 2: Generate DWI mask
        paB0Files = systemdir(fullfile(dwiDir, '*PA_B0.mif.gz'));
        if isempty(paB0Files)
            fprintf('  Warning: PA_B0 file not found, skipping mask generation\n');
            continue;
        end
        
        dwiApB0 = fullfile(dwiDir, paB0Files(1).name);
        dwiMask = fullfile(dwiDir, [volumePath.name, '_mask.nii.gz']);

        cmdline = sprintf('mrconvert %s %s -force', dwiApB0, dwiMask);
        executeCmd(fullfile(mrtrix3Dir, cmdline), 'Convert reverse B0 image to NIfTI format');
        
        cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -add 1000 -bin %s', dwiMask, dwiMask);
        executeCmd(cmdline, 'Generate DWI binary mask');
        
        %% Step 3: Execute DTI fitting
        outputPrefix = fullfile(dwiDir, 'Big_4D_preproc');
        
        cmdline = sprintf('${FSLDIR}/bin/dtifit -k %s -o %s -m %s -r %s -b %s', dwiApPreprocNii, outputPrefix, dwiMask, bvec, bval);
        executeCmd(cmdline, 'Perform DTI fitting using FSL');
        
        %% Step 4: Rename output metrics
        l1 = fullfile(dwiDir, 'Big_4D_preproc_L1.nii.gz');
        ad = fullfile(dwiDir, 'Big_4D_preproc_AD.nii.gz');
        
        if isfile(l1)
            movefile(l1, ad);
        end
        
        l2 = fullfile(dwiDir, 'Big_4D_preproc_L2.nii.gz');
        l3 = fullfile(dwiDir, 'Big_4D_preproc_L3.nii.gz');
        rd = fullfile(dwiDir, 'Big_4D_preproc_RD.nii.gz');
        
        if isfile(l2) && isfile(l3)
            cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -add %s -div 2 %s', l2, l3, rd);
            executeCmd(cmdline, 'Compute radial diffusivity (RD)');
        end
        
        %% Step 5: Clean up temporary files
        if isfile(dwiApPreprocNii)
            delete(dwiApPreprocNii);
        end
        
        %% Step 6: Delete intermediate files        
        patterns = {'Big*_V*', 'Big*_L2.nii.gz', 'Big*_L3.nii.gz', 'Big*_S*', 'Big*_tensor*', 'Big_4D_preproc_MO*', dwiMask};
        
        for pIdx = 1:length(patterns)
            pattern = patterns{pIdx};
            files = dir(fullfile(dwiDir, pattern));
            
            for fIdx = 1:length(files)
                delete(fullfile(dwiDir, files(fIdx).name));
            end
        end
    end
end

fprintf('\nDWI DTI fitting completed\n');