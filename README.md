# CoSpine-dMRI: A MATLAB Pipeline for Brain–Spinal Cord Diffusion MRI Processing

This repository contains the MATLAB source code used in the manuscript  
**“Spinothalamic Tract Microstructure as a Common Neural Substrate of Pain Sensitivity Across Modalities.”**  
It provides a reproducible pipeline for preprocessing, registration, DTI fitting, and tractography across the brain–spinal cord axis.

---

## 1. System Requirements

### Operating Systems
- Ubuntu 20.04 / 22.04 / 24.04
- macOS 10.14+

### Software Dependencies
| Software | Minimum | Recommended | Tested |
|---------|---------|-------------|--------|
| MATLAB | R2023a | R2024a+ | R2024b |
| MRtrix3 | 3.0.4 | 3.0.4+ | 3.0.4 |
| FSL | 6.0.0 | 6.0.6+ | 6.0.6 |
| ANTs | 2.3.0 | 2.4.0+ | 2.4.3 |
| Spinal Cord Toolbox | 6.0.0 | 7.0.0+ | 7.0.0 |

### MATLAB Toolboxes
- Image Processing Toolbox  
- Signal Processing Toolbox  
- Statistics and Machine Learning Toolbox (optional)

### Hardware Requirements
- **Minimum:** 8‑core CPU, 16 GB RAM, 100 GB SSD  
- **Recommended:** 16‑core CPU, 32 GB RAM, NVMe SSD  
- GPU not required

---

## 2. Installation Guide

### Step 1 — Install MATLAB
Install MATLAB and required toolboxes following MathWorks instructions.  
Typical installation time: **30–60 minutes**.

### Step 2 — Install External Neuroimaging Tools
Install FSL, MRtrix3, ANTs, and SCT following their official documentation.  
Typical installation time: **1–2 hours**.

### Step 3 — Clone the Repository
```bash
git clone https://github.com/yourusername/CoSpine-dMRI.git
cd CoSpine-dMRI
```

### Step 4 — Configure Environment Variables
Add the following to your shell profile (e.g., `~/.bashrc`, `~/.zshrc`):
```bash
export FSLDIR=/usr/local/fsl
. ${FSLDIR}/etc/fslconf/fsl.sh
export PATH=${FSLDIR}/bin:$PATH

export PATH=/path/to/mrtrix3/bin:$PATH
export PATH=/path/to/ants/bin:$PATH
export PATH=/path/to/sct/bin:$PATH
```
Reload:
```bash
source ~/.bashrc  # or ~/.zshrc
```
## 3. Demo Data

The repository includes sample data in the `demo_data/` directory with the following structure:

```
demo_data/
└── Sub01/
    └── Vol01/
        ├── ANAT/
        │   ├── Vol01_brain-spinal_t1.json
        │   └── Vol01_brain-spinal_t1.nii.gz
        └── DWI/
            ├── Vol01_brain-spinal_ep2d_DTI_AP_1500.bval
            ├── Vol01_brain-spinal_ep2d_DTI_AP_1500.bvec
            ├── Vol01_brain-spinal_ep2d_DTI_AP_1500.json
            ├── Vol01_brain-spinal_ep2d_DTI_AP_1500.nii.gz
            ├── Vol01_brain-spinal_ep2d_PA_B0_new.bval
            ├── Vol01_brain-spinal_ep2d_PA_B0_new.bvec
            ├── Vol01_brain-spinal_ep2d_PA_B0_new.json
            └── Vol01_brain-spinal_ep2d_PA_B0_new.nii.gz
```

This sample dataset contains:
- T1-weighted anatomical images covering both brain and spinal cord regions
- Diffusion-weighted images with AP phase encoding direction
- Reverse phase-encoded (PA) b0 images for susceptibility distortion correction
- Associated metadata files (JSON, bval, bvec)

## 4. Instructions for Use
### 4.1 Data Organization
data/
└── Subject001/
    └── Volume1/
        ├── ANAT/  (T1-weighted image)
        └── DWI/   (AP/PA dMRI + bval/bvec/json)

### 4.2 Running the Pipeline

The pipeline consists of several stages that should be executed sequentially in MATLAB. Each stage builds upon the outputs of previous stages:

#### Stage 1: Data Preparation
- **M1_format_correct**: Validates and corrects data format issues, ensuring compatibility with downstream processing

#### Stage 2: Preprocessing
- **M2_process_T1**: Processes T1-weighted anatomical images including skull stripping and intensity normalization
- **M2_process_dwi**: Preprocesses diffusion-weighted images including motion and eddy current correction
- **M2_process_dwi_qc**: Performs quality control on DWI data with visual inspection reports
- **M2_process_dwi_sqc**: Strict quality control with automatic outlier detection and rejection

#### Stage 3: Registration to Masks
- **M3_1_t12mask**: Registers T1 images to brain and spinal cord masks
- **M3_2_dwi2mask**: Registers DWI data to the same mask space for consistency

#### Stage 4: Registration to Standard Space
- **M4_1_t12standard**: Transforms T1 images to MNI standard space
- **M4_2_dwi2standard**: Applies the same transformation to DWI data

