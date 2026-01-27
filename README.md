# WiBCI CSV to SET Converter & Quality Check

A MATLAB-based toolbox for converting WiBCI EEG data from CSV format to EEGLAB .set format, with integrated quality checking and preprocessing capabilities.

## Overview

This repository provides tools for processing EEG data from the WiBCI (Wireless Brain-Computer Interface) system. It includes functionality for:
- Converting WiBCI CSV files to EEGLAB .set format
- Performing quality checks on EEG data
- Applying filtering, ASR (Artifact Subspace Reconstruction), and ICLabel cleaning
- Batch processing multiple files
- Interactive GUI and command-line interfaces

## Features

### Converter Features
- **Single file or batch folder conversion** - Process one file or an entire directory
- **Configurable channel selection** - Choose which EEG channels to include (default: 10 channels from 16-channel montage)
- **Channel renaming** - Customize channel names if needed
- **Automatic missing packet handling** - Detects and fills missing data packets using MATLAB's `fillmissing` function with pchip interpolation
- **Event/trigger preservation** - Maintains software and hardware trigger events (ST A/B, HT A/B)
- **Progress tracking** - Real-time status display during conversion
- **Organized output** - Saves .set files to SET_files folder in data directory

### Quality Check Features
- **Single or batch .set file loading** - Load one or multiple EEGLAB datasets
- **Preprocessing pipeline** - Apply filtering, ASR, and ICLabel cleaning
- **Quality metrics** - Automatic assessment (Excellent/Good/Moderate/Poor)
- **IC visualization** - View independent component topoplots, activity, and spectra
- **Batch reporting** - Export quality metrics to Excel for multiple files
- **Data cleaning** - Save cleaned datasets after preprocessing

## Requirements

### Software Requirements
- **MATLAB** (R2019b or later recommended)
- **EEGLAB** toolbox (latest version recommended)

### Required EEGLAB Plugins
- **clean_rawdata** plugin (for ASR - Artifact Subspace Reconstruction)
- **ICLabel** plugin (for automatic IC classification)

### Installation of EEGLAB Plugins
1. Launch EEGLAB in MATLAB
2. Go to **File > Manage EEGLAB extensions**
3. Install the following plugins:
   - clean_rawdata
   - ICLabel

## Installation

1. Clone or download this repository:
```bash
git clone https://github.com/ghani097/WIBCI_CSVtoSET_QC.git
```

2. Add the MAIN_Pipeline folder to your MATLAB path:
```matlab
addpath('/path/to/WIBCI_CSVtoSET_QC/MAIN_Pipeline');
```

3. Ensure EEGLAB is installed and in your MATLAB path

## Usage

### Method 1: GUI Interface (Recommended)

Launch the GUI using the quick launcher script:

```matlab
cd MAIN_Pipeline
run_converter
```

Or directly:
```matlab
WIBCI_Converter_GUI()
```

#### GUI Tabs:

**Tab 1 - Converter:**
1. Click "Single File" to select one CSV file, or "Folder" for batch processing
2. Configure channel selection if needed (default: 10 standard channels)
3. Rename channels if desired
4. Click "Convert" to start conversion
5. Monitor progress in the log window
6. Output .set files are saved to `SET_files` folder in the data directory

**Tab 2 - Quality Check:**
1. Load single or multiple .set files
2. Apply filtering, ASR, and ICLabel cleaning
3. View quality metrics (Excellent/Good/Moderate/Poor)
4. Visualize IC topoplots, activity, and spectra
5. Save cleaned data
6. Export batch reports to Excel

### Method 2: Command-Line Interface

#### Basic Conversion:
```matlab
% Load EEGLAB first
eeglab;

% Convert single file with automatic missing packet filling
EEG = wibci2eeglab('C:\path\to\your\data.csv');

% Convert without filling missing packets (keeps NaNs)
EEG = wibci2eeglab('C:\path\to\your\data.csv', 0);

% Use EEGLAB functions on the data
pop_eegplot(EEG, 1, 1, 1);

% Save as EEGLAB dataset
pop_saveset(EEG, 'filename', 'my_eeg_data.set', 'filepath', 'C:\output\');
```

#### Experiment A Data:
For data saved with "Experiment A" montage:
```matlab
% Load Experiment A file
data = loadExperimentAFile('experimentA.csv');

% Quick visualization
quickViewExperimentAFile('experimentA.csv');
```

## Data Format

### Input: WiBCI CSV Files
WiBCI hardware records EEG data in CSV format with the following characteristics:
- **Sampling rate:** 250 Hz
- **Default channels:** 16 EEG channels + accelerometer + event channels
- **Standard 10-20 channel names:** Fp1, Fp2, F3, Fz, F4, T3, C3, Cz, C4, T4, P3, Pz, P4, O1, O2, ref
- **Default selected channels (10):** Fp1, F3, Fz, F4, C3, Cz, C4, P3, Pz, P4
- **Event channels:** Software triggers (ST A, ST B) and Hardware triggers (HT A, HT B)

### Output: EEGLAB .set Format
Converted files are in standard EEGLAB format (.set/.fdt) containing:
- EEG channel data
- Channel locations (Standard-10-5-Cap385)
- Event markers (software and hardware triggers)
- Metadata (sampling rate, channel names, etc.)

