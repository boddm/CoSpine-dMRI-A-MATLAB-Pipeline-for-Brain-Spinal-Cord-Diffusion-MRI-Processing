% Purpose: Perform point matching processing on tractography fibers
% Input:
%   dataDir: Data directory path containing all subject folders
%   tckPattern: Tractography file name pattern, default '*tha2C6*resample.tck'
%   discThreshold: Point matching distance threshold, default 1mm
%   numCores: Number of parallel processing cores, default 10
% Output:
%   No direct output, processing results are saved in the original tractography file directory
% Example:
%   M7_5_Tractography_pointmatch; % Execute script to perform point matching on tractography
% History:
%   2025-07-01, boddm, Initial version
clc, clear;

%% Set paths and parameters
dataDir = '/media/xd/脑影像/IBS_baseline/DATA/Sub04';
tckPattern = '*tha2C6*resample.tck';

discThreshold = 1;
numCores = 10;

%% Validate input path
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);

%% Initialize parallel pool (if needed)
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting tractography point matching processing, found %d subjects\n\n', numSubjects);

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
        
        %% Set tractography directory path
        dwiTckDir = fullfile(volumePath.folder, volumePath.name, 'DWI', 'tractography');
        
        % Check if tractography directory exists, skip if not
        if ~exist(dwiTckDir, 'dir')
            continue;
        end
        
        %% Prepare DWI mask file (decompress gzip file)
        dwiMaskGz = fullfile(dwiTckDir, [volumePath.name, '_mask.nii.gz']);
        dwiMask = fullfile(dwiTckDir, [volumePath.name, '_mask.nii']);
        
        if exist(dwiMaskGz, 'file')
            gunzip(dwiMaskGz, dwiTckDir);
        else
            continue;
        end
        
        %% Get list of tractography files to process
        dwiTckResamples = systemdir(fullfile(dwiTckDir, tckPattern));
        
        %% Loop through all tractography files to perform point matching processing
        for tckIdx = 1:numel(dwiTckResamples)
            dwiTckResample = dwiTckResamples(tckIdx);
            
            %% Set input and output file paths
            [~, baseName, ~] = getFileExtension(dwiTckResample.name);
            dwiTckPoint = fullfile(dwiTckDir, [baseName, '_match_point.tck']);
            
            dwiTckPointMask = fullfile(dwiTckDir, [baseName, '_match_mask.mat']);
            
            %% Read tractography data
            tracks = read_mrtrix_tracks(fullfile(dwiTckDir, dwiTckResample.name));
            
            if isempty(tracks) || isempty(tracks.data)
                continue;
            end
            
            %% Perform point matching processing
            [~, ~, ~, ~, coord, coordMask] = tabsPointMatch(tracks.data, dwiMask, discThreshold);
            
            %% Save processing results
            tracks.data = coord;
            
            write_mrtrix_tracks(tracks, dwiTckPoint);
            
            save(dwiTckPointMask, 'coordMask');
        end
        
        % Clean up temporary files
        delete(dwiMask);
    end
end

fprintf('\nTractography point matching processing completed\n');