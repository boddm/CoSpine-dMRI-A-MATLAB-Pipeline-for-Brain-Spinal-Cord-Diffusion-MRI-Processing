function t1Spinal2Template(t1Spinal, t1SpinalSeg, t1SpinalDisc, t1SpinalDir, sctDir)
% Purpose: Register spinal cord T1 image to PAM50 template space
% Inputs:
%   t1Spinal: Path to spinal cord T1 image file
%   t1SpinalSeg: Path to spinal cord T1 segmentation image file
%   t1SpinalDisc: Path to spinal disc label file
%   t1SpinalDir: Path to spinal cord processing directory
%   sctDir: Path to SCT tools directory
% Outputs:
%   No direct output; generates registration-related files
% Example:
%   t1Spinal2Template(t1Spinal, t1SpinalSeg, t1SpinalDisc, t1SpinalDir, sctDir);
% History:
%   2025-07-01, boddm, Initial version

%% Input parameter check
if nargin < 5
    error('Insufficient input arguments. Please provide all required parameters.');
end

% Check file path parameters
if isempty(t1Spinal) || ~exist(t1Spinal, 'file')
    error('t1Spinal file does not exist or is empty: %s', t1Spinal);
end

if isempty(t1SpinalSeg) || ~exist(t1SpinalSeg, 'file')
    error('t1SpinalSeg file does not exist or is empty: %s', t1SpinalSeg);
end

if isempty(t1SpinalDisc) || ~exist(t1SpinalDisc, 'file')
    error('t1SpinalDisc file does not exist or is empty: %s', t1SpinalDisc);
end

if isempty(t1SpinalDir) || ~exist(t1SpinalDir, 'dir')
    error('spinalDir directory does not exist or is empty: %s', t1SpinalDir);
end

if isempty(sctDir) || ~exist(sctDir, 'dir')
    error('sctDir directory does not exist or is empty: %s', sctDir);
end

%% Register spinal cord to PAM50 template using SCT tools
cmdline = sprintf('sct_register_to_template -i %s -s %s -ldisc %s -c t1 -ofolder %s', t1Spinal, t1SpinalSeg, t1SpinalDisc, t1SpinalDir);
executeCmd(fullfile(sctDir, cmdline), 'Spinal cord registration to PAM50 template');

%% Warp PAM50 template labels to individual space
warpTemplate2Anat = fullfile(t1SpinalDir, 'warp_template2anat.nii.gz');
t1SpinalLabel = fullfile(t1SpinalDir, 'label');

cmdline = sprintf('sct_warp_template -d %s -w %s -ofolder %s', t1Spinal, warpTemplate2Anat, t1SpinalLabel);
executeCmd(fullfile(sctDir, cmdline), 'Warp template labels to individual space');

end