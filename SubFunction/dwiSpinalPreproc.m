function [dwiSpinalMean, dwiSpinalSeg, dwiSpinalMask, dwiSpinalCrop] = dwiSpinalPreproc(dwiSpinal, bvecPath, dwiSpinalDir, volumeName, sctDir)
% Function: Preprocess spinal cord DWI data
% Input:
%   dwiSpinal: Spinal cord DWI data file path
%   bvecPath: bvec file path
%   dwiSpinalDir: Spinal cord DWI data directory path
%   volumeName: Volume name
%   sctDir: SCT tool directory path
% Output:
%   dwiSpinalMean: Mean DWI image path
%   dwiSpinalSeg: Spinal cord segmentation result path
%   dwiSpinalMask: Spinal cord mask path
%   dwiSpinalCrop: Cropped DWI data path
% Example:
%   [meanImg, segImg, maskImg, cropImg] = dwiSpinalPreproc(dwiSpinal, bvecPath, dwiSpinalDir, volumeName, sctDir);
% History:
%   2025-07-01, boddm, Initial version

%% Input validation: Check input parameters
if nargin < 5
    error('Incorrect number of input parameters: 5 input parameters required (dwiSpinal, bvecPath, dwiSpinalDir, volumeName, sctDir)');
end

assert(exist(dwiSpinal, 'file'), 'dwiSpinal file does not exist or is empty: %s', dwiSpinal);
assert(exist(dwiSpinalDir, 'dir'), 'dwiSpinalDir directory does not exist or is empty: %s', dwiSpinalDir);
assert(exist(sctDir, 'dir'), 'sctDir directory does not exist or is empty: %s', sctDir);
assert(exist(bvecPath, 'file'), 'bvecPath file does not exist or is empty: %s', bvecPath);
assert(~isempty(volumeName), 'volumeName parameter cannot be empty');

%% Step 1: Separate B0 and DWI data
cmdline = sprintf('sct_dmri_separate_b0_and_dwi -i %s -bvec %s -ofolder %s', dwiSpinal, bvecPath, dwiSpinalDir);
executeCmd(fullfile(sctDir, cmdline), 'Separate B0 and DWI data');

%% Step 2: Perform spinal cord segmentation using propseg algorithm
dwiSpinalMean = fullfile(dwiSpinalDir, [volumeName, '_spinal_dwi_mean.nii.gz']);
dwiSpinalSeg  = fullfile(dwiSpinalDir, [volumeName, '_spinal_dwi_mean_seg.nii.gz']);

propseg(dwiSpinalMean, sctDir, dwiSpinalSeg, 'dwi');

%% Step 3: Create spinal cord mask
dwiSpinalMask = fullfile(dwiSpinalDir, ['mask_', volumeName, '_spinal_dwi_mean.nii.gz']);

cmdline = sprintf('sct_create_mask -i %s -p centerline,%s -size 35mm -o %s', dwiSpinalMean, dwiSpinalSeg, dwiSpinalMask);
executeCmd(fullfile(sctDir, cmdline), 'Create spinal cord mask');

%% Step 4: Crop DWI data
cmdline = sprintf('sct_crop_image -i %s -m %s', dwiSpinal, dwiSpinalMask);
executeCmd(fullfile(sctDir, cmdline), 'Crop DWI data');

%% Step 5: Set cropped DWI data path
dwiSpinalCrop = fullfile(dwiSpinalDir, [volumeName, '_spinal_crop.nii.gz']);

%% Step 6: Perform motion correction on cropped DWI data
cmdline = sprintf('sct_dmri_moco -i %s -bvec %s -param metric=MeanSquares -ofolder %s', dwiSpinalCrop, bvecPath, dwiSpinalDir);
executeCmd(fullfile(sctDir, cmdline), 'Perform motion correction on cropped DWI data');

end