% Function: Process DWI data including format conversion, denoising, artifact correction and preprocessing
% Input: 
%   data directory path, MRtrix3 tools path, number of threads
% Output: 
%   preprocessed DWI data file (.mif.gz format)
% Example: 
%   M2_process_dwi; % Execute DWI data processing
% History: 
%   2025-07-01, boddm, Initial version

clc; clear;

%% Initialize parameters
dataDir = '/Volumes/BODDM3/IBS-北京/nii/IBS合并_预处理';
mrtrix3Dir = '/usr/local/bin';
numThreads = 20;

%% Validate input path
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting DWI data processing, found %d subjects\n\n', numSubjects);

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
        
        %% Check DWI directory
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        if ~isfolder(dwiDir)
            fprintf('  Warning: DWI directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end

        %% Step 1: Convert NIfTI files to MRtrix format
        niiFiles = systemdir(fullfile(dwiDir, '*nii*'));

        for fileIdx = 1:length(niiFiles)
            niiFile = niiFiles(fileIdx);
            [~, baseName, ~] = getFileExtension(niiFile.name);

            mifFile = fullfile(dwiDir, [baseName, '.mif']);
            bvecFile = fullfile(dwiDir, [baseName, '.bvec']);
            bvalFile = fullfile(dwiDir, [baseName, '.bval']);
            jsonFile = fullfile(dwiDir, [baseName, '.json']);

            fileCheck = [exist(fullfile(dwiDir, niiFile.name), 'file'), exist(bvecFile, 'file'), ...
                exist(bvalFile, 'file'), exist(jsonFile, 'file')];

            if all(fileCheck)
                cmdline = sprintf('mrconvert %s %s -fslgrad %s %s -json_import %s -force', ...
                    fullfile(dwiDir, niiFile.name), mifFile, bvecFile, bvalFile, jsonFile);
                executeCmd(fullfile(mrtrix3Dir, cmdline), 'Convert NIfTI file to MRtrix format');
            end
        end

        %% Step 2: Process AP-direction DWI data
        apFiles = systemdir(fullfile(dwiDir, '*_AP.mif'));
        if isempty(apFiles)
            fprintf('  Warning: AP-direction DWI file not found, skipping volume %d\n', volIdx);
            continue;
        end

        dwiAp = fullfile(dwiDir, apFiles(1).name);
        [~, baseName, ~] = getFileExtension(dwiAp);
        dwiApB0 = fullfile(dwiDir, [baseName, '_B0.mif']);

        cmdline = sprintf('mrconvert %s %s -coord 3 0 -axes 0,1,2,3 -force', dwiAp, dwiApB0);
        executeCmd(fullfile(mrtrix3Dir, cmdline), 'Extract AP-direction B0 image');

        %% Step 3: Merge AP and PA direction B0 images
        paFiles = systemdir(fullfile(dwiDir, '*_PA_B0*.mif'));
        if ~isempty(paFiles)
            dwiPaB0 = fullfile(dwiDir, paFiles(1).name);
            dwiApPAB0 = fullfile(dwiDir, 'Big_AP_PA.mif');

            cmdline = sprintf('mrcat %s %s %s -force', dwiApB0, dwiPaB0, dwiApPAB0);
            executeCmd(fullfile(mrtrix3Dir, cmdline), 'Merge AP and PA direction B0 images');
        end

        %% Step 4: DWI data denoising
        dwiApDenoise = fullfile(dwiDir, 'Big_4D_denoise.mif');

        cmdline = sprintf('dwidenoise %s %s -nthreads %d -force', dwiAp, dwiApDenoise, numThreads);
        executeCmd(fullfile(mrtrix3Dir, cmdline), 'DWI data denoising');

        %% Step 5: Gibbs artifact correction
        dwiApGibbs = fullfile(dwiDir, 'Big_4D_gibbs.mif');

        cmdline = sprintf('mrdegibbs %s %s -nthreads %d -force', dwiApDenoise, dwiApGibbs, numThreads);
        executeCmd(fullfile(mrtrix3Dir, cmdline), 'Gibbs artifact correction');

        %% Step 6: Run FSL preprocessing
        dwiApPreproc = fullfile(dwiDir, 'Big_4D_preproc.mif');
        dwifslprerpoc_matlab(dwiApGibbs, dwiApPAB0, dwiApPreproc, mrtrix3Dir, numThreads)

        %% Step 7: Compress processed files
        cmdline = sprintf('gzip -f %s/*.mif', dwiDir);
        executeCmd(fullfile(mrtrix3Dir, cmdline), 'Compress MIF files');

        cmdline = sprintf('gzip -f %s/*.nii', dwiDir);
        executeCmd(fullfile(mrtrix3Dir, cmdline), 'Compress NIfTI files');
    end
end

fprintf('\nDWI data processing completed\n');