#### Stage 5: DTI Fitting
- **M5_dwi_dtifit**: Fits diffusion tensor model to generate FA, MD, AD, and RD maps

#### Stage 6: Tractography Preparation
- **M6_1_Tract_seed_edit**: Creates and edits seed regions for tractography
- **M6_2_Tractography_edit**: Sets up tractography parameters and constraints

#### Stage 7: Tractography Processing
- **M7_1_Tractography_crop_edit**: Crops tractography results to regions of interest
- **M7_2_Tractography_edit_sphere_edit**: Applies spherical constraints to tractography
- **M7_3_Tractography_length**: Calculates tract length metrics
- **M7_4_Tractography_orientation_resample**: Resamples tracts for consistent orientation
- **M7_5_Tractography_pointdeleted**: Removes outlier points from tractography
- **M7_5_Tractography_pointmatch**: Matches corresponding points across subjects
- **M7_6_Tractography_downsample**: Reduces point density for efficient processing
- **M7_7_Tractography_dtifit**: Extracts DTI metrics along tract pathways

#### Execution
Run each script sequentially in MATLAB:
```matlab
M1_format_correct
M2_process_T1
M2_process_dwi
M3_1_t12mask
M3_2_dwi2mask
M4_1_t12standard
M4_2_dwi2standard
M5_dwi_dtifit
M6_1_Tract_seed_edit
M6_2_Tractography_edit
M7_1_Tractography_crop_edit
M7_2_Tractography_edit_sphere_edit
M7_3_Tractography_length
M7_4_Tractography_orientation_resample
M7_6_Tractography_downsample
M7_7_Tractography_dtifit
```

Each script prints progress information to the MATLAB console.

### 4.3 Output

The pipeline generates the following outputs:
- Preprocessed DWI data with motion and distortion correction
- DTI scalar maps (FA, MD, AD, RD) in native and standard space
- Tractography files for spinothalamic and other relevant pathways
- Post-processed tracts with quality control measures
- Quantitative tract features including length, orientation, and microstructural metrics

## 5. Directory Structure

```
CoSpine-dMRI/
├── MainFunction/
│   ├── M1_format_correct.m              # Data format validation and correction
│   ├── M2_process_T1.m                  # T1-weighted image preprocessing
│   ├── M2_process_dwi.m                 # DWI preprocessing
│   ├── M2_process_dwi_qc.m             # DWI quality control
│   ├── M2_process_dwi_sqc.m            # DWI strict quality control
│   ├── M3_1_t12mask.m                   # T1 to mask registration
│   ├── M3_2_dwi2mask.m                  # DWI to mask registration
│   ├── M4_1_t12standard.m               # T1 to standard space registration
│   ├── M4_2_dwi2standard.m              # DWI to standard space registration
│   ├── M5_dwi_dtifit.m                  # DTI fitting
│   ├── M6_1_Tract_seed_edit.m           # Tractography seed editing
│   ├── M6_2_Tractography_edit.m         # Tractography editing
│   ├── M7_1_Tractography_crop_edit.m    # Tractography cropping
│   ├── M7_2_Tractography_edit_sphere_edit.m  # Tractography sphere editing
│   ├── M7_3_Tractography_length.m       # Tractography length calculation
│   ├── M7_4_Tractography_orientation_resample.m  # Tractography orientation resampling
│   ├── M7_5_Tractography_pointdeleted.m  # Tractography point deletion
│   ├── M7_5_Tractography_pointmatch.m   # Tractography point matching
│   ├── M7_6_Tractography_downsample.m   # Tractography downsampling
│   └── M7_7_Tractography_dtifit.m       # Tractography DTI fitting
├── SubFunction/
│   ├── Mrtrix_matlab/                   # MRtrix-MATLAB interface
│   ├── Spm_vol/                         # SPM volume utilities
│   ├── MNI2VOX.m                        # MNI to voxel conversion
│   ├── T1_2_MNI152_1mm.cnf              # T1 to MNI152 configuration
│   ├── dwiBrain2standard.m              # DWI brain to standard registration
│   ├── dwiSpinal2t1.m                   # DWI spinal to T1 registration
│   ├── dwiSpinalPreproc.m               # DWI spinal preprocessing
│   ├── dwifslprerpoc_matlab.m           # DWI FSL preprocessing in MATLAB
│   ├── executeCmd.m                     # Command execution utility
│   ├── fiberResample.m                  # Fiber resampling
│   ├── frame.m                          # Frame utility
│   ├── generateSpinalSeed.m             # Spinal seed generation
│   ├── getFileExtension.m               # File extension utility
│   ├── getMeasure.m                     # Measurement utility
│   └── propseg.m                        # Propagation segmentation
├── demo_data/                           # Sample dataset
│   └── Sub01/
│       └── Vol01/
│           ├── ANAT/                    # Anatomical data
│           └── DWI/                     # Diffusion data
└── README.md                            # This file
```

## 6. License

This project is released under the MIT License. See the LICENSE file for details.

## 7. Contact

For questions or issues regarding the CoSpine-dMRI pipeline:
- Email: boddm123@gmail.com
- GitHub Issues: [Create an issue](https://github.com/yourusername/CoSpine-dMRI/issues)