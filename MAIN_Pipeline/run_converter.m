% RUN_CONVERTER - Quick launcher script for WiBCI Converter GUI
%
% Usage:
%   1. Open MATLAB
%   2. Navigate to the wibci2eeglab-main folder
%   3. Run this script: run_converter
%
% The GUI will open and allow you to:
%   - Load single CSV files or batch process entire folders
%   - Configure which EEG channels to include
%   - Rename channels if needed
%   - Convert files to EEGLAB .set format
%
% Output files are saved to SET_files folder in the data directory.

% Add current folder to path
addpath(pwd);

% Launch GUI
WIBCI_Converter_GUI();
