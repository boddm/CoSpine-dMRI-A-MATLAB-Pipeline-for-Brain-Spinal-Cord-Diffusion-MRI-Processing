% Purpose: Standardize DWI and T1 file naming conventions and create necessary directory structure
% Inputs: 
%   None
% Outputs: 
%   None
% Example: 
%   M1_format_correct;
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/Users/boddm/Desktop/杂事/北京IBS/IBS合并_预处理';

%% Validate input path
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);

%% Get subject list
subjPaths = systemdir(dataDir);
numSubjects = length(subjPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting DWI file naming format processing, found %d subjects\n', numSubjects);

%% Loop through all subjects
for subjIdx = 1:numSubjects
    subjPath = subjPaths(subjIdx);
    volumePaths = systemdir(fullfile(subjPath.folder, subjPath.name));
    numVolumes = length(volumePaths);

    fprintf('[%d/%d] Processing subject: %s (%d volumes)\n', subjIdx, numSubjects, subjPath.name, numVolumes);
    
    %% Process each volume
    for volIdx = 1:numVolumes
        volPath = volumePaths(volIdx);

        fprintf('  [%d/%d] Processing volume: %s\n', volIdx, numVolumes, volPath.name);

        %% Check DWI directory
        dwiDir = fullfile(volPath.folder, volPath.name, 'DWI');

        if ~isfolder(dwiDir)
            fprintf('    Warning: DWI directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end

        %% Find DWI files
        dwiFiles = systemdir(fullfile(dwiDir));
        if isempty(dwiFiles)
            fprintf('    Warning: No files found in DWI directory, skipping volume %d\n', volIdx);
            continue;
        end

        %% Rename DWI files
        fprintf('    Found %d DWI files, starting rename\n', length(dwiFiles));

        renamedCount = 0;

        for dwiIdx = 1:length(dwiFiles)
            %% Process DWI file
            fileName = dwiFiles(dwiIdx).name;
            [~, ~, ext] = getFileExtension(fileName);

            if contains(fileName, 'b0')
                newName = [volPath.name, '_PA_B0.', ext];
            elseif contains(fileName, 'AP')
                newName = [volPath.name, '_AP.', ext];
            else
                continue;
            end

            %% Rename DWI file
            oldPath = fullfile(dwiDir, fileName);
            newPath = fullfile(dwiDir, newName);

            if isfile(newPath)
                fprintf('    Warning: Target file already exists, skipping volume %d: %s\n', volIdx, newName);
                continue;
            end

            movefile(oldPath, newPath);
            renamedCount = renamedCount + 1;
        end

        fprintf('    Successfully renamed %d DWI files\n', renamedCount);

        %% Check T1 directory
        anatDir = fullfile(volPath.folder, volPath.name, 'ANAT');
        if ~isfolder(anatDir)
            fprintf('    Warning: ANAT directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end

        %% Find T1 files
        t1Files = systemdir(fullfile(anatDir));
        if isempty(t1Files)
            fprintf('    Warning: No files found in ANAT directory, skipping volume %d\n', volIdx);
            continue;
        end

        %% Rename T1 files
        fprintf('    Found %d T1 files, starting rename\n', length(t1Files));

        renamedCount = 0;

        for t1Idx = 1:length(t1Files)
            %% Process T1 file
            fileName = t1Files(t1Idx).name;
            [~, ~, ext] = getFileExtension(fileName);
            newName = [volPath.name, '_T1.', ext];

            %% Rename T1 file
            oldPath = fullfile(anatDir, fileName);
            newPath = fullfile(anatDir, newName);

            if isfile(newPath)
                fprintf('    Warning: Target file already exists, skipping volume %d: %s\n', volIdx, newName);
                continue;
            end

            movefile(oldPath, newPath);
            renamedCount = renamedCount + 1;
        end

        fprintf('    Successfully renamed %d T1 files\n', renamedCount);
    end
end

fprintf('\nFile naming format standardization completed\n');