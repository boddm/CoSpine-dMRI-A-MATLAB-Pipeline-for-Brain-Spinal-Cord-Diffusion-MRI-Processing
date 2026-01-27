% Function: Calculate diffusion tensor metrics for fiber tracts (FA, AD, MD, RD)
% Input: 
%   Data directory path, list of diffusion metrics
% Output: 
%   Fiber tract diffusion metric files (.mat format)
% Example: 
%   M7_7_Tractography_dtifit; % Calculate fiber tract diffusion tensor metrics
% History:
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/Users/boddm/Desktop/杂事/北京IBS/IBS合并_预处理';
diffMetrics = {'FA', 'AD', 'MD', 'RD'};
tckPattern = '*tha2C6*downsample.tck';

%% Validate input path
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting fiber tract diffusion tensor metric calculation, found %d subjects\n\n', numSubjects);

%% Iterate through all subjects and volumes
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
        
        %% Find downsampled fiber tract files
        dwiTckDownsampleds = systemdir(fullfile(dwiTckDir, tckPattern));
        numTckDownsampleds = length(dwiTckDownsampleds);
        
        if numTckDownsampleds == 0
            fprintf('  Warning: No fiber tract files found, skipping volume %d\n', volIdx);
            continue;
        end
        
        fprintf('    Found %d fiber tract files, starting diffusion tensor metric calculation\n', numTckDownsampleds);
        
        %% Iterate through all fiber tract files to calculate diffusion metrics
        for tckIdx = 1:numTckDownsampleds
            dwiTckDownsampled = dwiTckDownsampleds(tckIdx);

            tckPath = fullfile(dwiTckDir, dwiTckDownsampled.name);
            
            if ~isfile(tckPath)
                fprintf('    Warning: Fiber tract file does not exist, skipping fiber tract %d\n', tckIdx);
                continue;
            end
            
            fprintf('    Processing fiber tract %d: %s\n', tckIdx, dwiTckDownsampled.name);
            
            %% Read fiber tract data
            track = read_mrtrix_tracks(tckPath);
            
            if isempty(track) || isempty(track.data)
                fprintf('    Warning: Fiber tract data is empty, skipping\n');
                continue;
            end
            
            diffMeas = struct();
            success = true;
            
            %% Iterate through all diffusion metrics for calculation
            for metricIdx = 1:length(diffMetrics)
                metricName = diffMetrics{metricIdx};
                
                dwiDiffFiles = systemdir(fullfile(dwiDir, ['*_' metricName '.nii.gz']));
                
                if isempty(dwiDiffFiles)
                    fprintf('      Warning: No %s diffusion metric file found, skipping\n', metricName);
                    success = false;
                    break;
                elseif length(dwiDiffFiles) > 1
                    fprintf('      Warning: Multiple %s diffusion metric files found, using the first one\n', metricName);
                end
                
                diffPath = fullfile(dwiDiffFiles(1).folder, dwiDiffFiles(1).name);
                
                %% Calculate diffusion metrics for current fiber tract
                diffMeas.(metricName) = getMeasure(track.data, diffPath);
            end
            
            %% Save diffusion metric results
            if success && ~isempty(fieldnames(diffMeas))
                [~, baseName, ~] = fileparts(dwiTckDownsampled.name);
                savePath = fullfile(dwiTckDir, baseName);
                
                save(savePath, 'diffMeas', '-v7.3');
                fprintf('    Successfully saved diffusion metric results\n');
            end
            
            %% Clear memory
            clear track diffMeas;
        end
    end
end

fprintf('\nFiber tract diffusion tensor metric calculation completed\n');