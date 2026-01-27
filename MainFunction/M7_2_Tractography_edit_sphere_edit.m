% Function: Fine cropping of fiber tracts using spherical ROIs based on spinal segment labels
% Input: 
%   data directory path, SCT tools path, MRtrix3 tools path
% Output: 
%   cropped fiber tract files (.tck format)
% Example: 
%   M7_2_Tractography_edit_sphere_edit; % Execute spherical ROI cropping
% History: 
%   2025-07-01, boddm, Initial version
clc, clear;

%% Initialize parameters
dataDir = '/Volumes/BODDM3/IBS-北京/nii/IBS合并_预处理';
sctDir = '/Users/boddm/sct_7.0/bin';
mrtrix3Dir = '/usr/local/bin';
tckPattern = '*tha2C6*crop.tck';
labelList = {'PAM50_atlas_12.nii.gz', 'PAM50_atlas_13.nii.gz'};
sphereRadius = 5;

%% Validate input paths
assert(exist(dataDir, 'dir') == 7, 'Data directory does not exist: %s', dataDir);
assert(exist(sctDir, 'dir') == 7, 'SCT tools directory does not exist: %s', sctDir);
assert(exist(mrtrix3Dir, 'dir') == 7, 'MRtrix3 tools directory does not exist: %s', mrtrix3Dir);

%% Retrieve subject list
subjectPaths = systemdir(dataDir);
numSubjects = length(subjectPaths);

if numSubjects == 0
    error('No subjects found in directory: %s', dataDir);
end

fprintf('Starting fiber tract sphere cropping, %d subjects found\n\n', numSubjects);

