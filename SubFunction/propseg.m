function propseg(inputDir, sctDir, outputDir, type)
% Function: Perform spinal cord segmentation using SCT propseg
% Inputs:
%   inputDir  : path to input image
%   sctDir    : path to SCT toolbox directory
%   outputDir : path for segmentation output
%   type      : image modality type
% Outputs:
%   None (results written to file)
% Example:
%   propseg(inputImage, sctDir, outputSeg, 'dwi');
% History:
%   2025-07-01, boddm, Initial version

%% Handle output directory
[outputPath, ~, ~] = fileparts(outputDir);
if isempty(outputPath)
    outputPath = '.';  % use current directory if empty
end

%% Step 1: Run first propseg (parameter -d=25)
segFile1 = fullfile(outputPath, 'spinal_seg_1.nii.gz');

cmdline = sprintf('sct_propseg -i %s -c %s -nbiter %d -min-contrast %d -d %d -distance-search %d -o %s', inputDir, type, 1000, 15, 25, 50, segFile1);
executeCmd(fullfile(sctDir, cmdline), 'First propseg segmentation');

%% Step 2: Run second propseg (parameter -d=10)
segFile2 = fullfile(outputPath, 'spinal_seg_2.nii.gz');

cmdline = sprintf('sct_propseg -i %s -c %s -nbiter %d -min-contrast %d -d %d -distance-search %d -o %s', inputDir, type, 1000, 15, 10, 50, segFile2);
executeCmd(fullfile(sctDir, cmdline), 'Second propseg segmentation');

%% Step 3: Merge two segmentations and binarize
cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -add %s -div 2 -bin %s', segFile1, segFile2, outputDir);
executeCmd(cmdline, 'Merge segmentations and binarize');

%% Step 4: Clean temporary files
delete(segFile1);  % delete first intermediate segmentation
delete(segFile2);  % delete second intermediate segmentation
delete(fullfile(outputPath, '*_centerline.nii.gz'));  % delete generated centerline files

end