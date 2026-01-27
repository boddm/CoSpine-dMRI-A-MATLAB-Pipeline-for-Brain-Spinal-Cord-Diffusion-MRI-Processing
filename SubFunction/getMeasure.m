function diffMeas = getMeasure(coord, diffPath)
% Function: Extract diffusion parameter values from 3D coordinates
% Input: 
%   coord: Coordinate data, cell array containing 3D coordinate points [1×n cell]
%   diffPath: Diffusion parameter image file path [string]
% Output: 
%   diffMeas: Diffusion parameter values at given coordinate points, array of dimension n*1
% Example: 
%   diff_values = getMeasure(coord, 'diffusion.nii.gz');
% History:
%   2025-07-01, boddm, Initial version

%% File format check and preprocessing: Check file extension
[~, ~, fullExt] = getFileExtension(diffPath);
if ~(contains(fullExt, 'nii.gz') || contains(fullExt, 'nii'))
    error('Please provide diffusion parameter file in nii format');
end

% Process compressed file
if contains(fullExt, 'nii.gz')
    executeCmd(sprintf('gzip -d -k "%s"', diffPath), 'Decompressing file');
    diffPath = diffPath(1:end-3);  % Remove .gz extension
end

% Verify file existence
if ~exist(diffPath, 'file')
    error('Cannot find diffusion parameter file: %s', diffPath);
end

%% Read image data: Load diffusion parameter image
volInfo = spm_vol(diffPath);
volData = spm_read_vols(volInfo);
[volHeight, volWidth, volDepth] = size(volData);  % Get image dimensions

%% Coordinate interpolation calculation: Define interpolation grid
voxX = 1:volWidth;  % X axis: 1 to width (corresponding to column index) 
voxY = 1:volHeight;  % Y axis: 1 to height (corresponding to row index)
voxZ = 1:volDepth;  % Z axis: 1 to depth (corresponding to slice index)

%% Loop through each coordinate point
for i = 1:length(coord)
    if mod(i, 50) == 0
        disp(['Processed ', num2str(i), ' items']);
    end
    
    % Convert MNI coordinates to voxel coordinates
    tmp_fiber = MNI2VOX(coord{i}', volInfo.mat);
    tmp_fiber = tmp_fiber';
    
    % Trilinear interpolation to calculate diffusion parameter values
    diffMeas(i, :) = interp3(voxX, voxY, voxZ, volData, tmp_fiber(:, 2), tmp_fiber(:, 1), tmp_fiber(:, 3), "cubic");
end

%% Clean up temporary files: Delete decompressed file (if exists)
if exist(diffPath, 'file')
    delete(diffPath);
    disp(['Deleted temporary file: ', diffPath]);
end

end