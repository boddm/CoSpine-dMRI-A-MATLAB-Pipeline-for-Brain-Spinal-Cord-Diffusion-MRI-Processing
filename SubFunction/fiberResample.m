function coordR = fiberResample(coord, numNodes, flag)
% Purpose: Resample DTI fiber tracts to generate uniformly-distributed points
%          by node count or step length
% Inputs:
%   coord: N×3 DTI fiber coordinate data, N points, 3 spatial dimensions
%   numNodes: resampling parameter; node count if flag=='N', step length if flag=='L'
%   flag: resampling mode, 'N' for node count, 'L' for step length
% Output:
%   coordR: resampled DTI fiber coordinates, N×3
% Example:
%   resampledFiber = fiberResample(fiberCoord, 100, 'N');
% History:
%   2025-07-01, boddm, Initial version
%   2025-12-04, boddm, changed I/O format to N×3

%% Handle input arguments
if ~exist('flag', 'var') || isempty(flag)
    flag = 'N';  % default resampling mode: by node count
end

%% Step 1: Remove NaNs, keep valid coordinates
fiberNoNan = coord(~any(isnan(coord), 2), :);  % discard rows containing NaN

%% Step 2: Size of valid fiber
sizeI = size(fiberNoNan, 1);  % number of points

%% Step 3: Validate data
if (strcmp(flag, 'N') && numNodes == 1) || (sizeI == 0) || (sizeI == 1)
    error('All NaNs, or only one non-NaN point, or requested node count is 1');
end

%% Step 4: Compute inter-node and cumulative distances
nodeToNodeDist = squareform(pdist(coord));  % pairwise distance matrix
archCumDist = cumsum(diag(nodeToNodeDist, 1));  % cumulative distance along fiber

%% Step 5: Build spline interpolants
% spline interpolation for each coordinate dimension
f_x = spline([0; archCumDist], fiberNoNan(:, 1));
f_y = spline([0; archCumDist], fiberNoNan(:, 2));
f_z = spline([0; archCumDist], fiberNoNan(:, 3));

%% Step 5: Determine resampling step according to mode
switch flag
    case 'N'
        stepP = archCumDist(end) / (numNodes - 1);  % node-count mode: inter-node spacing
    case 'L'
        stepP = numNodes;  % step-length mode: use given step
    otherwise
        error('Flag must be L or N');
end

%% Step 6: Generate parameter values for resampling
t = 0:stepP:archCumDist(end);

%% Step 7: Perform resampling
% interpolate each coordinate dimension
x_interp = ppval(f_x, t);
y_interp = ppval(f_y, t);
z_interp = ppval(f_z, t);

% concatenate into N×3 format
coordR = [x_interp', y_interp', z_interp'];
end