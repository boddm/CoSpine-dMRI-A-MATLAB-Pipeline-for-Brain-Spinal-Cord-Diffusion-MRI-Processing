function disconRanges = tabsFindDisconTRanges(t)
% Purpose: Find discontinuous segments in t-values
% Input:
%   t: array of t-values
% Output:
%   disconRanges: matrix of discontinuous segment ranges
% Example:
%   disconRanges = tabsFindDisconTRanges(tValues);
% History:  
%   2025-07-01, boddm, Initial version

%% Initialize output variable
disconRanges = [];

%% Check input array length, return if less than or equal to 1
n = length(t);
if n <= 1
    return;
end

%% Find indices of all non-zero t-values
validIndices = find(t ~= 0);
numValid = length(validIndices);

%% Return if number of non-zero values is less than or equal to 1
if numValid <= 1
    return;
end

%% Traverse non-zero t-values to locate discontinuous segments
startIdx = 0;  % Initialize start index of discontinuous segment

for ii = 2:numValid
    % Get indices of current and previous non-zero values
    currentIdx = validIndices(ii);
    prevIdx = validIndices(ii-1);

    if startIdx == 0
        % Look for start of discontinuous segment
        % If current t-value is less than previous one, a segment starts here
        if t(currentIdx) < t(prevIdx)
            startIdx = currentIdx;
        end
    else
        % Look for end of discontinuous segment
        % If current t-value is greater than previous one, the segment ends
        if t(currentIdx) > t(prevIdx)
            % Record the discontinuous segment
            disconRanges = [disconRanges; startIdx, currentIdx-1];
            startIdx = 0;  % Reset start index for next segment
        end
    end
end

%% Handle last discontinuous segment (if any)
if startIdx ~= 0
    disconRanges = [disconRanges; startIdx, validIndices(end)];
end

end