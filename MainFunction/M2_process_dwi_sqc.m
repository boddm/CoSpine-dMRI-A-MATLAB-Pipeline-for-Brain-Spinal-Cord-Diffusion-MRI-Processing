% Purpose: Generate quality report for DWI data
% Input: 
%   Path to data directory
% Output: 
%   Excel file with quality metrics
% Example: 
%   M2_process_dwi_sqc; % Generate DWI quality report
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/media/xd/脑影像/IBS_baseline/DATA_EDC/DATA';
outputFile = fullfile(dataDir, 'DWI_Quality_Report.xlsx');

%% Validate input path  
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);

%% Initialize quality control data structure
fprintf('Starting DWI quality control report generation\n\n');

qcData = {};
header = {'SubjectID', 'VolumeID', 'CNR_Avg1', 'CNR_Avg2', 'CNR_Std1', 'CNR_Std2', 'Motion_Abs', 'Motion_Rel', 'Outliers_B', 'Outliers_PE', 'Outliers_Total'};

for i = 1:length(header)
    qcData{1, i} = header{i};
end

%% Get subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting DWI quality control report generation, found %d subjects\n', numSubjects);

%% Loop through all subjects and volumes
rowIdx = 2;
for subjIdx = 1:numSubjects
    subjectPath = subjectPaths(subjIdx);
    volumePaths = systemdir(fullfile(subjectPath.folder, subjectPath.name));
    numVolumes = length(volumePaths);

    fprintf('[%d/%d] Processing subject: %s\n', subjIdx, numSubjects, subjectPath.name);

    %% Process each volume
    for volIdx = 1:numVolumes
        volumePath = volumePaths(volIdx);

        fprintf('  [%d/%d] Processing volume: %s\n', volIdx, numVolumes, volumePath.name);
        
        %% Set directory paths
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        dwiPreprocDir = fullfile(dwiDir, 'dwifslpreproc');
        dwiTckDir = fullfile(dwiDir, 'tractography');
        
        if ~isfolder(dwiTckDir) || ~isfolder(dwiPreprocDir)
            fprintf('  Warning: DWI tractography or preprocessing directory does not exist, skipping volume %d\n', volIdx);
            continue;
        end

        %% Locate quality control JSON file
        qcJsonFile = fullfile(dwiPreprocDir, 'dwi_post_eddy.qc', 'qc.json');

        if ~isfile(qcJsonFile)
            fprintf('  Warning: Quality control JSON file does not exist, skipping volume %d\n', volIdx);
            continue;
        end

        %% Read quality control JSON file
        fprintf('    Reading quality control data...\n');
        qcInfo = jsondecode(fileread(qcJsonFile));

        %% Check required fields and extract data
        hasAllFields = isfield(qcInfo, 'qc_cnr_avg') && ...
                       isfield(qcInfo, 'qc_cnr_std') && ...
                       isfield(qcInfo, 'qc_mot_abs') && ...
                       isfield(qcInfo, 'qc_mot_rel') && ...
                       isfield(qcInfo, 'qc_outliers_b') && ...
                       isfield(qcInfo, 'qc_outliers_pe') && ...
                       isfield(qcInfo, 'qc_outliers_tot');

        if ~hasAllFields
            fprintf('    Warning: Quality control data missing required fields, skipping\n');
            continue;
        end

        %% Extract and store quality control data
        qcData{rowIdx, 1} = subjectPath.name;
        qcData{rowIdx, 2} = volumePath.name;
        qcData{rowIdx, 3} = qcInfo.qc_cnr_avg(1);
        qcData{rowIdx, 4} = qcInfo.qc_cnr_avg(2);
        qcData{rowIdx, 5} = qcInfo.qc_cnr_std(1);
        qcData{rowIdx, 6} = qcInfo.qc_cnr_std(2);
        qcData{rowIdx, 7} = qcInfo.qc_mot_abs;
        qcData{rowIdx, 8} = qcInfo.qc_mot_rel;
        qcData{rowIdx, 9} = qcInfo.qc_outliers_b;
        qcData{rowIdx, 10} = qcInfo.qc_outliers_pe;
        qcData{rowIdx, 11} = qcInfo.qc_outliers_tot;

        rowIdx = rowIdx + 1;

        fprintf('    Successfully extracted quality control data\n');
    end
end

%% Write quality control data to Excel file
if rowIdx > 2
    fprintf('\nGenerating quality control report...\n');

    tableHeader = qcData(1, :);
    tableData = qcData(2:rowIdx-1, :);

    qcTable = cell2table(tableData, 'VariableNames', tableHeader);

    writetable(qcTable, outputFile);
    fprintf('Quality control report saved to: %s\n', outputFile);
else
    fprintf('Warning: No valid quality control data found, report not generated\n');
end

fprintf('\nDWI quality control report generation completed\n');