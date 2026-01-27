% Purpose: Perform tractography to generate fiber tracts from brain regions to spinal cord
% Inputs: 
%   data directory path, MRtrix3 tools path, tracking parameters
% Output: 
%   tractography result file (.tck format)
% Example: 
%   M6_2_Tractography_edit; % Run tractography
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = 'example';
mrtrix3Dir = '/usr/local/bin';
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

%% Loop over all subjects and volumes
for subjIdx = 1:numSubjects
    subjectPath = subjectPaths(subjIdx);
    volumePaths = systemdir(fullfile(subjectPath.folder, subjectPath.name));
    numVolumes = length(volumePaths);
    
    fprintf('[%d/%d] Processing subject: %s (%d volumes)\n', subjIdx, numSubjects, subjectPath.name, numVolumes);
    
    for volIdx = 1:numVolumes
        volumePath = volumePaths(volIdx);
        
        fprintf('  Processing volume %d: %s\n', volIdx, volumePath.name);
        
        %% Set directory paths
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        dwiTckDir = fullfile(dwiDir, 'tractography');
        
        if ~isfolder(dwiTckDir)
            fprintf('  Warning: tractography directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Locate DWI preprocessed file
        dwiFile = fullfile(dwiDir, 'Big_4D_preproc.mif.gz');
        
        if ~isfile(dwiFile)
            fprintf('  Warning: DWI preprocessed file does not exist, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Locate brain seed files
        dwiBrainSeeds = systemdir(fullfile(dwiTckDir, '*brain*_bin*'));
        numBrainSeeds = length(dwiBrainSeeds);
        
        if numBrainSeeds == 0
            fprintf('  Warning: No brain seed files found, skipping volume %d\n', volIdx);
            continue;
        end
        
        fprintf('    Found %d brain seeds, starting tractography\n', numBrainSeeds);
        
        %% Loop over all seeds to perform tractography
        for seedIdx = 1:numBrainSeeds
            dwiSeedFile = dwiBrainSeeds(seedIdx);
            dwiSeed = fullfile(dwiSeedFile.folder, dwiSeedFile.name);
            
            dwiInclude1 = fullfile(dwiTckDir, sprintf('Seed_spinal_C1_thr%d.nii.gz', seedIdx));
            dwiInclude2 = fullfile(dwiTckDir, sprintf('Seed_spinal_C6_thr%d.nii.gz', seedIdx));
            
            outputTck = fullfile(dwiTckDir, sprintf('%s_tha2C6%d.tck', volumePath.name, seedIdx));
            
            if ~isfile(dwiSeed)
                fprintf('    Warning: seed file does not exist, skipping seed %d\n', seedIdx);
                continue;
            end
            
            if ~isfile(dwiInclude1) || ~isfile(dwiInclude2)
                fprintf('    Warning: spinal cord seed files do not exist, skipping seed %d\n', seedIdx);
                continue;
            end
            
            fprintf('    [%d/%d] Running tractography...\n', seedIdx, numBrainSeeds);
            
            trackGen(dwiFile, outputTck, 'seedImage', dwiSeed, 'includeImage', {dwiInclude1, dwiInclude2}, ...
                'algorithm', algorithm, 'cutoff', cutoff, 'selectCount', selectCount, 'stepSize', stepSize, ...
                'angleThreshold', angleThreshold, 'maxLength', maxLength, 'mrtrix3Dir', mrtrix3Dir);
        end        
    end
end

fprintf('\nTractography completed\n');