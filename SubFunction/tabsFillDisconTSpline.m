function filledT = tabsFillDisconTSpline(tValues, disconRanges)
% Purpose: Fill discontinuous t-values using spline interpolation
% Inputs:
%   tValues: original array of t-values
%   disconRanges: ranges of discontinuous regions
% Output:
%   filledT: array of t-values after filling
% Example:
%   filledT = tabsFillDisconTSpline(tValues, disconRanges);
% History:
%   2025-07-01, boddm, Initial version

%% Initialize output variable
filledT = tValues;

%% Compute the length of the original t-values array
n = length(tValues);

%% Check if discontinuous ranges are empty, return directly if so
if isempty(disconRanges)
    return;
end

%% Traverse all discontinuous regions, perform spline interpolation filling
for jj = 1:size(disconRanges, 1)
    % Get the start and end indices of the current discontinuous region
    startIdx = disconRanges(jj, 1);
    endIdx = disconRanges(jj, 2);

    % Ensure reference points are within valid range
    startValueIdx = max(1, startIdx - 1);
    endValueIdx = min(n, endIdx + 1);

    % Get reference t-values
    startValue = filledT(startValueIdx);
    endValue = filledT(endValueIdx);

    % Prepare interpolation data points
    x = [startValueIdx, endValueIdx]'; % indices of reference points
    v = [startValue, endValue]'; % t-values of reference points for interpolation

    % Compute the number of points to insert
    numPointsToInsert = endIdx - startIdx + 1;

    %% Execute spline interpolation and fill discontinuous region
    if numPointsToInsert > 0
        % Generate indices for interpolation points
        xq = linspace(startIdx, endIdx, numPointsToInsert + 2)';

        % Execute spline interpolation
        vq = interp1(x, v, xq, 'spline');

        % Extract interpolation results (excluding reference points at ends)
        vq = vq(2:end-1);

        % Fill interpolated values into the original array
        filledT(startIdx:endIdx) = vq;
    end
end

end