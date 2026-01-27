function trackGen(dwiFile, outputTck, varargin)
% Function: Perform fiber tractography using MRtrix3 tckgen command
%
% Input:
%   dwiFile - Input DWI data file path (required)
%   outputTck - Output tractography file path (required)
%
% Optional parameters (parameter-value pairs):
%   'includeImage' - Include image path(s) (can be single path or cell array, default: auto-generate spinal cord seed points)
%   'seedImage' - Seed image path (required)
%   'algorithm' - Tractography algorithm (default: 'Tensor_Prob')
%   'cutoff' - Tracking threshold FA value (default: 0.1)
%   'selectCount' - Number of tracts generated per seed point (default: 2000)
%   'stepSize' - Tracking step size in mm (default: 1)
%   'angleThreshold' - Angle threshold in degrees (default: 15)
%   'maxLength' - Maximum tract length in mm (default: 250)
%   'mrtrix3Dir' - MRtrix3 tools directory path (required)
%
% Examples:
%   trackGen(dwiFile, outputTck, 'seedImage', seedImage, 'mrtrix3Dir', mrtrix3Dir);
%   trackGen(dwiFile, outputTck, 'algorithm', 'iFOD2', 'cutoff', 0.05, 'seedImage', seedImage, 'mrtrix3Dir', mrtrix3Dir);
%   trackGen(dwiFile, outputTck, 'includeImage', {'seed1.nii.gz', 'seed2.nii.gz'}, 'seedImage', seedImage, 'mrtrix3Dir', mrtrix3Dir);
%
% History:
%   2025-07-01, boddm, Initial version

%% Parse input parameters
% Set default values
includeImage = {};
seedImage = [];
algorithm = 'Tensor_Prob';
cutoff = 0.1;
selectCount = 2000;
stepSize = 1;
angleThreshold = 15;
maxLength = 250;
mrtrix3Dir = [];

% 解析参数-值对
if mod(length(varargin), 2) ~= 0
    error('Parameter-value pairs must be in name-value form');
end

for i = 1:2:length(varargin)
    paramName = varargin{i};
    paramValue = varargin{i+1};

    switch lower(paramName)
        case 'includeimage'
            % Handle includeImage parameter, can be single string or cell array of strings
            if ischar(paramValue) || isstring(paramValue)
                includeImage = {char(paramValue)};
            elseif iscell(paramValue)
                includeImage = paramValue;
            else
                error('includeImage parameter must be a string or cell array of strings');
            end
        case 'seedimage'
            seedImage = paramValue;
        case 'algorithm'
            algorithm = paramValue;
        case 'cutoff'
            cutoff = paramValue;
        case 'selectcount'
            selectCount = paramValue;
        case 'stepsize'
            stepSize = paramValue;
        case 'anglethreshold'
            angleThreshold = paramValue;
        case 'maxlength'
            maxLength = paramValue;
        case 'mrtrix3dir'
            mrtrix3Dir = paramValue;
        otherwise
            error('Unknown parameter name: %s', paramName);
    end
end

%% Check required parameters
if isempty(seedImage)
    error('Required parameter ''seedImage'' is not specified');
end

if isempty(mrtrix3Dir)
    error('Required parameter ''mrtrix3Dir'' is not specified');
end

%% Check if input files exist
if ~exist(dwiFile, 'file')
    error('Input DWI file does not exist: %s', dwiFile);
end

% Check includeImage files exist
for i = 1:length(includeImage)
    if ~exist(includeImage{i}, 'file')
        error('Include image file does not exist: %s', includeImage{i});
    end
end

if ~exist(seedImage, 'file')
    error('Seed image file does not exist: %s', seedImage);
end

% Check MRtrix3 tools directory exists
if ~exist(mrtrix3Dir, 'dir')
    error('MRtrix3 tools directory does not exist: %s', mrtrix3Dir);
end

%% Check output directory
[outputDir, ~, ~] = fileparts(outputTck);
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

if exist(outputDir, 'dir')
    % 创建临时文件检查写入权限
    tempFile = fullfile(outputDir, '.write_test');
    fid = fopen(tempFile, 'w');
    if fid == -1
        error('Output directory is not writable: %s', outputDir);
    else
        fclose(fid);
        delete(tempFile);
    end
end

%% Parameter validation
if ~isnumeric(cutoff) || cutoff <= 0 || cutoff >= 1
    error('Cutoff value must be a number between 0 and 1');
end

if ~isnumeric(selectCount) || selectCount <= 0
    error('Select count must be a positive number');
end

if ~isnumeric(stepSize) || stepSize <= 0
    error('Step size must be a positive number');
end

if ~isnumeric(angleThreshold) || angleThreshold <= 0 || angleThreshold >= 180
    error('Angle threshold must be a number between 0 and 180 degrees');
end

if ~isnumeric(maxLength) || maxLength <= 0
    error('Maximum length must be a positive number');
end

validAlgorithms = {'Tensor_Prob', 'Tensor_Det', 'iFOD1', 'iFOD2', 'NNA'};
if ~ischar(algorithm) && ~isstring(algorithm)
    error('Algorithm parameter must be a string');
end

algorithm = char(algorithm);
if ~any(strcmpi(algorithm, validAlgorithms))
    error('Invalid tractography algorithm: %s. Valid options: %s', algorithm, strjoin(validAlgorithms, ', '));
end

%% Auto-generate spinal cord seed points (if not provided)
[dwiTrackDir, ~, ~] = fileparts(dwiFile);

% If includeImage is empty, automatically search for all spinal cord seed point files
if isempty(includeImage)
    % Look for tractography directory
    tractographyDir = fullfile(dwiTrackDir, 'tractography');
    
    if exist(tractographyDir, 'dir')
        % Find all .nii.gz files starting with "Seed_spinal_"
        spinalSeedFiles = dir(fullfile(tractographyDir, 'Seed_spinal_*.nii.gz'));
        
        % Sort by filename to ensure consistent order
        [~, sortIdx] = sort({spinalSeedFiles.name});
        spinalSeedFiles = spinalSeedFiles(sortIdx);
        
        % Add all found spinal cord seed point files
        for i = 1:length(spinalSeedFiles)
            seedFile = fullfile(tractographyDir, spinalSeedFiles(i).name);
            includeImage{end+1} = seedFile;
        end
        
        % If no spinal cord seed files found, warn but don't error
        if isempty(includeImage)
            warning('No spinal cord seed point files found, will not include include images');
        else
            fprintf('Auto-found %d spinal cord seed point files\n', length(includeImage));
        end
    else
        warning('tractography directory does not exist: %s', tractographyDir);
    end
end

%% Build tckgen command
% Base command part
cmd = {'tckgen', dwiFile, outputTck, '-algorithm', algorithm, '-cutoff', sprintf('%.1f', cutoff), '-select', num2str(selectCount), '-step', num2str(stepSize), '-angle', num2str(angleThreshold), '-maxlength', num2str(maxLength), '-force'};

% Dynamically add include image parameters
for i = 1:length(includeImage)
    if ~isempty(includeImage{i}) && exist(includeImage{i}, 'file')
        cmd{end+1} = '-include';
        cmd{end+1} = includeImage{i};
    end
end

% Always include seed image
cmd{end+1} = '-seed_image';
cmd{end+1} = seedImage;

% Join command parts into string
tckgenCmd = strjoin(cmd, ' ');

executeCmd(fullfile(mrtrix3Dir, tckgenCmd), 'Perform tractography');
end