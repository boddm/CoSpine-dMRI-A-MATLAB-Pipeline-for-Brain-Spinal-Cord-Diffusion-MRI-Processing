function [protype, tBefore, coordBefore, tValues, coord, coordMask] = tabsPointMatch(tracts, template, disc)
% Purpose: Match points of fiber bundles to a template
% Input:
%   tracts: Fiber bundle data
%   template: Template file path
%   disc: Step size for point sampling
% Output:
%   protype: Index of prototype fiber bundle
%   tBefore: t-values before matching
%   coordBefore: Coordinates before matching
%   tValues: t-values after matching
%   coord: Coordinates after matching
%   coordMask: Coordinate mask
% Example:
%   [pro, tBef, coordBef, tVals, coord, coordMask] = tabsPointMatch(tracts, template, 10);
% History:
%   2025-07-01, boddm, Initial version

%% Calculate index of prototype fiber bundle
protype = tabsFindPrototype(tracts, template);
protract = tracts{protype};

%% Determine point sampling step size for prototype fiber bundle
getPoint = 1:disc:length(protract);

%% Adjust sampling point number to ensure not exceeding fiber bundle length
if getPoint(end) <= length(protract)
    lenPro = length(getPoint);
else
    lenPro = length(getPoint) - 1;
    getPoint = getPoint(1:lenPro);
end

%% Initialize output variables
coordBefore{protype} = protract(getPoint, :);
coord{protype} = protract(getPoint, :);

%% Initialize t-value variables
tBefore = cell(1, length(tracts));
tValues = cell(1, length(tracts));

%% Parallel processing each fiber bundle to perform curve matching
parfor ii = 1:length(tracts)
    if ii ~= protype
        [tBefore{ii}, coordBefore{ii}, tValues{ii}, coord{ii}] = tabsPointMatch_curves(protract(getPoint, :), tracts{ii});
    end
end

%% Generate coordinate mask 
numFibers = length(coord);
numPoints = length(coord{1});
coordMask = ones(numFibers, numPoints);

%% Traverse all fiber bundles and points to mark invalid points (x-coordinate is 0)
for i = 1:numFibers
    for j = 1:numPoints
        if coord{1,i}(j, 1) == 0
            coordMask(i, j) = 0;
        end
    end
end

end