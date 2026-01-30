% Purpose: Perform tractography to generate fiber tracts from brain regions to spinal cord
% Input: 
%   data directory path, MRtrix3 tools path, tracking parameters
% Output: 
%   tractography result file (.tck format)
% Example: 
%   M6_2_Tractography_edit2; % Execute tractography
% History: 
%   2025-07-01, boddm, Initial version

clc; clear;

%% Initialize parameters
dataDir = 'example'; % DWI data root directory
mrtrix3Dir = '/usr/local/bin'; % MRtrix3 tools path

%% Define tracking parameters
algorithm = 'Tensor_Prob';
cutoff = 0.1;
selectCount = 2000; 
stepSize = 1;
angleThreshold = 15;
maxLength = 250;

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(mrtrix3Dir, 'dir') == 7, 'MRtrix3 tools directory does not exist: %s', mrtrix3Dir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting tractography, found %d subjects\n\n', numSubjects);

%% Loop through all subjects and volumes
for subjIdx = 1:numSubjects
    subjectPath = subjectPaths(subjIdx); % current subject
    volumePaths = systemdir(fullfile(subjectPath.folder, subjectPath.name)); % all volumes under this subject
    numVolumes = length(volumePaths);
    
    fprintf('\n[%d/%d] Processing subject: %s (%d volumes)\n', subjIdx, numSubjects, subjectPath.name, numVolumes);

    %% Loop through each volume
    for volIdx = 1:numVolumes
        volumePath = volumePaths(volIdx);
        
        fprintf('  Processing volume %d: %s\n', volIdx, volumePath.name);
        
        %% Set directory paths
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI'); % DWI directory
        dwiTckDir = fullfile(dwiDir, 'tractography'); % tractography directory
        if ~exist(dwiTckDir, 'dir')
            fprintf('  Warning: tractography directory does not exist, skipping volume %d\n', volIdx);
            continue; % skip if directory missing
        end

        %% Check DWI file
        dwiFile = fullfile(dwiDir, 'Big_4D_preproc.mif.gz'); % main DWI file
        if ~exist(dwiFile, 'file')
            fprintf('  Warning: DWI file does not exist, skipping volume %d\n', volIdx);
            continue; % skip if DWI file missing
        end
        
        %% Get brain region seeds
        dwiBrainSeeds = systemdir(fullfile(dwiTckDir, '*brain*_bin*')); % list of brain region seed files
        if isempty(dwiBrainSeeds)
            fprintf('  Warning: no brain region seed files found, skipping volume %d\n', volIdx);
            continue; % skip if no seeds
        end

        %% Loop through each brain region seed
        for seedIdx = 1:length(dwiBrainSeeds)
            fprintf('    Processing brain region seed %d: %s\n', seedIdx, dwiBrainSeeds(seedIdx).name);

            %% Get current brain region seed path
            dwiBrainSeed = fullfile(dwiBrainSeeds(seedIdx).folder, dwiBrainSeeds(seedIdx).name); % brain region seed path
            if ~exist(dwiBrainSeed, 'file')
                fprintf('  Warning: brain region seed does not exist: %s, skipping seed %d\n', dwiBrainSeed, seedIdx);
                continue; 
            end
            
            %% Check spinal cord seeds
            dwiSpinalSeed1 = fullfile(dwiTckDir, ['Seed_spinal_C1_thr',num2str(seedIdx), '.nii.gz']);  % spinal C1 seed
            dwiSpinalSeed2 = fullfile(dwiTckDir, ['Seed_spinal_C6_thr',num2str(seedIdx), '.nii.gz']);  % spinal C6 seed
            
            if ~exist(dwiSpinalSeed1, 'file') || ~exist(dwiSpinalSeed2, 'file')
                fprintf('  Warning: spinal cord seeds do not exist: %s or %s, skipping seed %d\n', dwiSpinalSeed1, dwiSpinalSeed2, seedIdx);
                continue;
            end
            
            %% Tractography command
            outputTck = fullfile(dwiTckDir, [volumePath.name, '_tha2C6', num2str(seedIdx), '.tck']); % output tck file

            cmdline = sprintf('tckgen %s %s -algorithm %s -cutoff %.1f -seed_image %s -include %s -include %s -select %d -step %d -angle %d -maxlength %d -force', ...
                dwiFile, outputTck, algorithm, cutoff, dwiSpinalSeed2, dwiBrainSeed, dwiSpinalSeed1, selectCount, stepSize, angleThreshold, maxLength);
            fprintf('      Executing command: %s\n', cmdline);
            [status, ~] = system(fullfile(mrtrix3Dir, cmdline));
            if status ~= 0
                continue;
            end
            
            %% Check generated tck file
            if exist(outputTck, 'file')
                file_info = dir(outputTck);
                if file_info.bytes > 0
                    fprintf('          Tractography completed: %s (%.2f MB)\n', outputTck, file_info.bytes/1024/1024);
                else
                    fprintf('          Generated tck file is empty\n');
                end
            else
                fprintf('          No tck file generated\n');
            end
        end
        
        fprintf('    Volume processing completed\n');
    end
end

fprintf('\n==== Tractography completed for all subjects ====\n');
