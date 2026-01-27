function [preT, preTargetTract, currentT, currentTargetTract] = tabsPointMatch_curves(protract, targetTract)
% Purpose: Match points along fiber-tract curves
% Input:
%   protract: prototype fiber tract
%   targetTract: target fiber tract
% Output:
%   preT: pre-processed t-values
%   preTargetTract: pre-processed target tract
%   currentT: current t-values
%   currentTargetTract: current target tract
% Example:
%   [preT, preTract, currT, currTract] = tabsPointMatch_curves(protract, targetTract);
% History:
%   2025-07-01, boddm, Initial version

%% Check input format
if size(protract, 2) ~= 3 || size(targetTract, 2) ~= 3
    error('Curves must be n x 3 matrices');
end

%% Count points in each tract
numPointsTarget = size(targetTract, 1);
numPointsProtract = size(protract, 1);

%% Build cubic splines for x, y, z separately
ppX = spline(1:numPointsTarget, targetTract(:, 1)');
ppY = spline(1:numPointsTarget, targetTract(:, 2)');
ppZ = spline(1:numPointsTarget, targetTract(:, 3)');

%% Compute frame and tangent vectors for prototype tract
[proTangent, ~, ~] = frame(protract, randn(1, 3));

%% Initialize output arrays
preT = zeros(numPointsProtract, 1);
preTargetTract = zeros(numPointsProtract, 3);

%% Set solver options
options = optimoptions('fsolve', 'Display', 'off');

%% Upsample target curve for higher matching accuracy
tInterp = linspace(1, numPointsTarget, numPointsTarget * 10);
targetCurveInterp = [ppval(ppX, tInterp)', ppval(ppY, tInterp)', ppval(ppZ, tInterp)'];

%% Loop over prototype points to find curve correspondences
for ii = 1:numPointsProtract
    % Get current point and tangent
    p = protract(ii, :);
    t = proTangent(ii, :);

    % Find closest point on upsampled target curve
    idx = knnsearch(targetCurveInterp, p);
    t0 = tInterp(idx);

    % Define objective: dot product of (curve-point) and tangent
    fun = @(tVal) (ppval(ppX, tVal) - p(1)) * t(1) + (ppval(ppY, tVal) - p(2)) * t(2) + (ppval(ppZ, tVal) - p(3)) * t(3);

    % Solve for optimal t
    [tSol, ~, exitFlag] = fsolve(fun, t0, options);

    % Store result if valid
    if exitFlag > 0 && tSol >= 1 && tSol <= numPointsTarget
        preT(ii) = tSol;
        preTargetTract(ii, :) = [ppval(ppX, tSol); ppval(ppY, tSol); ppval(ppZ, tSol)]';
    end
end

%% Handle discontinuities in t-parameter
errorNode = tabsFindDisconTRanges(preT);

if isempty(errorNode)
    % No discontinuities: use pre-processed t directly
    currentT = preT;
else
    % Fill gaps via spline interpolation
    currentT = tabsFillDisconTSpline(preT, errorNode);
end

%% Generate final target tract
currentTargetTract = zeros(numPointsProtract, 3);

for ii = 1:numPointsProtract
    if currentT(ii) ~= 0
        currentTargetTract(ii, :) = [ppval(ppX, currentT(ii)); ppval(ppY, currentT(ii)); ppval(ppZ, currentT(ii))]';
    end
end

end