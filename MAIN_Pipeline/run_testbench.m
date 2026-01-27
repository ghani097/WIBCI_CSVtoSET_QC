% RUN_TESTBENCH - Quick launcher for comparing loadWiBCIData loaders
%
% This script runs the testbench that compares the original loadWiBCIData
% function with the updated loadWiBCIData_UG function to verify they
% produce identical results.
%
% The UG (Updated) version uses an iterative approach instead of recursion,
% which avoids stack overflow issues with large files.
%
% Usage:
%   1. Open MATLAB
%   2. Navigate to the wibci2eeglab-main folder
%   3. Run this script: run_testbench
%
% The testbench will:
%   - Find all CSV files in the TEST folder
%   - Load each file with both functions
%   - Compare the results for equality
%   - Report timing differences (speedup)
%   - Save results to TEST/testbench_results.mat

% Add current folder to path
addpath(pwd);

% Get the TEST folder path
scriptDir = fileparts(mfilename('fullpath'));
testFolder = fullfile(fileparts(scriptDir), 'TEST');

fprintf('WiBCI Data Loader Testbench\n');
fprintf('===========================\n\n');
fprintf('Test folder: %s\n\n', testFolder);

% Check if TEST folder exists
if ~exist(testFolder, 'dir')
    fprintf('TEST folder not found.\n');
    fprintf('Creating TEST folder...\n');
    mkdir(testFolder);
    fprintf('Please add CSV files to the TEST folder and run again.\n');
    return;
end

% Check for CSV files
csvFiles = dir(fullfile(testFolder, '*.csv'));
if isempty(csvFiles)
    fprintf('No CSV files found in TEST folder.\n');
    fprintf('Please add CSV files and run again.\n');
    return;
end

fprintf('Found %d CSV files. Starting tests...\n\n', length(csvFiles));

% Run testbench
results = testbench_compare_loaders(testFolder, true);

% Display final status
fprintf('\n');
if results.allPassed
    fprintf('SUCCESS: The loadWiBCIData_UG function produces identical results!\n');
    fprintf('You can safely use the updated function for large files.\n');
else
    fprintf('WARNING: Some differences were found. Please review the output above.\n');
end
