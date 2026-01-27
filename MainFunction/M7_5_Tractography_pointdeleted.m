% Function: Remove and adjust intermediate points in tractography fibers, clean invalid data
% Input: 
%   Path to data directory
% Output: 
%   Processed tractography files (.tck format)
% Example: 
%   M7_5_Tractography_pointdeleted; % Execute intermediate point deletion
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/Users/boddm/Desktop/杂事/北京IBS/IBS合并_预处理';
tckPattern = '*tha2C6*match_point.tck';

%% Validate input path
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting tractography intermediate point deletion, found %d subjects\n\n', numSubjects);

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
        dwiTckDir = fullfile(volumePath.folder, volumePath.name, 'DWI', 'tractography');
        
        if ~isfolder(dwiTckDir)
            fprintf('  Warning: Tractography directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Search for tractography files
        dwiTckPoints = systemdir(fullfile(dwiTckDir, tckPattern));
        numTckPoints = length(dwiTckPoints);
        
        if numTckPoints == 0
            fprintf('  Warning: No tractography files found, skipping volume %d\n', volIdx);
            continue;
        end
        
        fprintf('    Found %d tractography files, starting intermediate point deletion\n', numTckPoints);
        
        %% Loop through all tractography files to delete intermediate points
        for tckIdx = 1:numTckPoints
            dwiTckPoint = dwiTckPoints(tckIdx);
            
            inputTck = fullfile(dwiTckDir, dwiTckPoint.name);
            
            [~, baseName, ~] = getFileExtension(dwiTckPoint.name);
            dwiTckDeleted = fullfile(dwiTckDir, sprintf('%s_deleted.tck', baseName));
            
            if ~isfile(inputTck)
                fprintf('    Warning: Tractography file does not exist, skipping fiber %d\n', tckIdx);
                continue;
            end
            
            fprintf('    Processing fiber %d: %s\n', tckIdx, dwiTckPoint.name);
            
            %% Read tractography data
            tracks = read_mrtrix_tracks(inputTck);
            
            if isempty(tracks) || isempty(tracks.data)
                fprintf('    Warning: Tractography data is empty, skipping\n');
                continue;
            end
            
            numOriginal = length(tracks.data);
            
            %% Step 1: Identify fibers with invalid intermediate points
            idxMiddle = false(1, length(tracks.data));
            
            for i = 1:length(tracks.data)
                fiber = tracks.data{i};
                
                if size(fiber, 1) > 9
                    middlePoints = fiber(6:end-1, :);
                    
                    if any(all(middlePoints == [0 0 0], 2))
                        idxMiddle(i) = true;
                    end
                end
            end
            
            %% Step 2: Delete fibers with invalid intermediate points
            if any(idxMiddle)
                tracks.data(idxMiddle) = [];
                numAfterDeletion = length(tracks.data);
                fprintf('    Deleted %d/%d fibers with invalid intermediate points\n', sum(idxMiddle), numOriginal);
            end
            
            %% Step 3: Adjust fiber points
            numAdjusted = 0;
            
            for i = 1:length(tracks.data)
                fiber = tracks.data{i};
                numPoints = size(fiber, 1);
                
                if numPoints > 6
                    tracks.data{i}(1:5, :) = [];
                    
                    tracks.data{i}(end, :) = [];
                    numAdjusted = numAdjusted + 1;
                else
                    tracks.data{i} = [];
                end
            end
            
            tracks.data = tracks.data(~cellfun(@isempty, tracks.data));
            
            numFinal = length(tracks.data);
            fprintf('    Adjusted %d fibers, remaining %d fibers\n', numAdjusted, numFinal);
            
            %% Step 4: Save processed fibers
            if numFinal > 0
                write_mrtrix_tracks(tracks, dwiTckDeleted);
            else
                fprintf('    Warning: No fibers retained after processing, skipping save\n');
            end
        end
    end
end

fprintf('\nTractography intermediate point deletion processing completed\n');