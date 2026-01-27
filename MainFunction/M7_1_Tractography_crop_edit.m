% Purpose: Crop fiber tracts to retain fibers between brain and spinal-cord regions
% Inputs: 
%   data directory path, MRtrix3 tools path, minimum fiber length
% Output: 
%   cropped fiber-tract file (.tck format)
% Example: 
%   M7_1_Tractography_crop_edit; % run tract cropping
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = 'example';
mrtrix3Dir = '/usr/local/bin';
minFiberLength = 100;
tckPattern = '*tha2C6*.tck';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory not found: %s', dataDir);
assert(exist(mrtrix3Dir, 'dir') == 7, 'MRtrix3 tools directory not found: %s', mrtrix3Dir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting tract cropping; found %d subjects\n\n', numSubjects);

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
        
        %% Set directory paths
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        dwiTckDir = fullfile(dwiDir, 'tractography');
        
        if ~isfolder(dwiDir) || ~isfolder(dwiTckDir)
            fprintf('  Warning: DWI or tractography directory missing, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Read brain-stem value parameter
        bs = readBSValue(dwiDir);
        if isnan(bs)
            fprintf('  Warning: Unable to read bs value from DWI data, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Locate DWI mask file
        dwiMask = fullfile(dwiTckDir, [volumePath.name, '_mask.nii.gz']);
        if ~isfile(dwiMask)
            fprintf('  Warning: DWI mask file not found, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Locate seed-point files
        dwiBrainSeeds = systemdir(fullfile(dwiTckDir, '*brain*_bin*'));
        numBrainSeeds = length(dwiBrainSeeds);
        
        if numBrainSeeds == 0
            fprintf('  Warning: No brain seed-point files found, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Locate tract files
        dwiTcks = systemdir(fullfile(dwiTckDir, tckPattern));
        numTcks = length(dwiTcks);
        
        if numTcks == 0
            fprintf('  Warning: No tract files found, skipping volume %d\n', volIdx);
            continue;
        end
        
        fprintf('    Found %d tract files; starting cropping\n', numTcks);
        
        %% Crop each tract file
        for tckIdx = 1:numTcks
            if tckIdx > numBrainSeeds
                fprintf('    Warning: tract index exceeds seed count, skipping\n');
                continue;
            end
            
            dwiTckFile = dwiTcks(tckIdx);
            dwiBrainSeed = dwiBrainSeeds(tckIdx);

            dwiBrainSeedPath = fullfile(dwiBrainSeed.folder, dwiBrainSeed.name);
            dwiSpinalSeed = fullfile(dwiTckDir, sprintf('Seed_spinal_C6_thr%d.nii.gz', tckIdx));
            
            if ~isfile(dwiBrainSeedPath) || ~isfile(dwiSpinalSeed)
                fprintf('    Warning: seed-point files missing, skipping tract %d\n', tckIdx);
                continue;
            end
            
            %% Step 1: Get brain-seed bounding box
            fprintf('    Step 1: Get brain-seed bounding box\n');
            
            cmdline = sprintf('${FSLDIR}/bin/fslstats %s -w', dwiBrainSeedPath);
            [~, cmdout] = executeCmd(cmdline, 'Get brain-seed bounding box');
            brainSize = str2double(strsplit(cmdout));
            
            if length(brainSize) < 6
                fprintf('    Warning: incomplete brain-seed bounding box, skipping tract %d\n', tckIdx);
                continue;
            end
            
            brainSize(5) = brainSize(5) + bs;
            
            %% Step 2: Get spinal-seed bounding box
            fprintf('    Step 2: Get spinal-seed bounding box\n');
            
            cmdline = sprintf('${FSLDIR}/bin/fslstats %s -w', dwiSpinalSeed);
            [~, cmdout] = executeCmd(cmdline, 'Get spinal-seed bounding box');
            spinalSize = str2double(strsplit(cmdout));
            
            if length(spinalSize) < 6
                fprintf('    Warning: incomplete spinal-seed bounding box, skipping tract %d\n', tckIdx);
                continue;
            end
            
            %% Step 3: Compute spinal-mask range
            fprintf('    Step 3: Compute spinal-mask range\n');
            
            zStart = spinalSize(5);
            zLength = brainSize(5) - spinalSize(5);
            spinalMaskRange = [0, -1, 0, -1, zStart, zLength+1];
            
            %% Step 4: Generate spinal-fiber mask
            fprintf('    Step 4: Generate spinal-fiber mask\n');
            
            tmpMask = fullfile(dwiTckDir, sprintf('%s_tmp_mask.nii.gz', volumePath.name));

            cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -add 100 -bin %s', dwiMask, tmpMask);
            executeCmd(cmdline, 'Create temporary mask');
            
            tmpSpinalFiberMask = fullfile(dwiTckDir, sprintf('%s_mask_spinal_fiber_mask%d.nii.gz', volumePath.name, tckIdx));

            cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -roi %d %d %d %d %d %d 0 -1 -bin %s', tmpMask, spinalMaskRange(1), ...
                spinalMaskRange(2), spinalMaskRange(3), spinalMaskRange(4), spinalMaskRange(5), spinalMaskRange(6), tmpSpinalFiberMask);
            executeCmd(cmdline, 'Generate spinal-fiber mask');
            
            dwiTckPath = fullfile(dwiTckFile.folder, dwiTckFile.name);
            [~, tckBaseName, ~] = getFileExtension(dwiTckPath);
            dwiTckCrop = fullfile(dwiTckDir, sprintf('%s_crop.tck', tckBaseName));
            
            if ~isfile(dwiTckPath)
                fprintf('    Warning: tract file not found, skipping\n');
                continue;
            end
            
            fprintf('    [%d/%d] Cropping tract: %s\n', tckIdx, numTcks, dwiTckFile.name);
            
            %% Step 5: Perform tract cropping
            fprintf('    Step 5: Perform tract cropping\n');
            dwiTck = fullfile(dwiTckFile.folder, dwiTckFile.name);

            cmdline = sprintf('tckedit %s -mask %s %s -force', dwiTck, tmpSpinalFiberMask, dwiTckCrop);
            executeCmd(fullfile(mrtrix3Dir, cmdline), 'Crop tract');
            
            %% Step 6: Filter tracts by length
            fprintf('    Step 6: Filter tracts by length\n');
            
            cmdline = sprintf('tckedit %s %s -include %s -minlength %d -force', ...
                dwiTckCrop, dwiTckCrop, dwiSpinalSeed, minFiberLength);
            executeCmd(fullfile(mrtrix3Dir, cmdline), 'Filter tracts by length');
            
            %% Step 7: Clean up temporary files
            fprintf('    Step 7: Clean up temporary files\n');
            
            delete(tmpMask);
        end
    end
end

fprintf('\nTract cropping finished\n');