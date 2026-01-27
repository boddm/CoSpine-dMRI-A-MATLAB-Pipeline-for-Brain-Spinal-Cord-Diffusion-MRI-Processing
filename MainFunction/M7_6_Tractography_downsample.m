% Purpose: Downsample tractography streamlines to reduce the number of points per streamline
% Inputs: data directory path, MRtrix3 tools path, desired number of nodes after downsampling
% Outputs: downsampled tract files (.tck format)
% Example: M7_6_Tractography_downsample; % Execute tractography downsampling
% History: 2025-12-03 Initial version

clc; clear;

%% Initialize parameters
dataDir = '/Users/boddm/Desktop/杂事/北京IBS/IBS合并_预处理';
mrtrix3Dir = '/home/xd/anaconda3/bin';
numNodes = 3;
tckPattern = '*tha2C6*deleted.tck';

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(mrtrix3Dir, 'dir') == 7, 'MRtrix3 tools directory does not exist: %s', mrtrix3Dir);

%% Retrieve subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting tractography downsampling, %d subjects detected\n\n', numSubjects);

%% Loop over all subjects and volumes
for subjIdx = 1:numSubjects
    subjectPath = subjectPaths(subjIdx);
    subjectDir = fullfile(subjectPath.folder, subjectPath.name);
    volumePaths = systemdir(subjectDir);
    numVolumes = length(volumePaths);
    
    fprintf('[%d/%d] Processing subject: %s (%d volumes)\n', subjIdx, numSubjects, subjectPath.name, numVolumes);
    
    for volIdx = 1:numVolumes
        volumePath = volumePaths(volIdx);
        
        fprintf('  Processing volume %d: %s\n', volIdx, volumePath.name);
        
        %% Set up directory paths
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        dwiTckDir = fullfile(dwiDir, 'tractography');
        
        if ~isfolder(dwiDir) || ~isfolder(dwiTckDir)
            fprintf('  Warning: DWI or tractography directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Locate tract files
        dwiTckDeleteds = systemdir(fullfile(dwiTckDir, tckPattern));
        numTckDeleteds = length(dwiTckDeleteds);
        
        if numTckDeleteds == 0
            fprintf('  Warning: No tract files found, skipping volume %d\n', volIdx);
            continue;
        end
        
        fprintf('    Found %d tract files, starting downsampling\n', numTckDeleteds);
        
        %% Loop over all tract files for downsampling
        for tckIdx = 1:numTckDeleteds
            dwiTckDeleted = dwiTckDeleteds(tckIdx);
            
            tractInput = fullfile(dwiTckDir, dwiTckDeleted.name);
            
            if ~isfile(tractInput)
                fprintf('    Warning: Tract file does not exist, skipping tract %d\n', tckIdx);
                continue;
            end
            
            [~, baseName, ~] = getFileExtension(dwiTckDeleted.name);
            
            dwiTckDownsampled = fullfile(dwiTckDir, sprintf('%s_downsample.tck', baseName));
            
            %% Execute tractography downsampling
            fprintf('    Processing tract %d: %s\n', tckIdx, dwiTckDeleted.name);
            executeCmd(fullfile(mrtrix3Dir, sprintf('tckresample -downsample %d %s %s -force', numNodes, tractInput, dwiTckDownsampled)), 'Tractography downsampling');
        end
    end
end

fprintf('\nTractography downsampling completed\n');