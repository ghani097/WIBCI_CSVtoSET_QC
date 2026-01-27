function WIBCI_Converter_GUI()
% WIBCI_Converter_GUI - GUI for converting WiBCI CSV files to EEGLAB .set format
%                       and performing quality checks on EEG data
%
% Features:
%   Tab 1 - Converter:
%     - Single file or batch folder conversion
%     - Configurable channel selection and renaming
%     - Progress display and file status logging
%     - Saves .set files to SET_files folder in data directory
%
%   Tab 2 - Quality Check:
%     - Load single or batch .set files
%     - Apply filtering, ASR, and ICLabel cleaning
%     - Display quality metrics (Excellent/Good/Moderate/Poor)
%     - View IC topoplots, activity, and spectra
%     - Save cleaned data and export batch reports to Excel
%
% Usage:
%   WIBCI_Converter_GUI()
%
% Requirements for Quality Check:
%   - EEGLAB with clean_rawdata plugin (for ASR)
%   - ICLabel plugin
%
% Author: Generated for WIBCI_Addon project
% Date: January 2026

    % Create main figure
    fig = figure('Name', 'WiBCI EEG Tool - Converter & Quality Check', ...
                 'NumberTitle', 'off', ...
                 'Position', [100, 50, 1000, 780], ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none', ...
                 'Resize', 'on', ...
                 'CloseRequestFcn', @closeCallback);

    % Store application data
    appData = struct();
    appData.filesToConvert = {};
    appData.dataFolder = '';
    appData.isConverting = false;

    % Default channel configuration (from wibci2eeglab.m)
    appData.allChannels = struct();
    appData.allChannels.indices = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19];
    appData.allChannels.names = {'Fp1', 'Fp2', 'F3', 'Fz', 'F4', 'T3', 'C3', 'Cz', 'C4', 'T4', 'P3', 'Pz', 'P4', 'O1', 'O2', 'ref'};

    % Default selected channels (as in original wibci2eeglab)
    appData.defaultSelectedIndices = [4, 6, 7, 8, 10, 11, 12, 14, 15, 16];
    appData.selectedChannels = appData.defaultSelectedIndices;
    appData.channelNames = {'Fp1', 'F3', 'Fz', 'F4', 'C3', 'Cz', 'C4', 'P3', 'Pz', 'P4'};

    % Sample rate
    appData.sampleRate = 250;

    % Fill missing packets option
    appData.fillMissingPackets = true;

    % Quality check data
    appData.qcEEG = [];
    appData.qcFilePath = '';
    appData.qcIsProcessing = false;
    appData.qcFiles = {};           % For batch processing
    appData.qcBatchResults = {};    % Store batch results
    appData.qcCurrentFileIdx = 0;   % Current file in batch

    guidata(fig, appData);

    % Create tab group
    tabGroup = uitabgroup('Parent', fig, 'Position', [0, 0, 1, 1]);

    % Tab 1: Converter
    converterTab = uitab('Parent', tabGroup, 'Title', '  Converter  ');
    createConverterUI(converterTab, fig);

    % Tab 2: Quality Check
    qcTab = uitab('Parent', tabGroup, 'Title', '  Quality Check  ');
    createQualityCheckUI(qcTab, fig);

    % Update display
    updateFileList(fig);
end

%% ========================================================================
%  CONVERTER TAB UI (Original functionality - unchanged)
%  ========================================================================