%% Loop through all subjects and volumes
for subjIdx = 1:numSubjects
    subjectPath = subjectPaths(subjIdx);
    volumePaths = systemdir(fullfile(subjectPath.folder, subjectPath.name));
    numVolumes = length(volumePaths);
    
    fprintf('[%d/%d] Processing subject: %s (%d volumes)\n', subjIdx, numSubjects, subjectPath.name, numVolumes);
    
    %% Process each volume
    for volIdx = 1:numVolumes
        volumePath = volumePaths(volIdx);
        
        fprintf('  Processing volume %d: %s\n', volIdx, volumePath.name);
        
        %% Set directory paths
        anatDir = fullfile(volumePath.folder, volumePath.name, 'ANAT');
        dwiDir = fullfile(volumePath.folder, volumePath.name, 'DWI');
        dwiSpinalDir = fullfile(dwiDir, 'spinal');
        dwiTckDir = fullfile(dwiDir, 'tractography');
        
        if ~isfolder(anatDir) || ~isfolder(dwiDir) || ~isfolder(dwiSpinalDir) || ~isfolder(dwiTckDir)
            fprintf('  Warning: Required directories do not exist, skipping volume %d\n', volIdx);
            continue;
        end
        
        %% Find DWI spinal registration files
        dwiSpinalMocoFiles = systemdir(fullfile(dwiSpinalDir, '*moco_dwi_mean.nii.gz'));
        warpT12Dti = fullfile(dwiSpinalDir, 'warp_T12dmri.nii.gz');
        
        if isempty(dwiSpinalMocoFiles) || ~isfile(warpT12Dti)
            fprintf('  Warning: Incomplete DWI spinal cord files, skipping volume %d\n', volIdx);
            continue;
        end
        
        dwiSpinalMoco = fullfile(dwiSpinalDir, dwiSpinalMocoFiles(1).name);
        
        %% Find fiber tract files
        dwiTckCrops = systemdir(fullfile(dwiTckDir, tckPattern));
        numTckCrops = length(dwiTckCrops);
        
        if numTckCrops == 0
            fprintf('  Warning: No fiber tract files found, skipping volume %d\n', volIdx);
            continue;
        end
        
        fprintf('    Found %d fiber tract files, starting spherical cropping\n', numTckCrops);
        
        %% Loop through all fiber-tract files for spherical cropping
        for tckIdx = 1:numTckCrops
            if tckIdx > length(labelList)
                fprintf('    Warning: Fiber-tract index exceeds label-list range, skipping\n');
                continue;
            end
            
            currentLabel = labelList{tckIdx};
            
            labelFile = fullfile(anatDir, 'spinal', 'label', 'atlas', currentLabel);
            labelOut = fullfile(dwiTckDir, currentLabel);
            
            if ~isfile(labelFile)
                fprintf('    Warning: Label file does not exist: %s, skipping\n', labelFile);
                continue;
            end
            
            %% Step 1: Transform label from T1 space to DWI space
            cmdline = fullfile(sctDir, sprintf('sct_apply_transfo -i %s -d %s -w %s -o %s -x linear', ...
                labelFile, dwiSpinalMoco, warpT12Dti, labelOut));
            executeCmd(cmdline, 'Transform label from T1 space to DWI space');
            
            cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -bin %s', labelOut, labelOut);
            executeCmd(cmdline, 'Binarize label');
            
            fiberMask = fullfile(dwiTckDir, sprintf('%s_mask_spinal_fiber_mask%d.nii.gz', volumePath.name, tckIdx));
            if ~isfile(fiberMask)
                fprintf('    Warning: Fiber-tract mask does not exist, skipping fiber tract %d\n', tckIdx);
                continue;
            end
            
            %% Step 2: Get fiber-tract mask bounding box
            cmdline = sprintf('${FSLDIR}/bin/fslstats %s -w', fiberMask);
            [~, cmdout] = executeCmd(cmdline, 'Get fiber-tract mask bounding box');
            imageDims = sscanf(cmdout, '%d');
            if length(imageDims) < 6
                fprintf('    警告: 纤维束掩码边界框信息不完整，跳过纤维束 %d\n', tckIdx);
                continue;
            end
            
            %% Step 3: Get label file bounding box            
            cmdline = sprintf('${FSLDIR}/bin/fslstats %s -w', labelOut);
            [~, cmdout] = executeCmd(cmdline, 'Get label file bounding box');
            tmpDims = sscanf(cmdout, '%d');
            
            if length(tmpDims) < 6
                fprintf('    Warning: Label file bounding box information is incomplete, skipping fiber tract %d\n', tckIdx);
                continue;
            end
            
            imageDims(6) = tmpDims(6) - imageDims(5);
            
            dwiTckCropFile = dwiTckCrops(tckIdx);
            dwiTckCrop = fullfile(dwiTckCropFile.folder, dwiTckCropFile.name);
            dwiTckEdit = fullfile(dwiTckDir, sprintf('%s_tha2C6%d_edit.tck', volumePath.name, tckIdx));
            
            if ~isfile(dwiTckCrop)
                fprintf('    警告: 纤维束文件不存在，跳过\n');
                continue;
            end
            
            copyfile(dwiTckCrop, dwiTckEdit);
            
            %% Step 4: Calculate slice points
            upperLimit = imageDims(5) + imageDims(6) - 2;
            lowerLimit = imageDims(5) + 1;
            rangeSize = upperLimit - lowerLimit + 1;
            numDivisions = 3;
            
            slicePoints = zeros(1, numDivisions + 1);
            for i = 0:numDivisions-1
                point = upperLimit - i * (rangeSize / numDivisions);
                slicePoints(i+1) = round(point);
            end
            slicePoints(end) = lowerLimit;
            
            fprintf('    处理纤维束 %d，生成 %d 个切片点\n', tckIdx, numDivisions);
            
            %% Step 5: Generate sphere ROIs at each slice position and crop fiber tracts
            for sliceIdx = slicePoints(1:numDivisions)
                roiFile = fullfile(dwiTckDir, sprintf('sphere_label%d_slice%03d.nii.gz', tckIdx, sliceIdx));
                
                %% Step 5.1: Extract current slice
                tempLayer = fullfile(dwiTckDir, sprintf('temp_layer%d.nii.gz', sliceIdx));
                
                cmdline = sprintf('${FSLDIR}/bin/fslroi %s %s 0 -1 0 -1 %d 1', labelOut, tempLayer, sliceIdx);
                executeCmd(cmdline, 'Extract current slice');
                
                cmdline = sprintf('${FSLDIR}/bin/fslstats %s -C', tempLayer);
                [~, cmdout] = executeCmd(cmdline, 'Calculate centroid of current slice');
                coords = sscanf(cmdout, '%f');
                
                delete(tempLayer);
                
                if numel(coords) ~= 3
                    fprintf('      Warning: Invalid centroid coordinates for slice %d, skipping\n', sliceIdx);
                    continue;
                end
                
                %% Step 5.2: Generate single point at centroid position
                cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -mul 0 -add 1 -roi %.0f 1 %.0f 1 %d 1 0 1 %s', labelOut, coords(1), coords(2), sliceIdx, roiFile);
                [status, ~] = executeCmd(cmdline, 'Generate single point at centroid position');
                
                if status == 0
                    cmdline = sprintf('${FSLDIR}/bin/fslmaths %s -kernel sphere %d -dilM -bin %s', ...
                        roiFile, sphereRadius, roiFile);
                    executeCmd(cmdline, 'Use sphere kernel to generate sphere ROI');
                    
                    cmdline = sprintf('tckedit %s -include %s %s -force', ...
                        dwiTckEdit, roiFile, dwiTckEdit);
                    executeCmd(fullfile(mrtrix3Dir, cmdline), 'Crop fiber tracts using sphere ROI');
                end
                
                if isfile(roiFile)
                    delete(roiFile);
                end
            end
        end
    end
end

fprintf('\n纤维束球体裁剪处理完成\n');