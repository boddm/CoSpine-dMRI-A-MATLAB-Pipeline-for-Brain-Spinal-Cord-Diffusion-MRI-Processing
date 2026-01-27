function [seedLabel, roi1, roi2] = generateSpinalSeed(spinalSeed, labelValue, dwiDir, dwiTckDir, volumeName, roiPrefix)
% Function: Generate spinal seed region ROIs
% Input:
%   seedSpinalFile: Spinal seed file path
%   labelValue: Label value
%   dwiDir: DWI directory path
%   dwiTckDir: Tractography directory path
%   volumeName: Volume name
%   roiPrefix: ROI prefix
% Output:
%   seedLabelFile: Seed label file path
%   roi1File: ROI1 file path
%   roi2File: ROI2 file path
% Example:
%   [seedLabel, roi1, roi2] = generateSpinalSeed(seedSpinal, 6, dwiDir, dwiTckDir, 'vol1', 'C6');
% History:
%   2025-07-01, boddm, Initial version

%% Step 1: Set output file paths
seedLabel = fullfile(dwiTckDir, ['Seed_spinal_' roiPrefix '.nii.gz']);
dwiSpinalSeg  = fullfile(dwiDir, 'spinal', [volumeName, '_spinal_dwi_mean_seg.nii.gz']);
seedSpinalThrFile = fullfile(dwiDir, 'Seed_spinal_thr.nii.gz'); 
roi1 = fullfile(dwiTckDir, ['Seed_spinal_' roiPrefix '_thr2.nii.gz']);
roi2 = fullfile(dwiTckDir, ['Seed_spinal_' roiPrefix '_thr1.nii.gz']);

%% Step 2: Generate spinal seed label file
cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -thr %d -uthr %d -bin %s', spinalSeed, labelValue, labelValue, seedLabel);
executeCmd(cmdline, 'Generate C6/C1 spinal seed label');

%% Step 3: Get spinal seed label bounding-box information
cmdline = sprintf('${FSLDIR}/bin/fslstats %s -w', seedLabel);
[~, cmdOut] = executeCmd(cmdline, 'Get spinal seed label bounding-box info');
stats = strsplit(strtrim(cmdOut), ' ');

if numel(stats) < 6
    error('fslstats output abnormal');
end

%% Step 4: Generate intermediate ROI file
cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -roi 0 -1 0 -1 %s 1 0 1 %s', dwiSpinalSeg, stats{5}, seedSpinalThrFile);
executeCmd(cmdline, 'Generate intermediate ROI file');

%% Step 5: Get intermediate ROI bounding-box information
cmdline = sprintf('${FSLDIR}/bin/fslstats %s -w', seedSpinalThrFile);
[~, cmdOut] = executeCmd(cmdline, 'Get intermediate ROI bounding-box info');
stats = strsplit(strtrim(cmdOut), ' ');

if numel(stats) < 6
    error('Intermediate ROI fslstats output abnormal');
end

%% Step 6: Calculate segmentation indices   
startIdx = str2double(stats{1});
len = floor(str2double(stats{2})/2);

if isnan(startIdx) || isnan(len)
    error('Segmentation index calculation error');
end

%% Step 7: Split intermediate ROI into two parts based on length parity 
if mod(str2double(stats{2}), 2) == 1
    % Odd length case
    cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -roi %d %d 0 -1 0 -1 0 -1 %s', seedSpinalThrFile, startIdx, len, roi1);
    executeCmd(cmdline, 'Generate ROI1 file');
    
    cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -roi %d %d 0 -1 0 -1 0 -1 %s', seedSpinalThrFile, startIdx+len+1, len, roi2);
    executeCmd(cmdline, 'Generate ROI2 file');
else
    % Even length case
    cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -roi %d %d 0 -1 0 -1 0 -1 %s', seedSpinalThrFile, startIdx, len, roi1);
    executeCmd(cmdline, 'Generate ROI1 file');
    
    cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -roi %d %d 0 -1 0 -1 0 -1 %s', seedSpinalThrFile, startIdx+len, len, roi2);
    executeCmd(cmdline, 'Generate ROI2 file');
end
end