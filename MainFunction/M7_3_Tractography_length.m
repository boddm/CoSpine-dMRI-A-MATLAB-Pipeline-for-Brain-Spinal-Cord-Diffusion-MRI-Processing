% Purpose: Length filtering of fiber tracts, keeping fibers within reasonable length range
% Input: 
%   Path to data directory, path to MRtrix3 tools
% Output: 
%   Filtered fiber tract files (.tck format)
% Example: 
%   M7_3_Tractography_length; % Execute fiber length filtering
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/Users/boddm/Desktop/杂事/北京IBS/IBS合并_预处理';
mrtrix3Dir = '/home/xd/anaconda3/bin';
tckPattern = '*tha2C6*edit.tck';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(mrtrix3Dir, 'dir') == 7, 'MRtrix3 tools directory does not exist: %s', mrtrix3Dir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting fiber tract length filtering, found %d subjects\n\n', numSubjects);

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
        
        %% Set directory paths
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        dwiTckDir = fullfile(dwiDir, 'tractography');
        
        if ~isfolder(dwiDir) || ~isfolder(dwiTckDir)
            fprintf('  Warning: DWI or fiber tract directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Find fiber tract files
        dwiTckEdits = systemdir(fullfile(dwiTckDir, tckPattern));
        numTckEdits = length(dwiTckEdits);
        
        if numTckEdits == 0
            fprintf('  Warning: No fiber tract files found, skipping volume %d\n', volIdx);
            continue;
        end
        
        fprintf('    Found %d fiber tract files, starting length filtering\n', numTckEdits);
        
        %% Process each fiber tract file
        for tckIdx = 1:numTckEdits
            dwiTckEditFile = dwiTckEdits(tckIdx);
            dwiTckEdit = fullfile(dwiTckEditFile.folder, dwiTckEditFile.name);
            
            if ~isfile(dwiTckEdit)
                fprintf('    Warning: Fiber tract file does not exist, skipping fiber tract %d\n', tckIdx);
                continue;
            end
            
            [~, baseName, ~] = getFileExtension(dwiTckEdit);
            dwiTckLength = fullfile(dwiTckDir, sprintf('%s_length.tck', baseName));
            
            fprintf('    Processing fiber tract %d: %s\n', tckIdx, dwiTckEditFile.name);
            
            %% Read fiber tract data
            tracks = read_mrtrix_tracks(dwiTckEdit);
            
            %% Calculate lengths of all fibers
            fiberLengths = cellfun(@(x) length(x), tracks.data);
            
            %% Compute length thresholds
            med = quantile(fiberLengths, 0.7);
            
            lower = med - 5;
            upper = med + 5;
            
            %% Filter fibers within length range
            idxKeep = (fiberLengths >= lower) & (fiberLengths <= upper);
            numKept = sum(idxKeep);
            numTotal = length(fiberLengths);
            
            fprintf('    Retained %d/%d fibers (length range: %.1f-%.1f)\n', numKept, numTotal, lower, upper);
            
            tracks.data = tracks.data(idxKeep);
            
            %% Save filtered fiber tracts
            write_mrtrix_tracks(tracks, dwiTckLength);
        end
    end
end

fprintf('\nFiber tract length filtering completed\n');