function dwiBrain2standard(dwiBrainMasked, dwiBrainMask, t1BrainMasked, dwiBrainDir, t1BrainDir, template)
% Purpose: Register DWI brain data to standard space
% Inputs:
%   dwiBrainMasked: path to skull-stripped DWI brain image
%   dwiBrainMask: path to DWI brain mask
%   t1BrainMasked: path to skull-stripped T1 brain image
%   dwiBrainDir: DWI processing directory
%   t1BrainDir: T1 processing directory
%   template: path to standard-space template
% Outputs:
%   None (generates registration-related files)
% Example:
%   dwiBrain2standard(dwiBrainMasked, dwiBrainMask, t1BrainMasked, dwiBrainDir, t1BrainDir, template);
% History: 
%   2025-07-01, boddm, Initial version

%% Input parameter check
if nargin < 6
    error('Incorrect number of inputs: 6 arguments required (dwiBrainMasked, dwiBrainMask, t1BrainMasked, dwiBrainDir, t1BrainDir, template)');
end

% Validate file/directory paths
assert(isistemplate(dwiBrainMasked, 'file'), 'dwiBrainMasked file does not exist or is empty');
assert(isistemplate(dwiBrainMask, 'file'), 'dwiBrainMask file does not exist or is empty');
assert(isistemplate(t1BrainMasked, 'file'), 't1BrainMasked file does not exist or is empty');
assert(isistemplate(dwiBrainDir, 'dir'), 'dwiBrainDir directory does not exist or is empty');
assert(isistemplate(t1BrainDir, 'dir'), 't1BrainDir directory does not exist or is empty');
assert(isistemplate(template, 'file'), 'template file does not exist or is empty');

%% Step 1: Rigid registration – generate transformation matrix from DWI to T1
matDiff2Str = fullfile(dwiBrainDir, 'diff2str.mat');
cmdline = sprintf('${FSLDIR}/bin/flirt -in %s -ref %s -omat %s -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 6 -cost corratio', dwiBrainMasked, t1BrainMasked, matDiff2Str);
executeCmd(cmdline, 'Rigid registration – generate transformation matrix from DWI to T1');

%% Step 2: Rigid registration – generate inverse transformation matrix from T1 to DWI
matStr2Diff = fullfile(dwiBrainDir, 'str2diff.mat');
cmdline = sprintf('${FSLDIR}/bin/convert_xfm -omat %s -inverse %s', matStr2Diff, matDiff2Str);
executeCmd(cmdline, 'Rigid registration – generate inverse transformation matrix from T1 to DWI');

%% Step 3: Concatenate transformation matrices: DWI to T1, T1 to standard space
matStr2Std = fullfile(t1BrainDir, 'str2standard.mat');
matDiff2Std = fullfile(dwiBrainDir, 'diff2standard.mat');
cmdline = sprintf('${FSLDIR}/bin/convert_xfm -omat %s -concat %s %s', matDiff2Std, matStr2Std, matDiff2Str);
executeCmd(cmdline, 'Concatenate transformation matrices: DWI to T1, T1 to standard space');

%% Step 4: Generate inverse transformation matrix from standard space to DWI
matStd2Diff = fullfile(dwiBrainDir, 'standard2diff.mat');
cmdline = sprintf('${FSLDIR}/bin/convert_xfm -omat %s -inverse %s', matStd2Diff, matDiff2Std);
executeCmd(cmdline, 'Generate inverse transformation matrix from standard space to DWI');

%% Step 5: Convert nonlinear warp field: transform T1-to-standard warp to DWI-to-standard warp
warpStr2Std = fullfile(t1BrainDir, systemdir(fullfile(t1BrainDir, 'warp_str2standard*')).name);
warpDiff2Std = fullfile(dwiBrainDir, 'warp_diff2standard');
cmdline = sprintf('${FSLDIR}/bin/convertwarp -o %s -r %s -m %s -w %s', warpDiff2Std, template, matDiff2Str, warpStr2Std);
executeCmd(cmdline, 'Transform T1-to-standard warp to DWI-to-standard warp');

%% Step 6: Convert nonlinear warp field: transform standard-to-T1 warp to standard-to-DWI warp
matStr2Diff = fullfile(dwiBrainDir, 'str2diff.mat');
warpStd2Str = fullfile(t1BrainDir, systemdir(fullfile(t1BrainDir, 'warp_standard2str*')).name);
warpStd2Diff = fullfile(dwiBrainDir, 'warp_standard2diff');
cmdline = sprintf('${FSLDIR}/bin/convertwarp -o %s -r %s -w %s --postmat=%s', warpStd2Diff, dwiBrainMask, warpStd2Str, matStr2Diff);
executeCmd(cmdline, 'Transform standard-to-T1 warp to standard-to-DWI warp');

end