function createConverterUI(parent, fig)
    % --- Top Panel: File Selection ---
    filePanel = uipanel('Parent', parent, ...
                        'Title', 'File Selection', ...
                        'FontSize', 10, ...
                        'FontWeight', 'bold', ...
                        'Position', [0.02, 0.82, 0.96, 0.16]);

    uicontrol('Parent', filePanel, ...
              'Style', 'pushbutton', ...
              'String', 'Load Single File', ...
              'Position', [20, 50, 120, 35], ...
              'FontSize', 9, ...
              'Callback', @loadSingleFile);

    uicontrol('Parent', filePanel, ...
              'Style', 'pushbutton', ...
              'String', 'Load Folder (Batch)', ...
              'Position', [160, 50, 140, 35], ...
              'FontSize', 9, ...
              'Callback', @loadFolder);

    uicontrol('Parent', filePanel, ...
              'Style', 'pushbutton', ...
              'String', 'Clear List', ...
              'Position', [320, 50, 100, 35], ...
              'FontSize', 9, ...
              'Callback', @clearFileList);

    uicontrol('Parent', filePanel, ...
              'Style', 'text', ...
              'String', 'Data Folder:', ...
              'Position', [20, 15, 80, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', filePanel, ...
              'Style', 'text', ...
              'String', 'No folder selected', ...
              'Tag', 'folderPathText', ...
              'Position', [100, 15, 750, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    % --- Middle Left Panel: File List ---
    fileListPanel = uipanel('Parent', parent, ...
                            'Title', 'Files to Convert', ...
                            'FontSize', 10, ...
                            'FontWeight', 'bold', ...
                            'Position', [0.02, 0.35, 0.46, 0.45]);

    uicontrol('Parent', fileListPanel, ...
              'Style', 'listbox', ...
              'Tag', 'fileListBox', ...
              'Position', [10, 10, 390, 250], ...
              'FontSize', 9, ...
              'Max', 2, ...
              'String', {});

    % --- Middle Right Panel: Channel Configuration ---
    channelPanel = uipanel('Parent', parent, ...
                           'Title', 'Channel Configuration', ...
                           'FontSize', 10, ...
                           'FontWeight', 'bold', ...
                           'Position', [0.50, 0.35, 0.48, 0.45]);

    uicontrol('Parent', channelPanel, ...
              'Style', 'text', ...
              'String', 'Select channels and rename if needed:', ...
              'Position', [10, 245, 250, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    % Create channel table
    columnNames = {'Select', 'Column', 'Original Name', 'Output Name'};
    columnFormat = {'logical', 'numeric', 'char', 'char'};
    columnEditable = [true, false, false, true];
    columnWidth = {50, 60, 100, 100};

    appData = guidata(fig);
    tableData = createChannelTableData(appData);

    uitable('Parent', channelPanel, ...
            'Tag', 'channelTable', ...
            'Data', tableData, ...
            'ColumnName', columnNames, ...
            'ColumnFormat', columnFormat, ...
            'ColumnEditable', columnEditable, ...
            'ColumnWidth', columnWidth, ...
            'Position', [10, 45, 350, 195], ...
            'CellEditCallback', @channelTableEdit);

    uicontrol('Parent', channelPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Reset to Default', ...
              'Position', [10, 10, 110, 28], ...
              'FontSize', 9, ...
              'Callback', @resetChannels);

    uicontrol('Parent', channelPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Select All', ...
              'Position', [130, 10, 80, 28], ...
              'FontSize', 9, ...
              'Callback', @selectAllChannels);

    uicontrol('Parent', channelPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Deselect All', ...
              'Position', [220, 10, 80, 28], ...
              'FontSize', 9, ...
              'Callback', @deselectAllChannels);

    % --- Options Panel ---
    optionsPanel = uipanel('Parent', parent, ...
                           'Title', 'Options', ...
                           'FontSize', 10, ...
                           'FontWeight', 'bold', ...
                           'Position', [0.02, 0.22, 0.96, 0.11]);

    uicontrol('Parent', optionsPanel, ...
              'Style', 'checkbox', ...
              'Tag', 'fillMissingCheck', ...
              'String', 'Fill missing packets (PCHIP interpolation)', ...
              'Value', 1, ...
              'Position', [20, 30, 280, 25], ...
              'FontSize', 9, ...
              'Callback', @fillMissingChanged);

    uicontrol('Parent', optionsPanel, ...
              'Style', 'text', ...
              'String', 'Sample Rate (Hz):', ...
              'Position', [320, 30, 110, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', optionsPanel, ...
              'Style', 'edit', ...
              'Tag', 'sampleRateEdit', ...
              'String', '250', ...
              'Position', [430, 28, 60, 25], ...
              'FontSize', 9, ...
              'Callback', @sampleRateChanged);

    uicontrol('Parent', optionsPanel, ...
              'Style', 'text', ...
              'String', 'Output: SET_files folder in data directory', ...
              'Position', [520, 30, 300, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9, ...
              'FontAngle', 'italic');

    % --- Status/Log Panel ---
    statusPanel = uipanel('Parent', parent, ...
                          'Title', 'Conversion Log', ...
                          'FontSize', 10, ...
                          'FontWeight', 'bold', ...
                          'Position', [0.02, 0.02, 0.70, 0.18]);

    uicontrol('Parent', statusPanel, ...
              'Style', 'listbox', ...
              'Tag', 'statusLog', ...
              'Position', [10, 10, 590, 90], ...
              'FontSize', 8, ...
              'Max', 2, ...
              'Enable', 'inactive', ...
              'String', {'Ready. Load files to begin.'});

    % --- Convert Button Panel ---
    convertPanel = uipanel('Parent', parent, ...
                           'Title', 'Actions', ...
                           'FontSize', 10, ...
                           'FontWeight', 'bold', ...
                           'Position', [0.74, 0.02, 0.24, 0.18]);

    uicontrol('Parent', convertPanel, ...
              'Style', 'pushbutton', ...
              'Tag', 'convertBtn', ...
              'String', 'CONVERT', ...
              'Position', [20, 45, 170, 45], ...
              'FontSize', 12, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.3, 0.7, 0.3], ...
              'ForegroundColor', [1, 1, 1], ...
              'Callback', @startConversion);

    uicontrol('Parent', convertPanel, ...
              'Style', 'text', ...
              'Tag', 'progressText', ...
              'String', '0 / 0 files', ...
              'Position', [20, 15, 170, 20], ...
              'FontSize', 10, ...
              'HorizontalAlignment', 'center');
end

%% ========================================================================
%  QUALITY CHECK TAB UI
%  ========================================================================

function createQualityCheckUI(parent, fig)
    % --- File Loading Panel ---
    loadPanel = uipanel('Parent', parent, ...
                        'Title', 'Load EEG Data (.set files)', ...
                        'FontSize', 10, ...
                        'FontWeight', 'bold', ...
                        'Position', [0.02, 0.85, 0.96, 0.13]);

    uicontrol('Parent', loadPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Load Single File', ...
              'Position', [20, 30, 110, 35], ...
              'FontSize', 9, ...
              'Callback', @qcLoadFile);

    uicontrol('Parent', loadPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Load Folder (Batch)', ...
              'Position', [140, 30, 130, 35], ...
              'FontSize', 9, ...
              'Callback', @qcLoadFolder);

    uicontrol('Parent', loadPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Clear', ...
              'Position', [280, 30, 60, 35], ...
              'FontSize', 9, ...
              'Callback', @qcClearFiles);

    uicontrol('Parent', loadPanel, ...
              'Style', 'text', ...
              'Tag', 'qcFileText', ...
              'String', 'No files loaded', ...
              'Position', [360, 35, 550, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', loadPanel, ...
              'Style', 'text', ...
              'Tag', 'qcDataInfo', ...
              'String', '', ...
              'Position', [360, 12, 550, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9, ...
              'FontAngle', 'italic');

    % --- File List Panel (for batch) ---
    fileListPanel = uipanel('Parent', parent, ...
                            'Title', 'Files to Process', ...
                            'FontSize', 10, ...
                            'FontWeight', 'bold', ...
                            'Position', [0.02, 0.55, 0.30, 0.28]);

    uicontrol('Parent', fileListPanel, ...
              'Style', 'listbox', ...
              'Tag', 'qcFileList', ...
              'Position', [10, 10, 260, 165], ...
              'FontSize', 8, ...
              'Callback', @qcFileListSelect, ...
              'String', {'(No files loaded)'});

    % --- Processing Options Panel ---
    procPanel = uipanel('Parent', parent, ...
                        'Title', 'Processing Options', ...
                        'FontSize', 10, ...
                        'FontWeight', 'bold', ...
                        'Position', [0.34, 0.55, 0.32, 0.28]);

    % Filtering options
    uicontrol('Parent', procPanel, ...
              'Style', 'checkbox', ...
              'Tag', 'qcFilterCheck', ...
              'String', 'Apply Bandpass Filter', ...
              'Value', 1, ...
              'Position', [15, 150, 180, 25], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'HP:', ...
              'Position', [30, 128, 25, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'edit', ...
              'Tag', 'qcHighpass', ...
              'String', '1', ...
              'Position', [55, 126, 40, 22], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'LP:', ...
              'Position', [105, 128, 25, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'edit', ...
              'Tag', 'qcLowpass', ...
              'String', '40', ...
              'Position', [130, 126, 40, 22], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'Hz', ...
              'Position', [175, 128, 25, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    % ASR options
    uicontrol('Parent', procPanel, ...
              'Style', 'checkbox', ...
              'Tag', 'qcASRCheck', ...
              'String', 'Apply ASR', ...
              'Value', 1, ...
              'Position', [15, 100, 100, 25], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'Cutoff:', ...
              'Position', [115, 102, 45, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'edit', ...
              'Tag', 'qcASRCutoff', ...
              'String', '20', ...
              'Position', [160, 100, 40, 22], ...
              'FontSize', 9);

    % ICA/ICLabel options
    uicontrol('Parent', procPanel, ...
              'Style', 'checkbox', ...
              'Tag', 'qcICACheck', ...
              'String', 'Run ICA & ICLabel', ...
              'Value', 1, ...
              'Position', [15, 70, 150, 25], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'Artifact threshold:', ...
              'Position', [30, 48, 110, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'edit', ...
              'Tag', 'qcICThreshold', ...
              'String', '0.8', ...
              'Position', [140, 46, 45, 22], ...
              'FontSize', 9);

    % Auto-save option
    uicontrol('Parent', procPanel, ...
              'Style', 'checkbox', ...
              'Tag', 'qcAutoSave', ...
              'String', 'Auto-save cleaned files', ...
              'Value', 1, ...
              'Position', [15, 18, 180, 25], ...
              'FontSize', 9);

    % --- Quality Metrics Panel ---
    metricsPanel = uipanel('Parent', parent, ...
                           'Title', 'Quality Metrics (Current File)', ...
                           'FontSize', 10, ...
                           'FontWeight', 'bold', ...
                           'Position', [0.68, 0.55, 0.30, 0.28]);

    % Overall quality indicator
    uicontrol('Parent', metricsPanel, ...
              'Style', 'text', ...
              'String', 'Overall Quality:', ...
              'Position', [15, 150, 100, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 10, ...
              'FontWeight', 'bold');

    uicontrol('Parent', metricsPanel, ...
              'Style', 'text', ...
              'Tag', 'qcOverallQuality', ...
              'String', '---', ...
              'Position', [115, 145, 120, 30], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 14, ...
              'FontWeight', 'bold');

    % Individual metrics
    metricLabels = {'Retained Var:', 'Good ICs:', 'Bad Chans:', 'Data Rank:', 'SNR:'};
    metricTags = {'qcVariance', 'qcGoodICs', 'qcBadChans', 'qcRank', 'qcSNR'};

    for i = 1:length(metricLabels)
        yPos = 120 - (i-1)*22;
        uicontrol('Parent', metricsPanel, ...
                  'Style', 'text', ...
                  'String', metricLabels{i}, ...
                  'Position', [15, yPos, 80, 18], ...
                  'HorizontalAlignment', 'left', ...
                  'FontSize', 9);

        uicontrol('Parent', metricsPanel, ...
                  'Style', 'text', ...
                  'Tag', metricTags{i}, ...
                  'String', '---', ...
                  'Position', [95, yPos, 140, 18], ...
                  'HorizontalAlignment', 'left', ...
                  'FontSize', 9);
    end

    % --- Processing Log Panel ---
    logPanel = uipanel('Parent', parent, ...
                       'Title', 'Processing Log', ...
                       'FontSize', 10, ...
                       'FontWeight', 'bold', ...
                       'Position', [0.02, 0.12, 0.64, 0.41]);

    uicontrol('Parent', logPanel, ...
              'Style', 'listbox', ...
              'Tag', 'qcLog', ...
              'Position', [10, 10, 590, 260], ...
              'FontSize', 8, ...
              'Max', 2, ...
              'Enable', 'inactive', ...
              'String', {'Quality Check ready. Load .set file(s) to begin.'});

    % --- Action Buttons Panel ---
    actionPanel = uipanel('Parent', parent, ...
                          'Title', 'Actions', ...
                          'FontSize', 10, ...
                          'FontWeight', 'bold', ...
                          'Position', [0.68, 0.12, 0.30, 0.41]);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'Tag', 'qcRunBtn', ...
              'String', 'RUN QC', ...
              'Position', [20, 220, 200, 45], ...
              'FontSize', 12, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.2, 0.5, 0.8], ...
              'ForegroundColor', [1, 1, 1], ...
              'Callback', @qcRunProcessing);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'Tag', 'qcSaveBtn', ...
              'String', 'Save Current Cleaned Data', ...
              'Position', [20, 180, 200, 32], ...
              'FontSize', 9, ...
              'Enable', 'off', ...
              'Callback', @qcSaveData);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'String', 'View ICs (Topo/Activity/Spectrum)', ...
              'Position', [20, 143, 200, 32], ...
              'FontSize', 9, ...
              'Callback', @qcViewICs);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'String', 'View Data (EEGLAB)', ...
              'Position', [20, 106, 200, 32], ...
              'FontSize', 9, ...
              'Callback', @qcViewData);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Export Report (Excel)', ...
              'Position', [20, 69, 200, 32], ...
              'FontSize', 9, ...
              'Callback', @qcExportExcel);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Export Report (Text)', ...
              'Position', [20, 37, 200, 28], ...
              'FontSize', 9, ...
              'Callback', @qcExportReport);

    uicontrol('Parent', actionPanel, ...
              'Style', 'text', ...
              'Tag', 'qcStatusText', ...
              'String', 'Ready', ...
              'Position', [20, 8, 200, 22], ...
              'FontSize', 9, ...
              'HorizontalAlignment', 'center');

    % --- Requirements Info ---
    uicontrol('Parent', parent, ...
              'Style', 'text', ...
              'String', 'Requirements: EEGLAB with clean_rawdata and ICLabel plugins', ...
              'Position', [20, 5, 400, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 8, ...
              'FontAngle', 'italic');
end

%% ========================================================================
%  CONVERTER CALLBACKS (Original - unchanged)
%  ========================================================================

function tableData = createChannelTableData(appData)
    nChannels = length(appData.allChannels.indices);
    tableData = cell(nChannels, 4);

    for i = 1:nChannels
        colIdx = appData.allChannels.indices(i);
        isSelected = ismember(colIdx, appData.selectedChannels);
        tableData{i, 1} = isSelected;
        tableData{i, 2} = colIdx;
        tableData{i, 3} = appData.allChannels.names{i};

        selIdx = find(appData.selectedChannels == colIdx, 1);
        if ~isempty(selIdx) && selIdx <= length(appData.channelNames)
            tableData{i, 4} = appData.channelNames{selIdx};
        else
            tableData{i, 4} = appData.allChannels.names{i};
        end
    end
end

function loadSingleFile(hObject, ~)
    fig = ancestor(hObject, 'figure');

    [filename, pathname] = uigetfile('*.csv', 'Select WiBCI CSV file');
    if isequal(filename, 0)
        return;
    end

    appData = guidata(fig);
    appData.filesToConvert = {fullfile(pathname, filename)};
    appData.dataFolder = pathname;
    guidata(fig, appData);

    updateFileList(fig);
    logMessage(fig, sprintf('Loaded file: %s', filename));
end

function loadFolder(hObject, ~)
    fig = ancestor(hObject, 'figure');

    folderPath = uigetdir('', 'Select folder containing WiBCI CSV files');
    if isequal(folderPath, 0)
        return;
    end

    csvFiles = dir(fullfile(folderPath, '*.csv'));

    if isempty(csvFiles)
        logMessage(fig, 'No CSV files found in selected folder.');
        return;
    end

    appData = guidata(fig);
    appData.filesToConvert = cell(1, length(csvFiles));
    for i = 1:length(csvFiles)
        appData.filesToConvert{i} = fullfile(folderPath, csvFiles(i).name);
    end
    appData.dataFolder = folderPath;
    guidata(fig, appData);

    updateFileList(fig);
    logMessage(fig, sprintf('Loaded %d CSV files from folder.', length(csvFiles)));
end

function clearFileList(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);
    appData.filesToConvert = {};
    appData.dataFolder = '';
    guidata(fig, appData);

    updateFileList(fig);
    logMessage(fig, 'File list cleared.');
end

function updateFileList(fig)
    appData = guidata(fig);
    listBox = findobj(fig, 'Tag', 'fileListBox');
    folderText = findobj(fig, 'Tag', 'folderPathText');
    progressText = findobj(fig, 'Tag', 'progressText');

    if isempty(appData.filesToConvert)
        set(listBox, 'String', {'(No files loaded)'}, 'Value', 1);
        set(folderText, 'String', 'No folder selected');
        set(progressText, 'String', '0 / 0 files');
    else
        fileNames = cell(size(appData.filesToConvert));
        for i = 1:length(appData.filesToConvert)
            [~, name, ext] = fileparts(appData.filesToConvert{i});
            fileNames{i} = [name, ext];
        end
        set(listBox, 'String', fileNames, 'Value', 1);
        set(folderText, 'String', appData.dataFolder);
        set(progressText, 'String', sprintf('0 / %d files', length(appData.filesToConvert)));
    end
end

function channelTableEdit(hObject, eventData)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    tableData = get(hObject, 'Data');

    selectedIndices = [];
    selectedNames = {};
    for i = 1:size(tableData, 1)
        if tableData{i, 1}
            selectedIndices(end+1) = tableData{i, 2}; %#ok<AGROW>
            selectedNames{end+1} = tableData{i, 4}; %#ok<AGROW>
        end
    end

    appData.selectedChannels = selectedIndices;
    appData.channelNames = selectedNames;
    guidata(fig, appData);

    logMessage(fig, sprintf('Channel configuration updated: %d channels selected.', length(selectedIndices)));
end

function resetChannels(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    appData.selectedChannels = appData.defaultSelectedIndices;
    appData.channelNames = {'Fp1', 'F3', 'Fz', 'F4', 'C3', 'Cz', 'C4', 'P3', 'Pz', 'P4'};
    guidata(fig, appData);

    channelTable = findobj(fig, 'Tag', 'channelTable');
    tableData = createChannelTableData(appData);
    set(channelTable, 'Data', tableData);

    logMessage(fig, 'Channel configuration reset to defaults.');
end

function selectAllChannels(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    appData.selectedChannels = appData.allChannels.indices;
    appData.channelNames = appData.allChannels.names;
    guidata(fig, appData);

    channelTable = findobj(fig, 'Tag', 'channelTable');
    tableData = get(channelTable, 'Data');
    for i = 1:size(tableData, 1)
        tableData{i, 1} = true;
    end
    set(channelTable, 'Data', tableData);

    logMessage(fig, 'All channels selected.');
end

function deselectAllChannels(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    appData.selectedChannels = [];
    appData.channelNames = {};
    guidata(fig, appData);

    channelTable = findobj(fig, 'Tag', 'channelTable');
    tableData = get(channelTable, 'Data');
    for i = 1:size(tableData, 1)
        tableData{i, 1} = false;
    end
    set(channelTable, 'Data', tableData);

    logMessage(fig, 'All channels deselected.');
end

function fillMissingChanged(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);
    appData.fillMissingPackets = get(hObject, 'Value');
    guidata(fig, appData);
end

function sampleRateChanged(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    val = str2double(get(hObject, 'String'));
    if isnan(val) || val <= 0
        set(hObject, 'String', num2str(appData.sampleRate));
        logMessage(fig, 'Invalid sample rate. Using previous value.');
    else
        appData.sampleRate = val;
        guidata(fig, appData);
    end
end

function startConversion(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.filesToConvert)
        logMessage(fig, 'ERROR: No files loaded. Please load files first.');
        return;
    end

    if isempty(appData.selectedChannels)
        logMessage(fig, 'ERROR: No channels selected. Please select at least one channel.');
        return;
    end

    if appData.isConverting
        logMessage(fig, 'Conversion already in progress...');
        return;
    end

    appData.isConverting = true;
    guidata(fig, appData);

    set(hObject, 'Enable', 'off', 'String', 'Converting...');
    drawnow;

    outputFolder = fullfile(appData.dataFolder, 'SET_files');
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
        logMessage(fig, sprintf('Created output folder: %s', outputFolder));
    end

    totalFiles = length(appData.filesToConvert);
    successCount = 0;
    failCount = 0;
    progressText = findobj(fig, 'Tag', 'progressText');

    logMessage(fig, '========================================');
    logMessage(fig, sprintf('Starting conversion of %d files...', totalFiles));
    logMessage(fig, sprintf('Output folder: %s', outputFolder));
    logMessage(fig, sprintf('Channels: %s', strjoin(appData.channelNames, ', ')));
    logMessage(fig, '========================================');

    for i = 1:totalFiles
        filePath = appData.filesToConvert{i};
        [~, fileName, ~] = fileparts(filePath);

        set(progressText, 'String', sprintf('%d / %d files', i, totalFiles));
        drawnow;

        try
            logMessage(fig, sprintf('[%d/%d] Converting: %s', i, totalFiles, fileName));

            EEG = convertWiBCIFile(filePath, appData);

            outputFile = fullfile(outputFolder, [fileName, '.set']);

            if exist('pop_saveset', 'file')
                pop_saveset(EEG, 'filename', [fileName, '.set'], 'filepath', outputFolder);
            else
                save(outputFile, 'EEG', '-v7.3');
            end

            successCount = successCount + 1;
            logMessage(fig, sprintf('  SUCCESS: Saved to %s.set', fileName));

        catch ME
            failCount = failCount + 1;
            logMessage(fig, sprintf('  FAILED: %s - %s', fileName, ME.message));
        end

        drawnow;
    end

    logMessage(fig, '========================================');
    logMessage(fig, sprintf('Conversion complete!'));
    logMessage(fig, sprintf('  Success: %d files', successCount));
    logMessage(fig, sprintf('  Failed: %d files', failCount));
    logMessage(fig, sprintf('  Output: %s', outputFolder));
    logMessage(fig, '========================================');

    appData.isConverting = false;
    guidata(fig, appData);
    set(hObject, 'Enable', 'on', 'String', 'CONVERT');
    set(progressText, 'String', sprintf('%d / %d files (done)', totalFiles, totalFiles));
end

function EEG = convertWiBCIFile(filePath, appData)
    fillMissing = appData.fillMissingPackets;
    loadedData = loadWiBCIData_UG(filePath, fillMissing);

    eegData = loadedData.channelData(:, appData.selectedChannels);
    accelData = loadedData.channelData(:, [20, 21, 22]);
    eventData = loadedData.channelData(:, [23, 24]);

    sampleRate = appData.sampleRate;

    softEventAVector = find(eventData(:, 1) >= 100);
    softEventBVector = find(eventData(:, 2) >= 100);
    hardEventAVector = find((eventData(:, 1) == 1) | (eventData(:, 1) == 101));
    hardEventBVector = find((eventData(:, 2) == 1) | (eventData(:, 2) == 101));

    channelNames = appData.channelNames;
    nChans = length(channelNames);

    % Create channel locations using standard 10-20 coordinates
    % These are the standard theta and radius values for 10-20 system
    standardLocs = getStandard1020Locations();

    % Build channel locations structure
    filteredChannelLocs = struct([]);
    for i = 1:nChans
        chName = channelNames{i};
        filteredChannelLocs(i).labels = chName;

        % Look up in standard locations
        locIdx = find(strcmpi(standardLocs.labels, chName), 1);
        if ~isempty(locIdx)
            filteredChannelLocs(i).theta = standardLocs.theta(locIdx);
            filteredChannelLocs(i).radius = standardLocs.radius(locIdx);
            filteredChannelLocs(i).X = standardLocs.X(locIdx);
            filteredChannelLocs(i).Y = standardLocs.Y(locIdx);
            filteredChannelLocs(i).Z = standardLocs.Z(locIdx);
            filteredChannelLocs(i).sph_theta = standardLocs.sph_theta(locIdx);
            filteredChannelLocs(i).sph_phi = standardLocs.sph_phi(locIdx);
            filteredChannelLocs(i).sph_radius = 1;
            filteredChannelLocs(i).type = '';
            filteredChannelLocs(i).urchan = i;
        else
            % Default values if not found
            filteredChannelLocs(i).theta = 0;
            filteredChannelLocs(i).radius = 0;
            filteredChannelLocs(i).X = 0;
            filteredChannelLocs(i).Y = 0;
            filteredChannelLocs(i).Z = 0;
            filteredChannelLocs(i).sph_theta = 0;
            filteredChannelLocs(i).sph_phi = 0;
            filteredChannelLocs(i).sph_radius = 1;
            filteredChannelLocs(i).type = '';
            filteredChannelLocs(i).urchan = i;
        end
    end

    [~, setName, ~] = fileparts(filePath);
    [nSamples, ~] = size(eegData);

    EEG = struct();
    EEG.setname = setName;
    EEG.filename = '';
    EEG.filepath = '';
    EEG.subject = '';
    EEG.group = '';
    EEG.condition = '';
    EEG.session = [];
    EEG.comments = sprintf('WiBCI data converted on %s', datestr(now));
    EEG.nbchan = nChans;
    EEG.trials = 1;
    EEG.pnts = nSamples;
    EEG.srate = sampleRate;
    EEG.xmin = 0;
    EEG.xmax = (nSamples - 1) / sampleRate;
    EEG.times = [];
    EEG.data = permute(eegData, [2, 1]);
    EEG.icaact = [];
    EEG.icawinv = [];
    EEG.icasphere = [];
    EEG.icaweights = [];
    EEG.icachansind = [];
    EEG.chanlocs = filteredChannelLocs;
    EEG.urchanlocs = [];
    EEG.chaninfo = struct();
    EEG.ref = 'common';
    EEG.event = eegLabEventStructW(softEventAVector, softEventBVector, ...
                                    hardEventAVector, hardEventBVector);
    EEG.urevent = EEG.event;
    EEG.eventdescription = {};
    EEG.epoch = [];
    EEG.epochdescription = {};
    EEG.reject = [];
    EEG.stats = [];
    EEG.specdata = [];
    EEG.specicaact = [];
    EEG.splinefile = '';
    EEG.icasplinefile = '';
    EEG.dipfit = [];
    EEG.history = 'WIBCI_Converter_GUI';
    EEG.saved = 'no';
    EEG.etc = struct('accelData', accelData, 'eventData', eventData);
end

function logMessage(fig, msg)
    statusLog = findobj(fig, 'Tag', 'statusLog');
    currentLog = get(statusLog, 'String');

    if ischar(currentLog)
        currentLog = {currentLog};
    end

    timestamp = datestr(now, 'HH:MM:SS');
    newMsg = sprintf('[%s] %s', timestamp, msg);

    currentLog{end+1} = newMsg;

    if length(currentLog) > 100
        currentLog = currentLog(end-99:end);
    end

    set(statusLog, 'String', currentLog, 'Value', length(currentLog));
    drawnow;
end

%% ========================================================================
%  QUALITY CHECK CALLBACKS
%  ========================================================================

function qcLoadFile(hObject, ~)
    fig = ancestor(hObject, 'figure');

    [filename, pathname] = uigetfile('*.set', 'Select EEGLAB .set file');
    if isequal(filename, 0)
        return;
    end

    filePath = fullfile(pathname, filename);

    appData = guidata(fig);
    appData.qcFiles = {filePath};
    appData.qcBatchResults = {};
    appData.qcCurrentFileIdx = 1;
    guidata(fig, appData);

    qcUpdateFileList(fig);
    qcLoadCurrentFile(fig);
end

function qcLoadFolder(hObject, ~)
    fig = ancestor(hObject, 'figure');

    folderPath = uigetdir('', 'Select folder containing .set files');
    if isequal(folderPath, 0)
        return;
    end

    setFiles = dir(fullfile(folderPath, '*.set'));

    if isempty(setFiles)
        qcLog(fig, 'No .set files found in selected folder.');
        return;
    end

    appData = guidata(fig);
    appData.qcFiles = cell(1, length(setFiles));
    for i = 1:length(setFiles)
        appData.qcFiles{i} = fullfile(folderPath, setFiles(i).name);
    end
    appData.qcBatchResults = {};
    appData.qcCurrentFileIdx = 1;
    guidata(fig, appData);

    qcUpdateFileList(fig);
    qcLoadCurrentFile(fig);

    qcLog(fig, sprintf('Loaded %d .set files for batch processing.', length(setFiles)));
end

function qcClearFiles(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    appData.qcFiles = {};
    appData.qcEEG = [];
    appData.qcFilePath = '';
    appData.qcBatchResults = {};
    appData.qcCurrentFileIdx = 0;
    guidata(fig, appData);

    qcUpdateFileList(fig);
    qcResetMetrics(fig);

    fileText = findobj(fig, 'Tag', 'qcFileText');
    set(fileText, 'String', 'No files loaded');
    infoText = findobj(fig, 'Tag', 'qcDataInfo');
    set(infoText, 'String', '');

    qcLog(fig, 'File list cleared.');
end

function qcUpdateFileList(fig)
    appData = guidata(fig);
    listBox = findobj(fig, 'Tag', 'qcFileList');

    if isempty(appData.qcFiles)
        set(listBox, 'String', {'(No files loaded)'}, 'Value', 1);
    else
        fileNames = cell(size(appData.qcFiles));
        for i = 1:length(appData.qcFiles)
            [~, name, ext] = fileparts(appData.qcFiles{i});
            fileNames{i} = [name, ext];
        end
        val = min(appData.qcCurrentFileIdx, length(fileNames));
        if val < 1, val = 1; end
        set(listBox, 'String', fileNames, 'Value', val);
    end
end

function qcFileListSelect(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    idx = get(hObject, 'Value');
    if idx > 0 && idx <= length(appData.qcFiles)
        appData.qcCurrentFileIdx = idx;
        guidata(fig, appData);
        qcLoadCurrentFile(fig);
    end
end

function qcLoadCurrentFile(fig)
    appData = guidata(fig);

    if isempty(appData.qcFiles) || appData.qcCurrentFileIdx < 1
        return;
    end

    filePath = appData.qcFiles{appData.qcCurrentFileIdx};
    [pathname, filename, ext] = fileparts(filePath);
    filename = [filename, ext];

    qcLog(fig, sprintf('Loading: %s', filename));
    qcSetStatus(fig, 'Loading...');

    try
        if ~exist('pop_loadset', 'file')
            qcLog(fig, 'ERROR: EEGLAB not found. Please add EEGLAB to path.');
            qcSetStatus(fig, 'EEGLAB not found');
            return;
        end

        EEG = pop_loadset('filename', filename, 'filepath', pathname);
        EEG = eeg_checkset(EEG);

        appData.qcEEG = EEG;
        appData.qcFilePath = filePath;
        guidata(fig, appData);

        % Update UI
        fileText = findobj(fig, 'Tag', 'qcFileText');
        if length(appData.qcFiles) > 1
            set(fileText, 'String', sprintf('[%d/%d] %s', appData.qcCurrentFileIdx, ...
                                            length(appData.qcFiles), filePath));
        else
            set(fileText, 'String', filePath);
        end

        infoText = findobj(fig, 'Tag', 'qcDataInfo');
        infoStr = sprintf('%d channels, %d samples, %.1f sec, %d Hz', ...
                          EEG.nbchan, EEG.pnts, EEG.xmax, EEG.srate);
        set(infoText, 'String', infoStr);

        qcLog(fig, sprintf('  Channels: %d, Samples: %d, Duration: %.1f sec', ...
                           EEG.nbchan, EEG.pnts, EEG.xmax));
        qcSetStatus(fig, 'File loaded');

        qcResetMetrics(fig);

    catch ME
        qcLog(fig, sprintf('ERROR loading file: %s', ME.message));
        qcSetStatus(fig, 'Load failed');
    end
end

function qcRunProcessing(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.qcFiles)
        qcLog(fig, 'ERROR: No files loaded. Please load .set file(s) first.');
        return;
    end

    if appData.qcIsProcessing
        qcLog(fig, 'Processing already in progress...');
        return;
    end

    appData.qcIsProcessing = true;
    appData.qcBatchResults = {};
    guidata(fig, appData);

    set(hObject, 'Enable', 'off', 'String', 'Processing...');
    drawnow;

    totalFiles = length(appData.qcFiles);
    autoSave = get(findobj(fig, 'Tag', 'qcAutoSave'), 'Value');

    qcLog(fig, '========================================');
    qcLog(fig, sprintf('Starting Quality Check on %d file(s)...', totalFiles));
    qcLog(fig, '========================================');

    for fileIdx = 1:totalFiles
        appData = guidata(fig);
        appData.qcCurrentFileIdx = fileIdx;
        guidata(fig, appData);

        qcUpdateFileList(fig);
        qcLoadCurrentFile(fig);

        appData = guidata(fig);
        if isempty(appData.qcEEG)
            qcLog(fig, sprintf('[%d/%d] SKIP: Failed to load file', fileIdx, totalFiles));
            continue;
        end

        qcLog(fig, sprintf('[%d/%d] Processing: %s', fileIdx, totalFiles, ...
                           appData.qcEEG.setname));

        try
            [EEG, metrics] = qcProcessSingleFile(fig, appData.qcEEG);

            % Store results
            appData = guidata(fig);
            result = struct();
            result.filename = appData.qcEEG.setname;
            result.filepath = appData.qcFilePath;
            result.metrics = metrics;
            result.success = true;
            appData.qcBatchResults{fileIdx} = result;

            % Update current EEG
            appData.qcEEG = EEG;
            appData.qcMetrics = metrics;
            guidata(fig, appData);

            % Update metrics display
            qcUpdateMetrics(fig, metrics);

            % Auto-save if enabled
            if autoSave
                [savePath, saveName, ~] = fileparts(appData.qcFilePath);
                cleanedFolder = fullfile(savePath, 'Cleaned_files');
                if ~exist(cleanedFolder, 'dir')
                    mkdir(cleanedFolder);
                end
                cleanedName = [saveName, '_cleaned.set'];
                pop_saveset(EEG, 'filename', cleanedName, 'filepath', cleanedFolder);
                qcLog(fig, sprintf('  Saved: %s', cleanedName));
            end

            qcLog(fig, sprintf('  Result: %s', metrics.overallQuality));

        catch ME
            qcLog(fig, sprintf('  ERROR: %s', ME.message));
            appData = guidata(fig);
            result = struct();
            result.filename = appData.qcEEG.setname;
            result.filepath = appData.qcFilePath;
            result.metrics = struct('overallQuality', 'ERROR', 'error', ME.message);
            result.success = false;
            appData.qcBatchResults{fileIdx} = result;
            guidata(fig, appData);
        end

        drawnow;
    end

    % Summary
    qcLog(fig, '========================================');
    qcLog(fig, 'Batch Processing Complete!');

    successCount = sum(cellfun(@(x) x.success, appData.qcBatchResults));
    qcLog(fig, sprintf('  Processed: %d / %d files', successCount, totalFiles));

    if autoSave
        qcLog(fig, sprintf('  Output folder: Cleaned_files'));
    end
    qcLog(fig, '========================================');

    % Enable save button
    saveBtn = findobj(fig, 'Tag', 'qcSaveBtn');
    set(saveBtn, 'Enable', 'on');

    appData.qcIsProcessing = false;
    guidata(fig, appData);
    set(hObject, 'Enable', 'on', 'String', 'RUN QC');
    qcSetStatus(fig, 'Complete');
end

function [EEG, metrics] = qcProcessSingleFile(fig, EEG)
    % Process a single EEG file and return cleaned data with metrics

    metrics = struct();

    % Store original data info
    origVar = var(EEG.data(:));

    % Get options
    doFilter = get(findobj(fig, 'Tag', 'qcFilterCheck'), 'Value');
    doASR = get(findobj(fig, 'Tag', 'qcASRCheck'), 'Value');
    doICA = get(findobj(fig, 'Tag', 'qcICACheck'), 'Value');

    % 1. Filtering
    if doFilter
        qcLog(fig, '  Applying bandpass filter...');
        qcSetStatus(fig, 'Filtering...');

        highpass = str2double(get(findobj(fig, 'Tag', 'qcHighpass'), 'String'));
        lowpass = str2double(get(findobj(fig, 'Tag', 'qcLowpass'), 'String'));

        if exist('pop_eegfiltnew', 'file')
            EEG = pop_eegfiltnew(EEG, highpass, lowpass);
        elseif exist('pop_basicfilter', 'file')
            EEG = pop_basicfilter(EEG, 1:EEG.nbchan, 'Cutoff', [highpass lowpass], ...
                                  'Design', 'butter', 'Filter', 'bandpass');
        else
            qcLog(fig, '    WARNING: Filter functions not found, skipping...');
        end
        metrics.filterApplied = true;
        metrics.highpass = highpass;
        metrics.lowpass = lowpass;
    else
        metrics.filterApplied = false;
    end

    % 2. ASR
    metrics.asrApplied = false;
    metrics.asrCutoff = [];

    if doASR
        qcLog(fig, '  Applying ASR cleaning...');
        qcSetStatus(fig, 'Running ASR...');

        asrCutoff = str2double(get(findobj(fig, 'Tag', 'qcASRCutoff'), 'String'));

        % Try different ASR methods
        asrSuccess = false;

        % Method 1: Try clean_asr directly (preferred)
        if exist('clean_asr', 'file') == 2 && ~asrSuccess
            try
                qcLog(fig, '    Using clean_asr...');
                EEG.data = double(EEG.data);  % Ensure double precision
                EEG = clean_asr(EEG, asrCutoff);
                asrSuccess = true;
                qcLog(fig, sprintf('    ASR applied (cutoff: %d)', asrCutoff));
            catch ME
                qcLog(fig, sprintf('    clean_asr failed: %s', ME.message));
            end
        end

        % Method 2: Try clean_rawdata with ASR only
        if exist('clean_rawdata', 'file') == 2 && ~asrSuccess
            try
                qcLog(fig, '    Using clean_rawdata...');
                EEG.data = double(EEG.data);  % Ensure double precision

                % Store original data size
                origPnts = EEG.pnts;

                % Run clean_rawdata with only burst correction (ASR)
                EEG = clean_rawdata(EEG, ...
                    'FlatlineCriterion', -1, ...
                    'ChannelCriterion', -1, ...
                    'LineNoiseCriterion', -1, ...
                    'Highpass', -1, ...
                    'BurstCriterion', asrCutoff, ...
                    'WindowCriterion', -1, ...
                    'BurstRejection', 'off', ...
                    'Distance', 'Euclidian');

                asrSuccess = true;
                qcLog(fig, sprintf('    ASR applied via clean_rawdata (cutoff: %d)', asrCutoff));
            catch ME
                qcLog(fig, sprintf('    clean_rawdata failed: %s', ME.message));
            end
        end

        % Method 3: Try vis_artifacts approach (alternative)
        if exist('clean_artifacts', 'file') == 2 && ~asrSuccess
            try
                qcLog(fig, '    Using clean_artifacts...');
                EEG.data = double(EEG.data);
                EEG = clean_artifacts(EEG, ...
                    'FlatlineCriterion', 'off', ...
                    'ChannelCriterion', 'off', ...
                    'LineNoiseCriterion', 'off', ...
                    'Highpass', 'off', ...
                    'BurstCriterion', asrCutoff, ...
                    'WindowCriterion', 'off');
                asrSuccess = true;
                qcLog(fig, sprintf('    ASR applied via clean_artifacts (cutoff: %d)', asrCutoff));
            catch ME
                qcLog(fig, sprintf('    clean_artifacts failed: %s', ME.message));
            end
        end

        if asrSuccess
            metrics.asrApplied = true;
            metrics.asrCutoff = asrCutoff;
        else
            qcLog(fig, '    WARNING: All ASR methods failed. Is clean_rawdata plugin installed?');
            qcLog(fig, '    Install via EEGLAB: File > Manage EEGLAB extensions > clean_rawdata');
            metrics.asrApplied = false;
        end
    end

    % Calculate retained variance
    newVar = var(EEG.data(:));
    metrics.retainedVariance = (newVar / origVar) * 100;

    % 3. ICA and ICLabel
    metrics.goodICs = 0;
    metrics.totalICs = 0;
    metrics.removedICs = 0;
    metrics.icaApplied = false;

    if doICA
        qcLog(fig, '  Running ICA decomposition...');
        qcSetStatus(fig, 'Running ICA...');

        if exist('pop_runica', 'file')
            try
                EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1);
                metrics.totalICs = size(EEG.icaweights, 1);
                metrics.icaApplied = true;

                % Run ICLabel
                if exist('iclabel', 'file') || exist('pop_iclabel', 'file')
                    qcLog(fig, '  Running ICLabel classification...');
                    qcSetStatus(fig, 'Running ICLabel...');

                    EEG = pop_iclabel(EEG, 'default');

                    icThreshold = str2double(get(findobj(fig, 'Tag', 'qcICThreshold'), 'String'));

                    % ICLabel categories
                    brainProb = EEG.etc.ic_classification.ICLabel.classifications(:, 1);
                    artifactProb = sum(EEG.etc.ic_classification.ICLabel.classifications(:, 2:end), 2);

                    metrics.goodICs = sum(brainProb > 0.5);
                    icsToRemove = find(artifactProb > icThreshold);
                    metrics.removedICs = length(icsToRemove);
                    metrics.icThreshold = icThreshold;

                    % Store IC classifications for viewing
                    metrics.icClassifications = EEG.etc.ic_classification.ICLabel.classifications;

                    if ~isempty(icsToRemove)
                        EEG = pop_subcomp(EEG, icsToRemove, 0);
                        qcLog(fig, sprintf('    Removed %d artifact components', length(icsToRemove)));
                    end
                else
                    qcLog(fig, '    WARNING: ICLabel not found, skipping...');
                end
            catch ME
                qcLog(fig, sprintf('    ICA error: %s', ME.message));
            end
        else
            qcLog(fig, '    WARNING: pop_runica not found, skipping ICA...');
        end
    end

    % Calculate additional metrics
    metrics.badChannels = 0;
    metrics.dataRank = rank(double(EEG.data'));
    metrics.nbchan = EEG.nbchan;
    metrics.pnts = EEG.pnts;
    metrics.srate = EEG.srate;
    metrics.duration = EEG.xmax;

    % Estimate SNR
    signalVar = var(mean(EEG.data, 1));
    noiseVar = mean(var(EEG.data, 0, 2));
    metrics.snr = 10 * log10(signalVar / max(noiseVar, eps));

    % Calculate overall quality
    metrics.overallQuality = calculateOverallQuality(metrics, EEG);
end

function quality = calculateOverallQuality(metrics, EEG)
    score = 0;
    maxScore = 0;

    % Retained variance (weight: 25)
    maxScore = maxScore + 25;
    if metrics.retainedVariance >= 90
        score = score + 25;
    elseif metrics.retainedVariance >= 80
        score = score + 20;
    elseif metrics.retainedVariance >= 70
        score = score + 15;
    elseif metrics.retainedVariance >= 60
        score = score + 10;
    end

    % Good ICs ratio (weight: 30)
    if metrics.totalICs > 0
        maxScore = maxScore + 30;
        goodRatio = metrics.goodICs / metrics.totalICs;
        if goodRatio >= 0.7
            score = score + 30;
        elseif goodRatio >= 0.5
            score = score + 22;
        elseif goodRatio >= 0.3
            score = score + 15;
        else
            score = score + 5;
        end
    end

    % Data rank (weight: 20)
    maxScore = maxScore + 20;
    rankRatio = metrics.dataRank / EEG.nbchan;
    if rankRatio >= 0.9
        score = score + 20;
    elseif rankRatio >= 0.7
        score = score + 15;
    elseif rankRatio >= 0.5
        score = score + 10;
    end

    % SNR (weight: 25)
    maxScore = maxScore + 25;
    if metrics.snr >= 10
        score = score + 25;
    elseif metrics.snr >= 5
        score = score + 20;
    elseif metrics.snr >= 0
        score = score + 15;
    elseif metrics.snr >= -5
        score = score + 10;
    end

    percentage = (score / maxScore) * 100;

    if percentage >= 85
        quality = 'EXCELLENT';
    elseif percentage >= 70
        quality = 'GOOD';
    elseif percentage >= 50
        quality = 'MODERATE';
    else
        quality = 'POOR';
    end
end

function qcUpdateMetrics(fig, metrics)
    qualityText = findobj(fig, 'Tag', 'qcOverallQuality');
    set(qualityText, 'String', metrics.overallQuality);

    switch metrics.overallQuality
        case 'EXCELLENT'
            set(qualityText, 'ForegroundColor', [0, 0.6, 0]);
        case 'GOOD'
            set(qualityText, 'ForegroundColor', [0, 0.4, 0.8]);
        case 'MODERATE'
            set(qualityText, 'ForegroundColor', [0.8, 0.6, 0]);
        case 'POOR'
            set(qualityText, 'ForegroundColor', [0.8, 0, 0]);
        otherwise
            set(qualityText, 'ForegroundColor', [0.5, 0.5, 0.5]);
    end

    set(findobj(fig, 'Tag', 'qcVariance'), 'String', sprintf('%.1f%%', metrics.retainedVariance));

    if metrics.totalICs > 0
        set(findobj(fig, 'Tag', 'qcGoodICs'), 'String', ...
            sprintf('%d / %d (%.0f%%)', metrics.goodICs, metrics.totalICs, ...
                    (metrics.goodICs/metrics.totalICs)*100));
    else
        set(findobj(fig, 'Tag', 'qcGoodICs'), 'String', 'N/A');
    end

    set(findobj(fig, 'Tag', 'qcBadChans'), 'String', sprintf('%d', metrics.badChannels));
    set(findobj(fig, 'Tag', 'qcRank'), 'String', sprintf('%d', metrics.dataRank));
    set(findobj(fig, 'Tag', 'qcSNR'), 'String', sprintf('%.1f dB', metrics.snr));
end

function qcResetMetrics(fig)
    set(findobj(fig, 'Tag', 'qcOverallQuality'), 'String', '---', 'ForegroundColor', [0, 0, 0]);
    set(findobj(fig, 'Tag', 'qcVariance'), 'String', '---');
    set(findobj(fig, 'Tag', 'qcGoodICs'), 'String', '---');
    set(findobj(fig, 'Tag', 'qcBadChans'), 'String', '---');
    set(findobj(fig, 'Tag', 'qcRank'), 'String', '---');
    set(findobj(fig, 'Tag', 'qcSNR'), 'String', '---');

    saveBtn = findobj(fig, 'Tag', 'qcSaveBtn');
    set(saveBtn, 'Enable', 'off');
end

function qcSaveData(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.qcEEG)
        qcLog(fig, 'ERROR: No data to save.');
        return;
    end

    [origPath, origName, ~] = fileparts(appData.qcFilePath);
    defaultName = [origName, '_cleaned.set'];

    [filename, pathname] = uiputfile('*.set', 'Save Cleaned Data', fullfile(origPath, defaultName));
    if isequal(filename, 0)
        return;
    end

    try
        qcLog(fig, sprintf('Saving to: %s', filename));
        pop_saveset(appData.qcEEG, 'filename', filename, 'filepath', pathname);
        qcLog(fig, 'Data saved successfully.');
        qcSetStatus(fig, 'Saved');
    catch ME
        qcLog(fig, sprintf('ERROR saving: %s', ME.message));
    end
end

function qcViewICs(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.qcEEG)
        qcLog(fig, 'ERROR: No data loaded.');
        return;
    end

    EEG = appData.qcEEG;

    if isempty(EEG.icaweights)
        qcLog(fig, 'ERROR: No ICA decomposition found. Run QC with ICA enabled first.');
        return;
    end

    % Create IC viewer window
    createICViewer(EEG, fig);
end

function createICViewer(EEG, parentFig)
    % Create a window to view IC properties

    nICs = size(EEG.icaweights, 1);

    % Create figure
    icFig = figure('Name', sprintf('IC Viewer - %s', EEG.setname), ...
                   'NumberTitle', 'off', ...
                   'Position', [150, 100, 1000, 700], ...
                   'MenuBar', 'none', ...
                   'ToolBar', 'figure');

    % Store EEG in figure
    setappdata(icFig, 'EEG', EEG);
    setappdata(icFig, 'currentIC', 1);

    % Create UI
    % --- Control Panel ---
    controlPanel = uipanel('Parent', icFig, ...
                           'Title', 'IC Selection', ...
                           'Position', [0.01, 0.85, 0.98, 0.14]);

    uicontrol('Parent', controlPanel, ...
              'Style', 'text', ...
              'String', 'Select IC:', ...
              'Position', [20, 50, 60, 20], ...
              'FontSize', 10);

    icList = arrayfun(@(x) sprintf('IC %d', x), 1:nICs, 'UniformOutput', false);
    icSelector = uicontrol('Parent', controlPanel, ...
              'Style', 'popupmenu', ...
              'String', icList, ...
              'Position', [85, 48, 100, 25], ...
              'FontSize', 9, ...
              'Callback', @(h,e) updateICViewCallback(icFig));

    uicontrol('Parent', controlPanel, ...
              'Style', 'pushbutton', ...
              'String', '< Prev', ...
              'Position', [200, 48, 70, 28], ...
              'Callback', @(h,e) changeICCallback(icFig, -1));

    uicontrol('Parent', controlPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Next >', ...
              'Position', [280, 48, 70, 28], ...
              'Callback', @(h,e) changeICCallback(icFig, 1));

    % ICLabel info
    icLabelText = [];
    if isfield(EEG.etc, 'ic_classification') && isfield(EEG.etc.ic_classification, 'ICLabel')
        icLabelText = uicontrol('Parent', controlPanel, ...
                  'Style', 'text', ...
                  'String', '', ...
                  'Position', [380, 45, 400, 30], ...
                  'FontSize', 10, ...
                  'HorizontalAlignment', 'left');
    end

    uicontrol('Parent', controlPanel, ...
              'Style', 'pushbutton', ...
              'String', 'View All Topoplots', ...
              'Position', [800, 48, 130, 28], ...
              'Callback', @(h,e) viewAllTopos(icFig));

    % --- Topoplot Panel ---
    topoPanel = uipanel('Parent', icFig, ...
                        'Title', 'Scalp Map', ...
                        'Position', [0.01, 0.42, 0.32, 0.42]);

    topoAx = axes('Parent', topoPanel, ...
                  'Position', [0.1, 0.1, 0.8, 0.85]);

    % --- Activity Panel ---
    actPanel = uipanel('Parent', icFig, ...
                       'Title', 'IC Activity (Time Series)', ...
                       'Position', [0.34, 0.42, 0.65, 0.42]);

    actAx = axes('Parent', actPanel, ...
                 'Position', [0.08, 0.15, 0.88, 0.75]);

    % --- Spectrum Panel ---
    specPanel = uipanel('Parent', icFig, ...
                        'Title', 'Power Spectrum', ...
                        'Position', [0.01, 0.02, 0.48, 0.38]);

    specAx = axes('Parent', specPanel, ...
                  'Position', [0.12, 0.18, 0.82, 0.72]);

    % --- Properties Panel ---
    propPanel = uipanel('Parent', icFig, ...
                        'Title', 'IC Properties', ...
                        'Position', [0.51, 0.02, 0.48, 0.38]);

    propText = uicontrol('Parent', propPanel, ...
              'Style', 'text', ...
              'String', '', ...
              'Position', [15, 10, 440, 200], ...
              'FontSize', 9, ...
              'HorizontalAlignment', 'left', ...
              'Max', 2);

    % Store handles in appdata for later access
    handles = struct();
    handles.icSelector = icSelector;
    handles.icLabelText = icLabelText;
    handles.topoAx = topoAx;
    handles.actAx = actAx;
    handles.specAx = specAx;
    handles.propText = propText;
    setappdata(icFig, 'handles', handles);

    % Initial view
    updateICViewCallback(icFig);
end

function changeICCallback(icFig, delta)
    if ~isvalid(icFig)
        return;
    end

    EEG = getappdata(icFig, 'EEG');
    handles = getappdata(icFig, 'handles');
    nICs = size(EEG.icaweights, 1);

    currentIC = get(handles.icSelector, 'Value');

    newIC = currentIC + delta;
    if newIC < 1, newIC = nICs; end
    if newIC > nICs, newIC = 1; end

    set(handles.icSelector, 'Value', newIC);
    updateICViewCallback(icFig);
end

function updateICViewCallback(icFig)
    if ~isvalid(icFig)
        return;
    end

    EEG = getappdata(icFig, 'EEG');
    handles = getappdata(icFig, 'handles');

    icNum = get(handles.icSelector, 'Value');

    % Update topoplot
    axes(handles.topoAx);
    cla(handles.topoAx);

    try
        hasValidLocs = ~isempty(EEG.chanlocs) && ...
                       isfield(EEG.chanlocs, 'theta') && ...
                       ~isempty([EEG.chanlocs.theta]);
        if hasValidLocs
            topoplot(EEG.icawinv(:, icNum), EEG.chanlocs, 'electrodes', 'on');
            title(handles.topoAx, sprintf('IC %d', icNum));
        else
            cla(handles.topoAx);
            text(handles.topoAx, 0.5, 0.5, 'No channel locations', ...
                 'HorizontalAlignment', 'center', 'Units', 'normalized');
            title(handles.topoAx, sprintf('IC %d', icNum));
        end
    catch ME
        cla(handles.topoAx);
        text(handles.topoAx, 0.5, 0.5, sprintf('Topoplot error:\n%s', ME.message), ...
             'HorizontalAlignment', 'center', 'Units', 'normalized', 'FontSize', 8);
    end

    % Compute IC activations if not available
    if isempty(EEG.icaact)
        icaact = (EEG.icaweights * EEG.icasphere) * EEG.data;
    else
        icaact = EEG.icaact;
    end

    % Update activity plot
    axes(handles.actAx);
    cla(handles.actAx);

    try
        maxSamples = min(EEG.srate * 10, EEG.pnts);
        timeVec = (0:maxSamples-1) / EEG.srate;
        plot(handles.actAx, timeVec, icaact(icNum, 1:maxSamples), 'b', 'LineWidth', 0.5);
        xlabel(handles.actAx, 'Time (s)');
        ylabel(handles.actAx, 'Amplitude');
        title(handles.actAx, sprintf('IC %d Activity', icNum));
        xlim(handles.actAx, [0, timeVec(end)]);
        grid(handles.actAx, 'on');
    catch ME
        text(handles.actAx, 0.5, 0.5, sprintf('Activity error:\n%s', ME.message), ...
             'HorizontalAlignment', 'center', 'Units', 'normalized');
    end

    % Update spectrum
    axes(handles.specAx);
    cla(handles.specAx);

    try
        nfft = min(EEG.srate * 2, EEG.pnts);
        [pxx, f] = pwelch(double(icaact(icNum, :)), hanning(nfft), nfft/2, nfft, EEG.srate);

        fMax = min(50, EEG.srate/2);
        fIdx = f <= fMax;

        plot(handles.specAx, f(fIdx), 10*log10(pxx(fIdx)), 'b', 'LineWidth', 1.5);
        xlabel(handles.specAx, 'Frequency (Hz)');
        ylabel(handles.specAx, 'Power (dB)');
        title(handles.specAx, sprintf('IC %d Power Spectrum', icNum));
        xlim(handles.specAx, [0, fMax]);
        grid(handles.specAx, 'on');
    catch ME
        text(handles.specAx, 0.5, 0.5, sprintf('Spectrum error:\n%s', ME.message), ...
             'HorizontalAlignment', 'center', 'Units', 'normalized');
    end

    % Update properties text
    propsStr = sprintf('IC %d Properties:\n\n', icNum);
    propsStr = [propsStr, sprintf('Variance accounted for: %.2f%%\n', ...
                                   100 * var(icaact(icNum, :)) / sum(var(icaact, 0, 2)))];

    % ICLabel classification
    if isfield(EEG.etc, 'ic_classification') && isfield(EEG.etc.ic_classification, 'ICLabel')
        classes = EEG.etc.ic_classification.ICLabel.classes;
        probs = EEG.etc.ic_classification.ICLabel.classifications(icNum, :);

        propsStr = [propsStr, sprintf('\nICLabel Classification:\n')];
        [sortedProbs, sortIdx] = sort(probs, 'descend');
        for i = 1:min(4, length(classes))
            propsStr = [propsStr, sprintf('  %s: %.1f%%\n', classes{sortIdx(i)}, sortedProbs(i)*100)];
        end

        % Update ICLabel text in control panel
        if ~isempty(handles.icLabelText) && isvalid(handles.icLabelText)
            [~, maxIdx] = max(probs);
            labelStr = sprintf('Classification: %s (%.1f%%)', classes{maxIdx}, probs(maxIdx)*100);
            set(handles.icLabelText, 'String', labelStr);

            if maxIdx == 1  % Brain
                set(handles.icLabelText, 'ForegroundColor', [0, 0.6, 0]);
            else  % Artifact
                set(handles.icLabelText, 'ForegroundColor', [0.8, 0, 0]);
            end
        end
    end

    set(handles.propText, 'String', propsStr);
end

function viewAllTopos(icFig)
    EEG = getappdata(icFig, 'EEG');
    nICs = size(EEG.icaweights, 1);

    % Create new figure for all topoplots
    allFig = figure('Name', sprintf('All IC Topoplots - %s', EEG.setname), ...
                    'NumberTitle', 'off', ...
                    'Position', [100, 100, 1200, 800]);

    % Calculate grid size
    nCols = ceil(sqrt(nICs));
    nRows = ceil(nICs / nCols);

    % Check if we have valid channel locations
    hasValidLocs = ~isempty(EEG.chanlocs) && ...
                   isfield(EEG.chanlocs, 'theta') && ...
                   ~isempty([EEG.chanlocs.theta]);

    for i = 1:nICs
        subplot(nRows, nCols, i);

        try
            if hasValidLocs
                topoplot(EEG.icawinv(:, i), EEG.chanlocs, 'electrodes', 'off');

                % Color code title based on ICLabel
                titleColor = [0, 0, 0];
                if isfield(EEG.etc, 'ic_classification') && isfield(EEG.etc.ic_classification, 'ICLabel')
                    probs = EEG.etc.ic_classification.ICLabel.classifications(i, :);
                    [~, maxIdx] = max(probs);
                    if maxIdx == 1  % Brain
                        titleColor = [0, 0.6, 0];
                    else  % Artifact
                        titleColor = [0.8, 0, 0];
                    end
                end
                title(sprintf('IC%d', i), 'Color', titleColor, 'FontSize', 8);
            else
                axis off;
                text(0.5, 0.5, sprintf('IC%d\n(no locs)', i), ...
                     'HorizontalAlignment', 'center', 'Units', 'normalized');
            end
        catch
            axis off;
            text(0.5, 0.5, sprintf('IC%d\nerror', i), ...
                 'HorizontalAlignment', 'center', 'Units', 'normalized');
        end
    end

    if hasValidLocs
        sgtitle(sprintf('All ICs - Green=Brain, Red=Artifact (%s)', EEG.setname));
    else
        sgtitle(sprintf('All ICs - No channel locations (%s)', EEG.setname));
    end
end

function qcViewData(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.qcEEG)
        qcLog(fig, 'ERROR: No data loaded.');
        return;
    end

    try
        if exist('pop_eegplot', 'file')
            pop_eegplot(appData.qcEEG, 1, 1, 1);
            qcLog(fig, 'Opened EEGLAB data viewer.');
        else
            qcLog(fig, 'ERROR: EEGLAB viewer not available.');
        end
    catch ME
        qcLog(fig, sprintf('ERROR: %s', ME.message));
    end
end

function qcExportExcel(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.qcBatchResults)
        qcLog(fig, 'ERROR: No results to export. Run QC first.');
        return;
    end

    % Get save location
    if ~isempty(appData.qcFiles)
        [defaultPath, ~, ~] = fileparts(appData.qcFiles{1});
    else
        defaultPath = pwd;
    end

    defaultName = sprintf('QC_Report_%s.xlsx', datestr(now, 'yyyy-mm-dd_HHMMSS'));
    [filename, pathname] = uiputfile('*.xlsx', 'Export QC Report to Excel', ...
                                      fullfile(defaultPath, defaultName));
    if isequal(filename, 0)
        return;
    end

    try
        qcLog(fig, 'Exporting to Excel...');

        % Build table data
        nFiles = length(appData.qcBatchResults);

        % Column headers
        headers = {'Filename', 'Quality', 'Retained_Var_pct', 'Good_ICs', 'Total_ICs', ...
                   'Removed_ICs', 'Bad_Channels', 'Data_Rank', 'SNR_dB', ...
                   'Channels', 'Samples', 'Duration_sec', 'SampleRate_Hz', ...
                   'Filter_Applied', 'Highpass_Hz', 'Lowpass_Hz', ...
                   'ASR_Applied', 'ASR_Cutoff', 'ICA_Applied', 'Filepath'};

        % Initialize data cell array
        data = cell(nFiles, length(headers));

        for i = 1:nFiles
            result = appData.qcBatchResults{i};
            m = result.metrics;

            data{i, 1} = result.filename;
            data{i, 2} = m.overallQuality;

            if result.success
                data{i, 3} = m.retainedVariance;
                data{i, 4} = m.goodICs;
                data{i, 5} = m.totalICs;
                data{i, 6} = m.removedICs;
                data{i, 7} = m.badChannels;
                data{i, 8} = m.dataRank;
                data{i, 9} = m.snr;
                data{i, 10} = m.nbchan;
                data{i, 11} = m.pnts;
                data{i, 12} = m.duration;
                data{i, 13} = m.srate;

                if isfield(m, 'filterApplied')
                    data{i, 14} = m.filterApplied;
                    if m.filterApplied
                        data{i, 15} = m.highpass;
                        data{i, 16} = m.lowpass;
                    end
                end

                if isfield(m, 'asrApplied')
                    data{i, 17} = m.asrApplied;
                    if m.asrApplied && isfield(m, 'asrCutoff')
                        data{i, 18} = m.asrCutoff;
                    end
                end

                data{i, 19} = m.icaApplied;
            else
                data{i, 3} = 'ERROR';
            end

            data{i, 20} = result.filepath;
        end

        % Create table
        T = cell2table(data, 'VariableNames', headers);

        % Write to Excel
        writetable(T, fullfile(pathname, filename), 'Sheet', 'QC_Results');

        % Add summary sheet
        summaryData = {
            'QC Report Summary', '';
            'Generated', datestr(now);
            'Total Files', nFiles;
            'Excellent', sum(strcmp(data(:, 2), 'EXCELLENT'));
            'Good', sum(strcmp(data(:, 2), 'GOOD'));
            'Moderate', sum(strcmp(data(:, 2), 'MODERATE'));
            'Poor', sum(strcmp(data(:, 2), 'POOR'));
            'Errors', sum(strcmp(data(:, 2), 'ERROR'));
        };

        writecell(summaryData, fullfile(pathname, filename), 'Sheet', 'Summary');

        qcLog(fig, sprintf('Excel report saved: %s', filename));
        qcSetStatus(fig, 'Excel exported');

    catch ME
        qcLog(fig, sprintf('ERROR exporting Excel: %s', ME.message));
    end
end

function qcExportReport(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.qcBatchResults) && (~isfield(appData, 'qcMetrics') || isempty(appData.qcMetrics))
        qcLog(fig, 'ERROR: No quality metrics to export. Run QC first.');
        return;
    end

    if ~isempty(appData.qcFiles)
        [defaultPath, ~, ~] = fileparts(appData.qcFiles{1});
    else
        defaultPath = pwd;
    end

    defaultName = sprintf('QC_Report_%s.txt', datestr(now, 'yyyy-mm-dd_HHMMSS'));
    [filename, pathname] = uiputfile('*.txt', 'Export QC Report', fullfile(defaultPath, defaultName));
    if isequal(filename, 0)
        return;
    end

    try
        fid = fopen(fullfile(pathname, filename), 'w');

        fprintf(fid, 'WiBCI EEG Quality Check Report\n');
        fprintf(fid, '==============================\n\n');
        fprintf(fid, 'Date: %s\n', datestr(now));
        fprintf(fid, 'Total Files: %d\n\n', length(appData.qcBatchResults));

        for i = 1:length(appData.qcBatchResults)
            result = appData.qcBatchResults{i};
            m = result.metrics;

            fprintf(fid, '----------------------------------------\n');
            fprintf(fid, 'File %d: %s\n', i, result.filename);
            fprintf(fid, '----------------------------------------\n');

            if result.success
                fprintf(fid, 'Overall Quality: %s\n', m.overallQuality);
                fprintf(fid, 'Retained Variance: %.1f%%\n', m.retainedVariance);
                fprintf(fid, 'Good ICs: %d / %d\n', m.goodICs, m.totalICs);
                fprintf(fid, 'Removed ICs: %d\n', m.removedICs);
                fprintf(fid, 'Data Rank: %d\n', m.dataRank);
                fprintf(fid, 'SNR: %.1f dB\n', m.snr);
                fprintf(fid, 'Channels: %d, Samples: %d, Duration: %.1f sec\n', ...
                        m.nbchan, m.pnts, m.duration);
            else
                fprintf(fid, 'ERROR: %s\n', m.error);
            end
            fprintf(fid, '\n');
        end

        % Summary
        fprintf(fid, '========================================\n');
        fprintf(fid, 'SUMMARY\n');
        fprintf(fid, '========================================\n');

        qualities = cellfun(@(x) x.metrics.overallQuality, appData.qcBatchResults, 'UniformOutput', false);
        fprintf(fid, 'Excellent: %d\n', sum(strcmp(qualities, 'EXCELLENT')));
        fprintf(fid, 'Good: %d\n', sum(strcmp(qualities, 'GOOD')));
        fprintf(fid, 'Moderate: %d\n', sum(strcmp(qualities, 'MODERATE')));
        fprintf(fid, 'Poor: %d\n', sum(strcmp(qualities, 'POOR')));
        fprintf(fid, 'Errors: %d\n', sum(strcmp(qualities, 'ERROR')));

        fclose(fid);

        qcLog(fig, sprintf('Report exported to: %s', filename));
    catch ME
        qcLog(fig, sprintf('ERROR exporting report: %s', ME.message));
    end
end

function qcLog(fig, msg)
    logBox = findobj(fig, 'Tag', 'qcLog');
    currentLog = get(logBox, 'String');

    if ischar(currentLog)
        currentLog = {currentLog};
    end

    timestamp = datestr(now, 'HH:MM:SS');
    newMsg = sprintf('[%s] %s', timestamp, msg);

    currentLog{end+1} = newMsg;

    if length(currentLog) > 200
        currentLog = currentLog(end-199:end);
    end

    set(logBox, 'String', currentLog, 'Value', length(currentLog));
    drawnow;
end

function qcSetStatus(fig, status)
    statusText = findobj(fig, 'Tag', 'qcStatusText');
    set(statusText, 'String', status);
    drawnow;
end

%% ========================================================================
%  STANDARD 10-20 CHANNEL LOCATIONS
%  ========================================================================

function locs = getStandard1020Locations()
    % Returns standard 10-20 electrode locations with theta and radius
    % These values are compatible with EEGLAB's topoplot function

    % Standard 10-20 electrode positions (theta in degrees, radius normalized)
    % Theta: angle from nose (0 = front, 90 = right ear, -90 = left ear, 180 = back)
    % Radius: distance from center (0 = Cz, 0.5 = standard)

    locs = struct();

    % Labels
    locs.labels = {'Fp1', 'Fp2', 'F7', 'F3', 'Fz', 'F4', 'F8', ...
                   'T7', 'T3', 'C3', 'Cz', 'C4', 'T4', 'T8', ...
                   'P7', 'T5', 'P3', 'Pz', 'P4', 'T6', 'P8', ...
                   'O1', 'Oz', 'O2', ...
                   'AF3', 'AF4', 'FC1', 'FC2', 'FC5', 'FC6', ...
                   'CP1', 'CP2', 'CP5', 'CP6', 'PO3', 'PO4'};

    % Theta (angle in degrees, front = 0)
    locs.theta = [-18, 18, -54, -39, 0, 39, 54, ...
                  -90, -90, -45, 0, 45, 90, 90, ...
                  -126, -126, -135, 180, 135, 126, 126, ...
                  -162, 180, 162, ...
                  -28, 28, -22, 22, -69, 69, ...
                  -158, 158, -111, 111, -151, 151];

    % Radius (normalized, Cz = 0)
    locs.radius = [0.511, 0.511, 0.511, 0.333, 0.256, 0.333, 0.511, ...
                   0.511, 0.511, 0.256, 0, 0.256, 0.511, 0.511, ...
                   0.511, 0.511, 0.333, 0.256, 0.333, 0.511, 0.511, ...
                   0.511, 0.511, 0.511, ...
                   0.383, 0.383, 0.128, 0.128, 0.383, 0.383, ...
                   0.128, 0.128, 0.383, 0.383, 0.383, 0.383];

    % Compute X, Y, Z from spherical coordinates
    % Convert theta to radians and compute 3D coordinates
    nLocs = length(locs.labels);
    locs.X = zeros(1, nLocs);
    locs.Y = zeros(1, nLocs);
    locs.Z = zeros(1, nLocs);
    locs.sph_theta = zeros(1, nLocs);
    locs.sph_phi = zeros(1, nLocs);

    for i = 1:nLocs
        % Convert to standard spherical coordinates
        % theta: azimuth angle (from nose, going CCW when viewed from above)
        % radius: determines elevation
        th = locs.theta(i);
        rd = locs.radius(i);

        % Convert to 3D (assuming head as unit sphere)
        % Elevation from radius (0 = top, 0.5 = equator)
        elevation = 90 - (rd * 180);  % degrees from horizontal

        locs.sph_theta(i) = th;
        locs.sph_phi(i) = elevation;

        % Convert to Cartesian
        elev_rad = elevation * pi / 180;
        th_rad = th * pi / 180;

        locs.X(i) = cos(elev_rad) * sin(th_rad);
        locs.Y(i) = cos(elev_rad) * cos(th_rad);
        locs.Z(i) = sin(elev_rad);
    end
end

%% ========================================================================
%  COMMON CALLBACKS
%  ========================================================================

function closeCallback(hObject, ~)
    appData = guidata(hObject);
    if isfield(appData, 'isConverting') && appData.isConverting
        choice = questdlg('Conversion in progress. Are you sure you want to close?', ...
                          'Close Confirmation', 'Yes', 'No', 'No');
        if strcmp(choice, 'No')
            return;
        end
    end
    if isfield(appData, 'qcIsProcessing') && appData.qcIsProcessing
        choice = questdlg('Processing in progress. Are you sure you want to close?', ...
                          'Close Confirmation', 'Yes', 'No', 'No');
        if strcmp(choice, 'No')
            return;
        end
    end
    delete(hObject);
end
