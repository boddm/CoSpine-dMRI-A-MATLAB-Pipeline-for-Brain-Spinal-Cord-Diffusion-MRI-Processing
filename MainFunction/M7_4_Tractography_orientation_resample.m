% Purpose: Re-orient and re-sample fiber tracts, unify the number of nodes per tract
% Input: 
%   Path to data directory, desired number of nodes after re-sampling
% Output: 
%   Re-sampled tractography files (.tck format)
% Example: 
%   M7_4_Tractography_orientation_resample; % Run tract re-orientation and re-sampling
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/Users/boddm/Desktop/杂事/北京IBS/IBS合并_预处理';
tckPattern = '*tha2C6*length.tck';
numNodes = 185;

%% Validate input path
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting fiber orientation adjustment and resampling, found %d subjects\n\n', numSubjects);

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
            fprintf('  Warning: DWI or tractography directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Locate tractography files
        dwiTckLengths = systemdir(fullfile(dwiTckDir, tckPattern));
        numTckLengths = length(dwiTckLengths);
        
        if numTckLengths == 0
            fprintf('  Warning: No tractography files found, skipping volume %d\n', volIdx);
            continue;
        end
        
        fprintf('    Found %d tractography files, starting orientation adjustment and resampling\n', numTckLengths);
        
        %% Process each tractography file
        for tckIdx = 1:numTckLengths
            dwiTckLength = dwiTckLengths(tckIdx); 
            
            inputTck = fullfile(dwiTckDir, dwiTckLength.name);
            
            if ~isfile(inputTck)
                fprintf('    Warning: Tractography file does not exist, skipping tract %d\n', tckIdx);
                continue;
            end
            
            [~, baseName, ~] = getFileExtension(dwiTckLength.name);
            dwiTckResample = fullfile(dwiTckDir, sprintf('%s_orien_resample.tck', baseName));
            
            fprintf('    Processing tract %d: %s\n', tckIdx, dwiTckLength.name);
            
            %% Read tractography data
            tracks = read_mrtrix_tracks(inputTck);
            
            if isempty(tracks) || isempty(tracks.data)
                fprintf('    Warning: Tractography data is empty, skipping\n');
                continue;
            end
            
            %% Perform orientation adjustment and resampling
            [tracksOut.data, ~, ~, ~] = reorientFibers(tracks.data, numNodes);
            
            %% Save resampled tractography
            write_mrtrix_tracks(tracksOut, dwiTckResample);
        end
    end
end

fprintf('\nFiber orientation adjustment and resampling completed\n');