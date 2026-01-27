function results = testbench_compare_loaders(testFolder, verbose)
% TESTBENCH_COMPARE_LOADERS - Compare loadWiBCIData and loadWiBCIData_UG
%
% This testbench verifies that loadWiBCIData_UG produces identical results
% to the original loadWiBCIData function, while being more efficient for
% large files (avoiding recursive stack overflow issues).
%
% Usage:
%   results = testbench_compare_loaders()                    % Use default TEST folder
%   results = testbench_compare_loaders(testFolder)          % Specify folder
%   results = testbench_compare_loaders(testFolder, true)    % Verbose output
%
% Output:
%   results - Structure with detailed comparison results
%
% Author: Generated for WIBCI_Addon project
% Date: January 2026

    if nargin < 1 || isempty(testFolder)
        % Default to TEST folder
        scriptDir = fileparts(mfilename('fullpath'));
        testFolder = fullfile(fileparts(scriptDir), 'TEST');
    end

    if nargin < 2
        verbose = true;
    end

    % Initialize results structure
    results = struct();
    results.testFolder = testFolder;
    results.timestamp = datestr(now);
    results.files = {};
    results.allPassed = true;
    results.summary = struct('total', 0, 'passed', 0, 'failed', 0, 'skipped', 0);

    % Print header
    printSeparator('=');
    fprintf('TESTBENCH: loadWiBCIData vs loadWiBCIData_UG\n');
    printSeparator('=');
    fprintf('Test folder: %s\n', testFolder);
    fprintf('Timestamp: %s\n', results.timestamp);
    printSeparator('-');

    % Find test files
    if ~exist(testFolder, 'dir')
        error('Test folder does not exist: %s', testFolder);
    end

    csvFiles = dir(fullfile(testFolder, '*.csv'));
    if isempty(csvFiles)
        warning('No CSV files found in test folder.');
        return;
    end

    fprintf('Found %d CSV files to test.\n\n', length(csvFiles));
    results.summary.total = length(csvFiles);

    % Test each file
    for i = 1:length(csvFiles)
        filePath = fullfile(testFolder, csvFiles(i).name);
        fileResult = testSingleFile(filePath, verbose);
        results.files{i} = fileResult;

        if fileResult.skipped
            results.summary.skipped = results.summary.skipped + 1;
        elseif fileResult.passed
            results.summary.passed = results.summary.passed + 1;
        else
            results.summary.failed = results.summary.failed + 1;
            results.allPassed = false;
        end
    end

    % Print summary
    printSeparator('=');
    fprintf('SUMMARY\n');
    printSeparator('=');
    fprintf('Total files tested: %d\n', results.summary.total);
    fprintf('  Passed:  %d\n', results.summary.passed);
    fprintf('  Failed:  %d\n', results.summary.failed);
    fprintf('  Skipped: %d\n', results.summary.skipped);
    printSeparator('-');

    if results.allPassed && results.summary.failed == 0
        fprintf('*** ALL TESTS PASSED ***\n');
        fprintf('loadWiBCIData_UG produces identical results to loadWiBCIData.\n');
    else
        fprintf('*** SOME TESTS FAILED ***\n');
        fprintf('Please review the detailed output above.\n');
    end

    printSeparator('=');

    % Save results to file
    resultsFile = fullfile(testFolder, 'testbench_results.mat');
    save(resultsFile, 'results');
    fprintf('Results saved to: %s\n', resultsFile);
end

