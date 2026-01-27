function t1Preprocess(t1Image, anatDir, antsDir)
% Purpose: T1 image preprocessing including bias-field correction and denoising
% Inputs:
%   t1Image: path to T1 image file
%   anatDir: path to anatomy directory
%   antsDir: path to ANTS tools directory
% Example:
%   t1Preprocess(t1, anatDir, antsDir);
% History:
%   2025-07-01, boddm, Initial version

%% Input parameter validation
if nargin ~= 3
    error('Function requires 3 input arguments: t1Image, anatDir, antsDir');
end

if ~(ischar(t1Image) || isstring(t1Image)) || ~exist(t1Image, 'file')
    error('t1Image must be a string and the file must exist: %s', t1Image);
end

if ~(ischar(anatDir) || isstring(anatDir)) || ~exist(anatDir, 'dir')
    error('anatDir must be a string and the directory must exist: %s', anatDir);
end

if ~(ischar(antsDir) || isstring(antsDir)) || ~exist(antsDir, 'dir')
    error('antsDir must be a string and the directory must exist: %s', antsDir);
end

%% Get T1 image base filename
[~, t1Name, ~] = getFileExtension(t1Image);

%% Step 1: Perform bias-field correction
fprintf('    Step 1: Performing bias-field correction\n');

t1Bias = fullfile(anatDir, [t1Name, '_bias.nii.gz']);

cmdline = sprintf('N4BiasFieldCorrection -d 3 -i %s -o %s', t1Image, t1Bias);
executeCmd(fullfile(antsDir, cmdline), 'T1 bias-field correction');

%% Step 2: Perform image denoising
fprintf('    Step 2: Performing image denoising\n');

t1Denoise = fullfile(anatDir, [t1Name, '_denoise.nii.gz']);

cmdline = sprintf('DenoiseImage -d 3 -i %s -o %s -r 1', t1Bias, t1Denoise);
executeCmd(fullfile(antsDir, cmdline), 'T1 image denoising');

end