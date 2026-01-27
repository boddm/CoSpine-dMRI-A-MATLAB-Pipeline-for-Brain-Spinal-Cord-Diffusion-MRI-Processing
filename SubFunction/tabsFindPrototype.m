function prototype = tabsFindPrototype(tracts, template)
% Function: Calculate fiber tract density and find prototype fiber tract
% Input:
%   tracts: Fiber tract data
%   template: Template file path
% Output:
%   prototype: Prototype fiber tract index
% Example:
%   prototypeIdx = tabsFindPrototype(tracts, templatePath);
% History:  
%   2025-07-01, boddm, Initial version

%% Input parameter validation
if ~iscell(tracts)
    error('Input fiber tract group must be in cell array format');
end

if ~exist(template, 'file')
    error('Template file does not exist, please check path: %s', template);
end

%% Read template file and transformation matrix
v = spm_vol(template);  % Read volume information of template file
mat = v.mat;  % Get transformation matrix of template file

%% Convert all fiber tracts to voxel coordinates
coord = cell(length(tracts), 1);  % Initialize coordinate storage array

% Process each fiber tract in parallel, convert to voxel coordinates
parfor i = 1:length(tracts)
    % Convert fiber tract from MNI coordinates to voxel coordinates
    coord{i} = MNI2VOX(tracts{i}', mat)';

    % Round up and remove duplicate points to reduce computation
    coord{i} = unique(ceil(coord{i}(:, 1:3)), 'row');
end

%% Calculate fiber tract density map
% Merge voxel coordinates of all fiber tracts into one matrix
fiberDataVox = vertcat(coord{:});

% Count the number of fiber tract points in each voxel
[count, ~, n] = unique(fiberDataVox, 'row');
c = tabulate(n);
count = [count c(:,2)];  % Merge voxel coordinates and counts

%% Clear temporary variables, release memory
clear coord c n fiberDataVox

%% Calculate density for each fiber tract
fiberDensity = zeros(length(tracts), 1);  % Initialize fiber tract density array

% Create KNN search model for fast nearest voxel search
mdl = KDTreeSearcher(count(:, 1:3));

% Process each fiber tract in parallel, calculate its density
parfor i = 1:length(tracts)
    % Convert current fiber tract to voxel coordinates
    fiberDataVox = MNI2VOX(tracts{1, i}', mat)';
    fiberDataVox = ceil(fiberDataVox(:, 1:3));

    % Remove duplicate points to reduce computation
    tmpCount = unique(fiberDataVox, 'row');

    % Find corresponding position of each voxel in density map
    idx = knnsearch(mdl, tmpCount, 'K', 1);

    % Calculate total density of current fiber tract
    num = sum(count(idx, 4));
    fiberDensity(i) = num / length(tmpCount);  % Calculate average density
end

%% Find fiber tract with maximum density as prototype
% Find index of fiber tract with maximum density
prototype = find(fiberDensity == max(fiberDensity));

% If multiple fiber tracts have same density, select the first one
prototype = prototype(1);

end