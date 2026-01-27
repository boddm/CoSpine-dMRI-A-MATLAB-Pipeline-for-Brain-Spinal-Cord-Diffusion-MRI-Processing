function pathName = systemdir(dirPath)
% Purpose: Get a list of files in the directory
% Inputs:
%   dirPath: directory path
% Output:
%   pathName: list of files
% Example:
%   files = systemdir('/path/to/directory');
% History:
%   2025-07-01, boddm, Initial version

%% Input argument check
if nargin < 1
    error('Please provide the directory path argument');
end

try
    % Get directory listing
    pathList = dir(dirPath);

    % Handle empty directory case
    if isempty(pathList)
        error('No files found in the specified path: %s', dirPath);
    end

    % Filter valid filenames (exclude hidden and system files)
    validIdx = cellfun(@isValidFileName, {pathList.name});
    pathName = pathList(validIdx);

    % Adjust output format to row vector
    pathName = reshape(pathName, 1, []);

catch e
    %% Exception handling
    error('Error processing path: %s\nError message: %s', dirPath, e.message);
end
end

function isValid = isValidFileName(name)
% Helper function: check if filename is valid (non-hidden file)
isValid = ~isempty(name) && isstrprop(name(1), 'alphanum');
end