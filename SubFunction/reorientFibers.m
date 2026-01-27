function [coordReoriented, startCoords, endCoords, numFlippedFibers] = reorientFibers(coord, numNodes)
% Purpose: Re-orient DTI fiber tracts to ensure all fibers have consistent direction
% Input:
%   coord: Cell array of fiber tract coordinates, each element is an n×3 matrix
%   numNodes: Number of nodes
% Output:
%   coordReoriented: Re-oriented fiber tract coordinate cell array
%   startCoords: Average starting coordinates
%   endCoords: Average ending coordinates
%   numFlippedFibers: Number of flipped fiber tracts
% Example:
%   [orientedCoord, start, end, flipped] = reorientFibers(coordData, 100);
% History:
%   2025-07-01, boddm, Initial version

%% Check input parameters
if ~exist('coord', 'var') || isempty(coord)
    error('Please provide fiber tract coordinate data')
elseif isempty(coord)
    % Handle empty fiber tract case
    coordReoriented = coord;
    startCoords = [];
    endCoords = [];
    numFlippedFibers = 0;
    return
end

%% Determine reorientation method
if ~exist('numNodes', 'var')
    method = 'cluster_endpoints';
else
    method = 'match_first_fiber';
end

%% Initialize output variables
coordReoriented = coord;

%% Perform fiber tract reorientation based on selected method
switch method
    case 'match_first_fiber'
        %% Resample first fiber tract as reference
        % coord is N×3 format cell array, pass directly to FiberResample
        curve1 = FiberResample(coord{1}, numNodes);
        numFlippedFibers = 0;

        %% Iterate through all fiber tracts for direction matching
        for i = 1:length(coord)
            % Resample current fiber tract
            % coord is a cell array in N×3 format, pass directly to FiberResample
            curve2 = FiberResample(coord{i}, numNodes);

            % Generate flipped fiber tract
            curve2Flipped = flipud(curve2);

            % Calculate distance from reference fiber tract for non-flipped and flipped cases
            % Fiber tract format is N×3, each row is a point coordinate
            noFlipDist = mean(sqrt(sum((curve1 - curve2).^2, 2)));
            flipDist = mean(sqrt(sum((curve1 - curve2Flipped).^2, 2)));

            % Select direction with smaller distance
            if flipDist < noFlipDist
                % FiberResample returns N×3 format, store directly
                coordReoriented{i} = curve2Flipped;
                numFlippedFibers = numFlippedFibers + 1;
            else
                % FiberResample returns N×3 format, store directly
                coordReoriented{i} = curve2;
            end
        end

        %% Calculate average starting and ending coordinates
        startCoords = zeros(1, 3);
        endCoords = zeros(1, 3);

        for fiberID = 1:length(coord)
            % coordReoriented is in N×3 format, first row is starting point, last row is ending point
            startCoords = startCoords + coordReoriented{fiberID}(1, :);
            endCoords = endCoords + coordReoriented{fiberID}(end, :);
        end

        startCoords = startCoords ./ length(coord);
        endCoords = endCoords ./ length(coord);
    case 'cluster_endpoints'
        error('Cluster endpoint reorientation method not implemented yet')
end