### Missing Data Handling
WiBCI uses Wi-Fi for wireless data transmission, which may occasionally result in missing packets. The converter:
1. Automatically detects missing packets
2. Reports the percentage of missing data
3. Fills missing packets using MATLAB's `fillmissing` function with pchip interpolation (default)
4. Optionally keeps missing data as NaNs if fillMissingPackets=0

## Repository Structure

```
WIBCI_CSVtoSET_QC/
├── MAIN_Pipeline/              # Main conversion and processing scripts
│   ├── WIBCI_Converter_GUI.m   # Main GUI application
│   ├── run_converter.m         # Quick launcher script
│   ├── wibci2eeglab.m          # Core conversion function
│   ├── loadWiBCIData_UG.m      # Data loading function
│   ├── loadExperimentAFile.m   # Experiment A data loader
│   ├── quickViewExperimentAFile.m  # Quick visualization
│   ├── eegLabEventStructW.m    # Event structure builder
│   ├── strcmpIND.m             # String comparison utility
│   └── Example Data/           # Sample CSV files
│       ├── experimentA.csv
│       ├── WIS00101.csv
│       └── ...
├── TEST/                       # Test data files
│   ├── 27.01.2026.Sub1MI1d1.csv
│   ├── 27.01.2026.Sub1MI2d1.csv
│   └── ...
└── README.md                   # This file
```

## Event/Trigger Abbreviations

The WiBCI system supports four types of event triggers:

1. **ST A** - Software Trigger A (event marker sent by software)
2. **ST B** - Software Trigger B (event marker sent by software)
3. **HT A** - Hardware Trigger A (event marker from hardware input)
4. **HT B** - Hardware Trigger B (event marker from hardware input)

These events are preserved in the EEGLAB EEG.event structure and can be used for epoch extraction and analysis.

## Examples

### Example 1: Quick Conversion
```matlab
% Start EEGLAB
eeglab;

% Convert CSV to EEGLAB format
EEG = wibci2eeglab('participant6indoors.csv');

% Plot the data
pop_eegplot(EEG, 1, 1, 1);

% Save the dataset
pop_saveset(EEG, 'filename', 'participant6.set');
```

### Example 2: Batch Processing with GUI
```matlab
% Launch the GUI
run_converter;

% In the GUI:
% 1. Click "Folder" button
% 2. Select folder containing multiple CSV files
% 3. Click "Convert" - all files will be processed
% 4. Check SET_files folder for output
```

### Example 3: Processing Without Missing Data Fill
```matlab
% Load without filling missing packets (for custom processing)
EEG = wibci2eeglab('my_data.csv', 0);

% Check for NaN values
nan_count = sum(isnan(EEG.data(:)));
fprintf('Number of NaN values: %d\n', nan_count);

% Apply custom interpolation or handling
% ... your processing code ...
```

## Troubleshooting

### Issue: "Channel not found in EEGLAB channel location file"
**Solution:** The wibci2eeglab function automatically ignores non-EEGLAB channels. Check the warning message to see which channels were ignored.

### Issue: "Large percentage of missing data reported"
**Solution:** This is normal for WiBCI data due to Wi-Fi transmission limitations. The converter automatically fills missing packets using pchip interpolation. If you prefer to handle missing data manually, use `wibci2eeglab(filePath, 0)` to keep NaNs.

### Issue: "EEGLAB functions not found"
**Solution:** Ensure EEGLAB is properly installed and added to MATLAB path. Run `eeglab;` to start EEGLAB before using conversion functions.

### Issue: "clean_rawdata or ICLabel plugin not found"
**Solution:** Install the required EEGLAB plugins:
1. Start EEGLAB
2. Go to File > Manage EEGLAB extensions
3. Install clean_rawdata and ICLabel plugins

### Issue: GUI not displaying correctly
**Solution:** Ensure you're using MATLAB R2019b or later. Try resizing the window or restarting MATLAB.

## Quality Check Metrics

The Quality Check module evaluates EEG data based on:
- **Data continuity** - Amount of missing or bad data
- **Artifact levels** - Presence of movement, muscle, or eye artifacts
- **IC classification** - Quality of independent components
- **Signal-to-noise ratio** - Overall data quality

Quality ratings:
- **Excellent** - Clean data with minimal artifacts
- **Good** - Good quality with minor artifacts
- **Moderate** - Acceptable quality, may need additional cleaning
- **Poor** - Significant artifacts or data quality issues

## Technical Notes

### Channel Configuration
Default configuration uses 10 of the 16 available channels:
- Selected: Fp1, F3, Fz, F4, C3, Cz, C4, P3, Pz, P4
- Available but not selected by default: Fp2, T3, T4, O1, O2, ref

You can modify channel selection in the GUI or by editing the `wibci2eeglab.m` function.

### Data Preprocessing
The converter performs the following preprocessing steps:
1. Loads raw CSV data
2. Applies calibration factors (0.02235 for EEG channels)
3. Computes cumulative sum to get absolute values
4. Detects and fills missing packets
5. Extracts selected channels
6. Creates EEGLAB structure with channel locations
7. Adds event markers

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is provided as-is for research and educational purposes.

## Acknowledgments

- WiBCI hardware and software development team
- EEGLAB toolbox developers
- Contributors to clean_rawdata and ICLabel plugins

## Contact

For questions or issues, please open an issue on the GitHub repository: https://github.com/ghani097/WIBCI_CSVtoSET_QC

## Version History

- **January 2026** - Initial release with GUI converter and quality check features
- Added comprehensive documentation and examples