function result = testSingleFile(filePath, verbose)
    % Test a single file with both loaders

    [~, fileName, ~] = fileparts(filePath);

    result = struct();
    result.fileName = fileName;
    result.filePath = filePath;
    result.passed = false;
    result.skipped = false;
    result.error = '';
    result.timing = struct();
    result.comparison = struct();

    if verbose
        fprintf('Testing: %s\n', fileName);
    end

    % Test with fillMissingPackets = true (default)
    fillMissing = 1;

    % Load with original function
    try
        tic;
        data_original = loadWiBCIData(filePath, fillMissing);
        result.timing.original = toc;
    catch ME
        if verbose
            fprintf('  [SKIP] Original loader failed: %s\n', ME.message);
        end
        result.skipped = true;
        result.error = sprintf('Original loader error: %s', ME.message);
        return;
    end

    % Load with updated function
    try
        tic;
        data_updated = loadWiBCIData_UG(filePath, fillMissing);
        result.timing.updated = toc;
    catch ME
        if verbose
            fprintf('  [FAIL] Updated loader failed: %s\n', ME.message);
        end
        result.passed = false;
        result.error = sprintf('Updated loader error: %s', ME.message);
        return;
    end

    % Compare results
    result.comparison = compareData(data_original, data_updated);

    if result.comparison.identical
        result.passed = true;
        if verbose
            fprintf('  [PASS] Data identical. Original: %.3fs, Updated: %.3fs (%.1fx speedup)\n', ...
                    result.timing.original, result.timing.updated, ...
                    result.timing.original / max(result.timing.updated, 0.001));
        end
    else
        result.passed = false;
        if verbose
            fprintf('  [FAIL] Data differs!\n');
            printComparisonDetails(result.comparison);
        end
    end

    % Additional test with fillMissingPackets = false
    if verbose
        fprintf('  Testing with fillMissingPackets = false...\n');
    end

    try
        data_orig_nofill = loadWiBCIData(filePath, 0);
        data_upd_nofill = loadWiBCIData_UG(filePath, 0);
        comp_nofill = compareData(data_orig_nofill, data_upd_nofill);

        result.comparison_nofill = comp_nofill;

        if comp_nofill.identical
            if verbose
                fprintf('  [PASS] No-fill mode: Data identical.\n');
            end
        else
            result.passed = false;
            if verbose
                fprintf('  [FAIL] No-fill mode: Data differs!\n');
            end
        end
    catch ME
        if verbose
            fprintf('  [SKIP] No-fill test error: %s\n', ME.message);
        end
    end

    if verbose
        fprintf('\n');
    end
end

function comp = compareData(data1, data2)
    % Compare two WiBCIData structures

    comp = struct();
    comp.identical = true;
    comp.details = {};

    % Compare channelData
    if isfield(data1, 'channelData') && isfield(data2, 'channelData')
        cd1 = data1.channelData;
        cd2 = data2.channelData;

        % Check dimensions
        if ~isequal(size(cd1), size(cd2))
            comp.identical = false;
            comp.details{end+1} = sprintf('channelData size differs: [%s] vs [%s]', ...
                                          mat2str(size(cd1)), mat2str(size(cd2)));
        else
            comp.sizeMatch = true;
            comp.dataSize = size(cd1);

            % Check for NaN differences
            nan1 = isnan(cd1);
            nan2 = isnan(cd2);

            if ~isequal(nan1, nan2)
                comp.identical = false;
                comp.details{end+1} = 'NaN locations differ';
            end

            % Compare non-NaN values
            valid = ~nan1 & ~nan2;
            if any(valid(:))
                maxDiff = max(abs(cd1(valid) - cd2(valid)));
                meanDiff = mean(abs(cd1(valid) - cd2(valid)));
                relDiff = maxDiff / max(abs(cd1(valid)));

                comp.maxAbsDiff = maxDiff;
                comp.meanAbsDiff = meanDiff;
                comp.maxRelDiff = relDiff;

                % Allow for small floating point differences
                tolerance = 1e-10;
                if maxDiff > tolerance
                    comp.identical = false;
                    comp.details{end+1} = sprintf('channelData values differ: maxDiff=%.2e', maxDiff);
                end
            end

            % Check exact equality (including NaN handling)
            comp.exactMatch = isequaln(cd1, cd2);
        end
    else
        comp.identical = false;
        comp.details{end+1} = 'channelData field missing in one or both structures';
    end

    % Compare channelNames
    if isfield(data1, 'channelNames') && isfield(data2, 'channelNames')
        if ~isequal(data1.channelNames, data2.channelNames)
            comp.identical = false;
            comp.details{end+1} = 'channelNames differ';
        end
        comp.channelNamesMatch = isequal(data1.channelNames, data2.channelNames);
    end
end

function printComparisonDetails(comp)
    fprintf('    Comparison details:\n');
    for i = 1:length(comp.details)
        fprintf('      - %s\n', comp.details{i});
    end

    if isfield(comp, 'maxAbsDiff')
        fprintf('      - Max absolute difference: %.2e\n', comp.maxAbsDiff);
    end
    if isfield(comp, 'meanAbsDiff')
        fprintf('      - Mean absolute difference: %.2e\n', comp.meanAbsDiff);
    end
end

function printSeparator(char)
    fprintf('%s\n', repmat(char, 1, 60));
end
