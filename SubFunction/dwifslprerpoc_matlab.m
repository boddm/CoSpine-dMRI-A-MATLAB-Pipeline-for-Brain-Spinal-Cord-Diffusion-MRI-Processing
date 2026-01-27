function dwifslprerpoc_matlab(apPa, apPaB0, outputName, mrtrix3Dir, numThreads)
% Purpose: FSL-based DWI preprocessing pipeline including mrconvert, topup, eddy, etc.
% Inputs:
%   apPa: path to DWI data file
%   apPaB0: path to B0 image file
%   outputName: output file name
%   mrtrix3Dir: path to MRtrix3 binaries
%   numThreads: number of threads (default 20)
% Output:
%   none; results written to file
% Example:
%   dwifslprerpoc_matlab('dwi.mif', 'b0.mif', 'output.mif', '/path/to/mrtrix3', 20);
% History:
%   2025-07-01, boddm, Initial version
%   2025-12-25, boddm, optimized version

%% Input parameter checks
if nargin < 4
    error('Insufficient input arguments. Please provide all required parameters.');
end
if nargin < 5 || isempty(numThreads)
    numThreads = 20;
end
assert(exist(apPa, 'file'), 'Input file does not exist or is empty');
assert(exist(apPaB0, 'file'), 'B0 file does not exist or is empty');
assert(exist(mrtrix3Dir, 'dir') == 7, 'MRtrix3 directory does not exist or is empty');
assert(~isempty(outputName) && ~exist(outputName, 'file'), 'Output filename must be non-empty and must not already exist');

%% Prepare output folder and working directory
[inputFolder, ~, ~] = fullfile(apPa);
targetPath = fullfile(inputFolder, 'dwifslpreproc');

if ~exist(targetPath, 'dir')
    mkdir(targetPath);
end

%% Save current directory and switch
originalDir = pwd;
cleanupObj = onCleanup(@() cd(originalDir));
cd(targetPath);

%% Step 1: DWI data conversion
dwiMif = fullfile(targetPath, 'dwi.mif');

cmdline = sprintf('mrconvert %s %s -nthreads %d -force', apPa, dwiMif, numThreads);
executeCmd(fullfile(mrtrix3Dir, cmdline), 'DWI data conversion');

assert(exist(dwiMif, 'file'), 'DWI data conversion failed');

%% Step 2: se_epi data conversion
seEpiMif = fullfile(targetPath, 'se_epi.mif');

cmdline = sprintf('mrconvert %s %s -nthreads %d -force', apPaB0, seEpiMif, numThreads);
executeCmd(fullfile(mrtrix3Dir, cmdline), 'se_epi data conversion');

assert(exist(seEpiMif, 'file'), 'se_epi data conversion failed');

%% Step 3: topup data conversion
topupIn = fullfile(targetPath, 'topup_in.nii.gz');
topupTable = fullfile(targetPath, 'topup_datain.txt');
if ismac
    cmdline = sprintf('mrconvert %s %s -strides -1,+2,+3,+4 -export_pe_topup %s -nthreads %d -force', seEpiMif, topupIn, topupTable, numThreads);
else
    cmdline = sprintf('mrconvert %s %s -strides -1,+2,+3,+4 -export_pe_table %s -nthreads %d -force', seEpiMif, topupIn, topupTable, numThreads);
end

executeCmd(fullfile(mrtrix3Dir, cmdline), 'topup data conversion');

assert(exist(topupIn, 'file') && exist(topupTable, 'file'), 'topup data conversion failed');

%% Step 4: Run Topup correction
topupOut = fullfile(targetPath, 'field');
topupCmd = sprintf('${FSLDIR}/bin/topup --imain=%s --datain=%s --out=%s --fout=%s --iout=%s --config=${FSLDIR}/etc/flirtsch/b02b0_1.cnf --verbose --nthr=%d', ...
    topupIn, topupTable, topupOut, fullfile(targetPath, 'field_map.nii.gz'), fullfile(targetPath, 'field_image.nii.gz'), numThreads);
executeCmd(topupCmd, 'Topup correction');

fieldImage = fullfile(targetPath, 'field_image.nii.gz');
assert(exist(fieldImage, 'file'), 'Topup correction failed');

%% Step 5: Create mask for Eddy correction
eddyMask = fullfile(targetPath, 'eddy_mask.nii.gz');

cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -Tmean %s', fieldImage, eddyMask);
executeCmd(cmdline, 'Mask creation');

assert(exist(eddyMask, 'file'), 'Mask creation failed');

%% Step 6: Prepare data for Eddy correction
eddyIn = fullfile(targetPath, 'eddy_in.nii.gz');
eddyConfig = fullfile(targetPath, 'eddy_config.txt');
eddyIndices = fullfile(targetPath, 'eddy_indices.txt');
bvecsFile = fullfile(targetPath, 'bvecs');
bvalsFile = fullfile(targetPath, 'bvals');

cmdline = sprintf('mrconvert %s %s -strides -1,+2,+3,+4 -export_grad_fsl %s %s -export_pe_eddy %s %s -nthreads %d -force', ...
    dwiMif, eddyIn, bvecsFile, bvalsFile, eddyConfig, eddyIndices, numThreads);
executeCmd(fullfile(mrtrix3Dir, cmdline), 'Eddy correction preparation');

assert(exist(eddyIn, 'file') && exist(eddyConfig, 'file') && exist(eddyIndices, 'file'), 'Eddy correction preparation failed');

%% Step 7: Select appropriate Eddy command (prefer CUDA version)
[status, ~] = executeCmd('which ${FSLDIR}/bin/eddy_cuda11.0', 'Eddy command selection');
if status == 0
    eddyCmd = '${FSLDIR}/bin/eddy_cuda11.0';
else
    eddyCmd = '${FSLDIR}/bin/eddy_cpu';
end

%% Step 8: Run Eddy correction
eddyOut = fullfile(targetPath, 'dwi_post_eddy');
eddyFullCmd = sprintf('%s --imain=%s --mask=%s --acqp=%s --index=%s --bvecs=%s --bvals=%s --topup=%s --fwhm=5 --flm=quadratic --out=%s --cnr_maps -v', ...
    eddyCmd, eddyIn, eddyMask, eddyConfig, eddyIndices, bvecsFile, bvalsFile, topupOut, eddyOut);
executeCmd(eddyFullCmd, 'Eddy correction');

eddyOutNii = fullfile(targetPath, 'dwi_post_eddy.nii.gz');
assert(exist(eddyOutNii, 'file'), 'Eddy correction failed');

%% Step 9: Convert to final output format
eddyBvecs = fullfile(targetPath, 'dwi_post_eddy.eddy_rotated_bvecs');

cmdline = sprintf('mrconvert %s %s -strides -1,+2,+3,+4 -fslgrad %s %s -force', eddyOutNii, outputName, eddyBvecs, bvalsFile);
executeCmd(fullfile(mrtrix3Dir, cmdline), 'Final output conversion');

assert(exist(outputName, 'file'), 'Final output conversion failed');

%% Step 10: Clean up temporary files
tempFiles = {dwiMif, eddyIn};

for i = 1:length(tempFiles)
    delete(tempFiles{i});
end

end