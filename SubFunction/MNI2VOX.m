function vox = MNI2VOX(mni, mat)
% Purpose: Convert MNI coordinates to voxel coordinates
% Inputs:
%   mni: MNI coordinate data
%   mat: transformation matrix
% Output:
%   vox: converted voxel coordinates
% Example:
%   voxCoords = MNI2VOX(mniCoords, transformMatrix);
% History:
%   2025-07-01, boddm, Initial version

%% Check input parameter count
if nargin ~= 2
    error('Incorrect number of input parameters: 2 required (mni, mat)');
end

%% Check MNI coordinate dimensions
sizeMni = size(mni);
if sizeMni(1) < 3 || sizeMni(1) > 4
    error('MNI coordinate dimension error: 3xN or 4xN matrix required');
end

%% Check transform matrix dimensions
sizeMat = size(mat);
if ~all(sizeMat == [4 4])
    error('Transform matrix dimension error: 4x4 matrix required');
end

%% Execute coordinate conversion
% Convert MNI coordinates to homogeneous coordinates (add one row)
mni = [mni(1:3, :); ones(1, sizeMni(2))];

%% Use inverse transformation matrix to convert MNI coordinates to voxel coordinates
vox = inv(mat) * mni;

end