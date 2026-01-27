function [file_path, file_name, full_ext] = getFileExtension(filepath)
% Purpose: Extract the directory path, file name (without extension), and full extension
% Input:
%   filepath: full file path
% Output:
%   file_path: directory path (excluding file name)
%   file_name: file name (excluding path and extension)
%   full_ext: complete file extension
% Example:
%   [path, name, ext] = getFileExtension('/home/user/data/example.nii.gz');
%   % Result: path = '/home/user/data/', name = 'example', ext = 'nii.gz'
% History:
%   2025-07-01, boddm, Initial version

%% Input validation
if ~ischar(filepath)
    error('Input must be a string');
end

%% Split path and file name
[path_sep, name_with_ext, ext] = fileparts(filepath);

% Handle path
if isempty(path_sep)
    file_path = '';
else
    file_path = path_sep;
end

%% Extract file name and full extension
% fileparts only keeps the last extension, so reprocessing is needed
% Combine name_with_ext and ext to get the complete file name (with extension)
full_file_name = [name_with_ext, ext];

% Split file name and extension
parts = strsplit(full_file_name, '.');

% Handle single extension case
if isscalar(parts)
    % Single extension: return file name and empty extension
    file_name = full_file_name;
    full_ext = '';
else
    % Handle multiple extensions
    full_ext = '';
    idx = [];
    for tmpIdx = length(parts)-1:length(parts)
        if length(parts{tmpIdx}) < 5
            full_ext = sprintf('%s.%s', full_ext, parts{tmpIdx});
            idx = [idx, tmpIdx];
        end
    end
    file_name = strjoin(parts(1:idx(1)-1), '_');
end

end