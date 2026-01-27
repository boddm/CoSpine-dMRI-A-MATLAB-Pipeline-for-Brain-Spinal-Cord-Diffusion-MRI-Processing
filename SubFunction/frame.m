function [tangent, normal, binormal] = frame(tract, vec)
% Function: Compute the frame of a fiber tract (tangent, normal, binormal)
% Input:
%   tract: Fiber tract coordinate data
%   vec: Reference vector
% Output:
%   tangent: Tangent vector
%   normal: Normal vector
%   binormal: Binormal vector
% Example:
%   [tangent, normal, binormal] = frame(fiberCoords, [0 0 1]);
% History:
%   2025-07-01, boddm, Initial version

%% Process input data format
N = size(tract, 1);
if N == 3
    % If input is 3xN format, transpose to Nx3 format
    tract = tract';
    N = size(tract, 1);
end

%% Initialize output variables
tangent = zeros(N, 3);   % Tangent vector
normal = zeros(N, 3);    % Normal vector
binormal = zeros(N, 3);  % Binormal vector

p = tract;  % Simplify variable name

%% Compute tangent vectors for intermediate points (using central difference method)
for i = 2:(N-1)
    tangent(i, :) = p(i+1, :) - p(i-1, :);  % Compute tangent vector
    tl = norm(tangent(i, :));  % Compute length of tangent vector

    if tl > 0
        tangent(i, :) = tangent(i, :) / tl;  % Normalize tangent vector
    else
        tangent(i, :) = tangent(i-1, :);  % If length is 0, use previous tangent vector
    end
end

%% Compute tangent vectors for first and last points (using forward and backward difference methods)
tangent(1, :) = p(2, :) - p(1, :);  % Tangent at first point (forward difference)
tangent(1, :) = tangent(1, :) / norm(tangent(1, :));  % Normalize

tangent(N, :) = p(N, :) - p(N-1, :);  % Tangent at last point (backward difference)
tangent(N, :) = tangent(N, :) / norm(tangent(N, :));  % Normalize

%% Compute normal vectors for intermediate points
for i = 2:(N-1)
    normal(i, :) = cross(tangent(i, :), vec);  % Normal vector = tangent vector × reference vector
    nl = norm(normal(i, :));  % Compute length of normal vector

    if nl > 0
        normal(i, :) = normal(i, :) / nl;  % Normalize normal vector
    else
        normal(i, :) = normal(i-1, :);  % If length is 0, use previous normal vector
    end
end

%% Compute normal vectors for first and last points
normal(1, :) = cross(tangent(1, :), vec);  % Normal at first point
normal(1, :) = normal(1, :) / norm(normal(1, :));  % Normalize

normal(N, :) = cross(tangent(N, :), vec);  % Normal at last point
normal(N, :) = normal(N, :) / norm(normal(N, :));  % Normalize

%% Compute binormal vectors (using right-hand rule)
for i = 1:N
    binormal(i, :) = cross(tangent(i, :), normal(i, :));  % Binormal vector = tangent vector × normal vector
    binormal(i, :) = binormal(i, :) / norm(binormal(i, :));  % Normalize binormal vector
end

end