function [warpDmri2T1, warpT12Dmri] = dwiSpinal2t1(t1Spinal, t1SpinalSeg, dwiSpinalMoco, dwiSpinalSeg, dwiSpinalDir, sctDir)
% Purpose: Register DWI spinal cord to T1 spinal cord using SCT
% Inputs:
%   t1Spinal: Path to T1 spinal cord image
%   t1SpinalSeg: Path to T1 spinal cord segmentation image
%   dwiSpinalMoco: Path to motion-corrected DWI spinal cord image
%   dwiSpinalSeg: Path to DWI spinal cord segmentation image
%   dwiSpinalDir: DWI spinal cord processing directory
%   sctDir: Path to SCT tools directory
% Outputs:
%   warpDmri2T1: File path to DWI-to-T1 deformation field
%   warpT12Dmri: File path to T1-to-DWI deformation field
% Example:
%   [warpDmri2T1, warpT12Dmri] = dwiSpinal2t1(t1Spinal, t1SpinalSeg, dwiSpinalMoco, dwiSpinalSeg, dwiSpinalDir, sctDir);
% History:
%   2025-07-01, boddm, Initial version

%% Validate input parameters
if isempty(t1Spinal) || ~exist(t1Spinal, 'file')
    error('t1Spinal file does not exist or is empty: %s', t1Spinal);
end

if isempty(t1SpinalSeg) || ~exist(t1SpinalSeg, 'file')
    error('t1SpinalSeg file does not exist or is empty: %s', t1SpinalSeg);
end

if isempty(dwiSpinalMoco) || ~exist(dwiSpinalMoco, 'file')
    error('dwiSpinalMoco file does not exist or is empty: %s', dwiSpinalMoco);
end

if isempty(dwiSpinalSeg) || ~exist(dwiSpinalSeg, 'file')
    error('dwiSpinalSeg file does not exist or is empty: %s', dwiSpinalSeg);
end

if isempty(dwiSpinalDir) || ~exist(dwiSpinalDir, 'dir')
    error('dwiSpinalDir directory does not exist or is empty: %s', dwiSpinalDir);
end

if isempty(sctDir) || ~exist(sctDir, 'dir')
    error('sctDir directory does not exist or is empty: %s', sctDir);
end

%% Step 1: Register DWI spinal cord to T1 spinal cord using SCT
fprintf('    Step 1: Register DWI spinal cord to T1 spinal cord using SCT\n');

cmd = sprintf('sct_register_multimodal -i %s -iseg %s -d %s -dseg %s -ofolder %s -param step=1,type=seg,algo=slicereg:step=2,type=seg,algo=centermass,slicewise=1,iter=3', ...
    t1Spinal, t1SpinalSeg, dwiSpinalMoco, dwiSpinalSeg, dwiSpinalDir);
executeCmd(fullfile(sctDir, cmd), '使用SCT进行DWI到T1的脊髓配准');

%% Step 2: Rename registration-generated transformation files
fprintf('    Step 2: Rename registration-generated transformation files\n');

% Output deformation field file paths
warpDmri2T1 = fullfile(dwiSpinalDir, 'warp_dmri2T1.nii.gz');
warpT12Dmri = fullfile(dwiSpinalDir, 'warp_T12dmri.nii.gz');

% Find and rename DWI-to-T1 deformation field file
warpFiles1 = dir(fullfile(dwiSpinalDir, 'warp*2*T1*.*'));
if ~isempty(warpFiles1)
    oldWarpFile1 = fullfile(warpFiles1(1).folder, warpFiles1(1).name);
    movefile(oldWarpFile1, warpDmri2T1);
end

% Find and rename T1-to-DWI deformation field file
warpFiles2 = dir(fullfile(dwiSpinalDir, 'warp*T1*2*dwi*'));
if ~isempty(warpFiles2)
    oldWarpFile2 = fullfile(warpFiles2(1).folder, warpFiles2(1).name);
    movefile(oldWarpFile2, warpT12Dmri);
end

end