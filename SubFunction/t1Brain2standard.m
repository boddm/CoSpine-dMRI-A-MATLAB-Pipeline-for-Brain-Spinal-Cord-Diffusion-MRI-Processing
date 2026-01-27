function t1Brain2standard(t1BrainMasked, template, t1BrainDir)
% Purpose: Register T1 brain image to standard template space (MNI152)
% Inputs:
%   t1BrainMasked: Path to T1 brain image mask file
%   templateRef: Path to standard template reference image
%   t1BrainDir: Path to brain processing directory
% Example:
%   t1Brain2standard(t1BrainMasked, template, t1BrainDir);
% History:
%   2025-07-01, boddm, Initial version

%% Input validation
if nargin ~= 3
    error('Function requires 3 input arguments');
end

assert(exist(template, 'file'), 'Standard template reference image does not exist');
assert(exist(t1BrainMasked, 'file'), 'T1 brain image mask file does not exist');

if ~exist(t1BrainDir, 'dir')
    mkdir(t1BrainDir);
end

%% Step 1: Rigid registration: generate transformation matrix from individual to standard space
matStr2Std = fullfile(t1BrainDir, 'str2standard.mat');

cmdline = sprintf('${FSLDIR}/bin/flirt -in %s -ref %s -omat %s -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12 -cost corratio', t1BrainMasked, template, matStr2Std);
executeCmd(cmdline, 'Generate rigid transformation matrix');

%% Step 2: Generate inverse transformation matrix from standard to individual space
matStd2Str = fullfile(t1BrainDir, 'standard2str.mat');

cmdline = sprintf('${FSLDIR}/bin/convert_xfm -omat %s -inverse %s', matStd2Str, matStr2Std);
executeCmd(cmdline, 'Generate inverse transformation matrix');

%% Step 3: Nonlinear registration: generate deformation field
warpStr2Std = fullfile(t1BrainDir, 'warp_str2standard');
str2standard = fullfile(t1BrainDir, 'str2standard');

cmdline = sprintf('${FSLDIR}/bin/fnirt --in=%s --aff=%s --cout=%s --iout=%s --config=T1_2_MNI152_2mm', ...
    t1BrainMasked, matStr2Std, warpStr2Std, str2standard);
executeCmd(cmdline, 'Generate nonlinear deformation field');

%% Step 4: Generate inverse deformation field from standard to individual space
warpStd2Str = fullfile(t1BrainDir, 'warp_standard2str');

cmdline = sprintf('${FSLDIR}/bin/invwarp -w %s -o %s -r %s', warpStr2Std, warpStd2Str, t1BrainMasked);
executeCmd(cmdline, 'Generate inverse deformation field');  

disp('T1 to standard template registration completed');
end