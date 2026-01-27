function bs = readBSValue(targetDir)
% Purpose: Read bs value
% Inputs:
%   targetDir: Path to target directory
% Outputs:
%   bs: The bs value read
% Example:
%   bsValue = readBSValue(targetDirectory);
% History:
%   2025-07-01, boddm, Initial version

%% Validate input path
assert(exist(targetDir, 'dir') == 7, 'Target directory does not exist: %s', targetDir);

%% Find files starting with "bs" in target directory
bsFiles = systemdir(fullfile(targetDir, 'bs*'));

if isempty(bsFiles)
    error('No bs files found in directory: %s', targetDir);
end

%% Extract bs value from filename
parts = split(bsFiles(1).name, '=');

if numel(parts) < 2
    error('bs file format error: %s', bsFiles(1).name);
end

%% Convert string to number
bs = str2double(parts{2});

end