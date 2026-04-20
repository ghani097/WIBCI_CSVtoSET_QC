function WIBCI_ERP_GUI()
% WIBCI_ERP_GUI - GUI for GEDAI-based EEG cleaning and ERP analysis
%
% Features:
%   Tab 1 - GEDAI Cleaning:
%     - Load single or batch .set files
%     - Apply bandpass filter + GEDAI artifact removal
%     - Display quality metrics (Excellent/Good/Moderate/Poor)
%     - Save cleaned data and export batch reports
%     - View data in EEGLAB
%
%   Tab 2 - ERP Analysis:
%     - Load single or batch cleaned .set files
%     - Set epoch window and baseline correction window
%     - Extract epochs for Easy / Medium / Hard difficulty codes
%     - Average ERPs per group and overlay in plot
%     - Easy=Green, Medium=Orange, Hard=Red
%     - Save figure and export averaged ERPs to .mat
%
% Requirements:
%   - EEGLAB toolbox
%   - GEDAI plugin (install via EEGLAB Extension Manager or from
%     https://github.com/neurotuning/GEDAI-master)
%
% Usage:
%   WIBCI_ERP_GUI()
%
% Author: WiBCI EEG Pipeline
% Date: March 2026

    % Create main figure
    fig = figure('Name', 'WiBCI EEG Tool - GEDAI Cleaning & ERP Analysis', ...
                 'NumberTitle', 'off', ...
                 'Position', [80, 40, 1050, 800], ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none', ...
                 'Resize', 'on', ...
                 'CloseRequestFcn', @closeCallback);

    % Store application data
    appData = struct();

    % Cleaning tab data
    appData.cleanEEG = [];
    appData.cleanEEGRaw = [];
    appData.cleanFilePath = '';
    appData.cleanIsProcessing = false;
    appData.cleanFiles = {};
    appData.cleanBatchResults = {};
    appData.cleanCurrentFileIdx = 0;

    % ERP tab data
    appData.erpFiles      = {};
    appData.erpMode       = '';
    appData.erpChanLabels = {};
    appData.erpNChans     = 0;
    appData.erpResult = struct('easy',[],'med',[],'hard',[],'time',[],'easyN',0,'medN',0,'hardN',0, ...
                               'erpFull',{{}},'chanLabels',{{}});

    guidata(fig, appData);

    % Create tab group
    tabGroup = uitabgroup('Parent', fig, 'Position', [0, 0, 1, 1]);

    % Tab 1: GEDAI Cleaning
    cleanTab = uitab('Parent', tabGroup, 'Title', '  GEDAI Cleaning  ');
    createCleaningUI(cleanTab, fig);

    % Tab 2: ERP Analysis
    erpTab = uitab('Parent', tabGroup, 'Title', '  ERP Analysis  ');
    createERPUI(erpTab, fig);
end

%% ========================================================================
%  GEDAI CLEANING TAB UI
%  ========================================================================

function createCleaningUI(parent, fig)
    % --- File Loading Panel ---
    loadPanel = uipanel('Parent', parent, ...
                        'Title', 'Load EEG Data (.set files)', ...
                        'FontSize', 10, ...
                        'FontWeight', 'bold', ...
                        'Position', [0.02, 0.87, 0.96, 0.11]);

    uicontrol('Parent', loadPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Load Single File', ...
              'Position', [20, 25, 110, 35], ...
              'FontSize', 9, ...
              'Callback', @cleanLoadFile);

    uicontrol('Parent', loadPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Load Folder (Batch)', ...
              'Position', [140, 25, 130, 35], ...
              'FontSize', 9, ...
              'Callback', @cleanLoadFolder);

    uicontrol('Parent', loadPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Clear', ...
              'Position', [280, 25, 60, 35], ...
              'FontSize', 9, ...
              'Callback', @cleanClearFiles);

    uicontrol('Parent', loadPanel, ...
              'Style', 'text', ...
              'Tag', 'cleanFileText', ...
              'String', 'No files loaded', ...
              'Position', [360, 35, 600, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', loadPanel, ...
              'Style', 'text', ...
              'Tag', 'cleanDataInfo', ...
              'String', '', ...
              'Position', [360, 10, 600, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9, ...
              'FontAngle', 'italic');

    % --- File List Panel ---
    fileListPanel = uipanel('Parent', parent, ...
                            'Title', 'Files to Process', ...
                            'FontSize', 10, ...
                            'FontWeight', 'bold', ...
                            'Position', [0.02, 0.57, 0.28, 0.28]);

    uicontrol('Parent', fileListPanel, ...
              'Style', 'listbox', ...
              'Tag', 'cleanFileList', ...
              'Position', [10, 10, 250, 170], ...
              'FontSize', 8, ...
              'Callback', @cleanFileListSelect, ...
              'String', {'(No files loaded)'});

    % --- Processing Options Panel ---
    procPanel = uipanel('Parent', parent, ...
                        'Title', 'Processing Options', ...
                        'FontSize', 10, ...
                        'FontWeight', 'bold', ...
                        'Position', [0.32, 0.57, 0.36, 0.28]);

    % Bandpass filter
    uicontrol('Parent', procPanel, ...
              'Style', 'checkbox', ...
              'Tag', 'cleanFilterCheck', ...
              'String', 'Apply Bandpass Filter', ...
              'Value', 1, ...
              'Position', [15, 165, 180, 25], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'HP:', ...
              'Position', [30, 143, 25, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'edit', ...
              'Tag', 'cleanHighpass', ...
              'String', '0.5', ...
              'Position', [55, 141, 40, 22], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'LP:', ...
              'Position', [105, 143, 25, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'edit', ...
              'Tag', 'cleanLowpass', ...
              'String', '40', ...
              'Position', [130, 141, 40, 22], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'Hz', ...
              'Position', [175, 143, 25, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    % GEDAI options
    uicontrol('Parent', procPanel, ...
              'Style', 'checkbox', ...
              'Tag', 'cleanGEDAICheck', ...
              'String', 'Apply GEDAI Cleaning', ...
              'Value', 1, ...
              'Position', [15, 112, 180, 25], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'Artifact threshold:', ...
              'Position', [30, 90, 110, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'edit', ...
              'Tag', 'cleanGEDAIThreshold', ...
              'String', '4', ...
              'Position', [145, 88, 40, 22], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'Epoch size (cycles):', ...
              'Position', [30, 66, 115, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'edit', ...
              'Tag', 'cleanGEDAIEpoch', ...
              'String', '2', ...
              'Position', [145, 64, 40, 22], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'Reference matrix:', ...
              'Position', [195, 90, 100, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'popupmenu', ...
              'Tag', 'cleanGEDAIRefType', ...
              'String', {'precomputed', 'interpolated'}, ...
              'Position', [295, 88, 50, 22], ...
              'FontSize', 8);

    uicontrol('Parent', procPanel, ...
              'Style', 'checkbox', ...
              'Tag', 'cleanGEDAIParallel', ...
              'String', 'Use parallel computing', ...
              'Value', 0, ...
              'Position', [195, 64, 170, 22], ...
              'FontSize', 9);

    % Auto-save option
    uicontrol('Parent', procPanel, ...
              'Style', 'checkbox', ...
              'Tag', 'cleanAutoSave', ...
              'String', 'Auto-save cleaned files', ...
              'Value', 1, ...
              'Position', [15, 28, 180, 25], ...
              'FontSize', 9);

    uicontrol('Parent', procPanel, ...
              'Style', 'text', ...
              'String', 'Output: GEDAI_Cleaned folder', ...
              'Position', [195, 30, 200, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 8, ...
              'FontAngle', 'italic');

    % --- Quality Metrics Panel ---
    metricsPanel = uipanel('Parent', parent, ...
                           'Title', 'Quality Metrics (Current File)', ...
                           'FontSize', 10, ...
                           'FontWeight', 'bold', ...
                           'Position', [0.70, 0.57, 0.28, 0.28]);

    % Overall quality indicator
    uicontrol('Parent', metricsPanel, ...
              'Style', 'text', ...
              'String', 'Overall Quality:', ...
              'Position', [15, 160, 100, 20], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 10, ...
              'FontWeight', 'bold');

    uicontrol('Parent', metricsPanel, ...
              'Style', 'text', ...
              'Tag', 'cleanOverallQuality', ...
              'String', '---', ...
              'Position', [115, 155, 120, 30], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 14, ...
              'FontWeight', 'bold');

    % Individual metrics
    metricLabels = {'Retained Var:', 'Artifacts:', 'Data Rank:', 'SNR:', 'Events:'};
    metricTags = {'cleanVariance', 'cleanArtifacts', 'cleanRank', 'cleanSNR', 'cleanEvents'};

    for i = 1:length(metricLabels)
        yPos = 130 - (i-1)*24;
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
                       'Position', [0.02, 0.12, 0.66, 0.43]);

    uicontrol('Parent', logPanel, ...
              'Style', 'listbox', ...
              'Tag', 'cleanLog', ...
              'Position', [10, 10, 640, 300], ...
              'FontSize', 8, ...
              'Max', 2, ...
              'Enable', 'inactive', ...
              'String', {'GEDAI Cleaning ready. Load .set file(s) to begin.'});

    % --- Action Buttons Panel ---
    actionPanel = uipanel('Parent', parent, ...
                          'Title', 'Actions', ...
                          'FontSize', 10, ...
                          'FontWeight', 'bold', ...
                          'Position', [0.70, 0.12, 0.28, 0.43]);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'Tag', 'cleanRunBtn', ...
              'String', 'RUN GEDAI', ...
              'Position', [20, 260, 220, 45], ...
              'FontSize', 12, ...
              'FontWeight', 'bold', ...
              'BackgroundColor', [0.2, 0.6, 0.3], ...
              'ForegroundColor', [1, 1, 1], ...
              'Callback', @cleanRunProcessing);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'Tag', 'cleanSaveBtn', ...
              'String', 'Save Current Cleaned Data', ...
              'Position', [20, 218, 220, 32], ...
              'FontSize', 9, ...
              'Enable', 'off', ...
              'Callback', @cleanSaveData);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'String', 'View Data (EEGLAB)', ...
              'Position', [20, 181, 220, 32], ...
              'FontSize', 9, ...
              'Callback', @cleanViewData);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Compare Raw vs Cleaned', ...
              'Position', [20, 144, 220, 32], ...
              'FontSize', 9, ...
              'Callback', @cleanCompare);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'String', 'View Power Spectrum', ...
              'Position', [20, 107, 220, 32], ...
              'FontSize', 9, ...
              'Callback', @cleanViewSpectrum);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Export Report (Excel)', ...
              'Position', [20, 70, 220, 32], ...
              'FontSize', 9, ...
              'Callback', @cleanExportExcel);

    uicontrol('Parent', actionPanel, ...
              'Style', 'pushbutton', ...
              'String', 'Export Report (Text)', ...
              'Position', [20, 38, 220, 28], ...
              'FontSize', 9, ...
              'Callback', @cleanExportReport);

    uicontrol('Parent', actionPanel, ...
              'Style', 'text', ...
              'Tag', 'cleanStatusText', ...
              'String', 'Ready', ...
              'Position', [20, 8, 220, 22], ...
              'FontSize', 9, ...
              'HorizontalAlignment', 'center');

    % --- Requirements Info ---
    uicontrol('Parent', parent, ...
              'Style', 'text', ...
              'String', 'Requirements: EEGLAB with GEDAI plugin (github.com/neurotuning/GEDAI-master)', ...
              'Position', [20, 5, 500, 18], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 8, ...
              'FontAngle', 'italic');
end

%% ========================================================================
%  ERP ANALYSIS TAB UI
%  ========================================================================

function createERPUI(parent, fig)
    % --- File Loading Panel ---
    loadPanel = uipanel('Parent', parent, ...
                        'Title', 'Load Cleaned EEG Data (.set files)', ...
                        'FontSize', 10, 'FontWeight', 'bold', ...
                        'Position', [0.02, 0.87, 0.96, 0.11]);

    uicontrol('Parent', loadPanel, 'Style', 'pushbutton', 'String', 'Load Single File', ...
              'Position', [20, 25, 115, 35], 'FontSize', 9, 'Callback', @erpLoadFile);
    uicontrol('Parent', loadPanel, 'Style', 'pushbutton', 'String', 'Load Folder (Batch)', ...
              'Position', [145, 25, 130, 35], 'FontSize', 9, 'Callback', @erpLoadFolder);
    uicontrol('Parent', loadPanel, 'Style', 'pushbutton', 'String', 'Clear', ...
              'Position', [285, 25, 60, 35], 'FontSize', 9, 'Callback', @erpClearFiles);
    uicontrol('Parent', loadPanel, 'Style', 'text', 'Tag', 'erpFileText', ...
              'String', 'No files loaded', 'Position', [365, 38, 600, 20], ...
              'HorizontalAlignment', 'left', 'FontSize', 9);
    uicontrol('Parent', loadPanel, 'Style', 'text', 'Tag', 'erpDataInfo', 'String', '', ...
              'Position', [365, 12, 600, 20], 'HorizontalAlignment', 'left', ...
              'FontSize', 9, 'FontAngle', 'italic');

    % --- File List Panel ---
    fileListPanel = uipanel('Parent', parent, ...
                            'Title', 'Files Loaded', ...
                            'FontSize', 10, 'FontWeight', 'bold', ...
                            'Position', [0.02, 0.54, 0.22, 0.31]);
    uicontrol('Parent', fileListPanel, 'Style', 'listbox', 'Tag', 'erpFileList', ...
              'Position', [8, 8, 198, 188], 'FontSize', 8, 'String', {'(No files loaded)'});

    % --- ERP Parameters Panel ---
    paramPanel = uipanel('Parent', parent, ...
                         'Title', 'ERP Parameters', ...
                         'FontSize', 10, 'FontWeight', 'bold', ...
                         'Position', [0.26, 0.54, 0.44, 0.31]);

    % -- Study mode checkbox --
    uicontrol('Parent', paramPanel, ...
              'Style', 'checkbox', ...
              'Tag', 'erpYIMIMGCheck', ...
              'String', '  YIMIMG Study  (sequential difficulty mapping)', ...
              'Value', 1, ...
              'Position', [15, 200, 380, 22], ...
              'FontSize', 9, 'FontWeight', 'bold', ...
              'Callback', @erpToggleStudyMode);

    % -- Epoch window --
    uicontrol('Parent', paramPanel, 'Style', 'text', 'String', 'Epoch Window (ms):', ...
              'Position', [15, 172, 130, 18], 'HorizontalAlignment', 'left', ...
              'FontSize', 9, 'FontWeight', 'bold');
    uicontrol('Parent', paramPanel, 'Style', 'text', 'String', 'Start:', ...
              'Position', [30, 149, 35, 18], 'HorizontalAlignment', 'left', 'FontSize', 9);
    uicontrol('Parent', paramPanel, 'Style', 'edit', 'Tag', 'erpEpochStart', ...
              'String', '-200', 'Position', [68, 147, 55, 22], 'FontSize', 9);
    uicontrol('Parent', paramPanel, 'Style', 'text', 'String', 'End:', ...
              'Position', [135, 149, 30, 18], 'HorizontalAlignment', 'left', 'FontSize', 9);
    uicontrol('Parent', paramPanel, 'Style', 'edit', 'Tag', 'erpEpochEnd', ...
              'String', '800', 'Position', [168, 147, 55, 22], 'FontSize', 9);
    uicontrol('Parent', paramPanel, 'Style', 'text', 'String', 'ms', ...
              'Position', [228, 149, 20, 18], 'HorizontalAlignment', 'left', 'FontSize', 9);

    % -- Baseline window --
    uicontrol('Parent', paramPanel, 'Style', 'text', 'String', 'Baseline Correction (ms):', ...
              'Position', [15, 122, 155, 18], 'HorizontalAlignment', 'left', ...
              'FontSize', 9, 'FontWeight', 'bold');
    uicontrol('Parent', paramPanel, 'Style', 'text', 'String', 'Start:', ...
              'Position', [30, 99, 35, 18], 'HorizontalAlignment', 'left', 'FontSize', 9);
    uicontrol('Parent', paramPanel, 'Style', 'edit', 'Tag', 'erpBaseStart', ...
              'String', '-200', 'Position', [68, 97, 55, 22], 'FontSize', 9);
    uicontrol('Parent', paramPanel, 'Style', 'text', 'String', 'End:', ...
              'Position', [135, 99, 30, 18], 'HorizontalAlignment', 'left', 'FontSize', 9);
    uicontrol('Parent', paramPanel, 'Style', 'edit', 'Tag', 'erpBaseEnd', ...
              'String', '0', 'Position', [168, 97, 55, 22], 'FontSize', 9);
    uicontrol('Parent', paramPanel, 'Style', 'text', 'String', 'ms', ...
              'Position', [228, 99, 20, 18], 'HorizontalAlignment', 'left', 'FontSize', 9);

    % -- Channel --
    uicontrol('Parent', paramPanel, 'Style', 'text', 'String', 'Plot Channel:', ...
              'Position', [15, 72, 90, 18], 'HorizontalAlignment', 'left', ...
              'FontSize', 9, 'FontWeight', 'bold');
    uicontrol('Parent', paramPanel, 'Style', 'edit', 'Tag', 'erpChannel', ...
              'String', '0', 'Position', [108, 70, 60, 22], 'FontSize', 9, ...
              'TooltipString', 'Enter channel number (1-based), name (e.g. Pz), or 0 for GFP');
    uicontrol('Parent', paramPanel, 'Style', 'text', 'Tag', 'erpChanHint', ...
              'String', '0=GFP  |  name or #  (e.g. Pz, Cz, 1)', ...
              'Position', [173, 72, 215, 18], 'HorizontalAlignment', 'left', ...
              'FontSize', 8, 'FontAngle', 'italic');

    % ---- YIMIMG section (visible when checkbox ON) ----
    uicontrol('Parent', paramPanel, ...
              'Tag', 'erpYIMIMGInfo', ...
              'Style', 'text', ...
              'String', 'Easy=1-4,21-24,29-32,37-40  |  Medium=5-8,13-16,33-36,45-48  |  Hard=9-12,17-20,25-28,41-44', ...
              'Position', [15, 28, 430, 28], ...
              'HorizontalAlignment', 'left', ...
              'FontSize', 8, 'FontAngle', 'italic', ...
              'Visible', 'on');
    uicontrol('Parent', paramPanel, 'Tag', 'erpYIMIMGStimLbl', ...
              'Style', 'text', 'String', 'Count only event type:', ...
              'Position', [15, 8, 130, 16], 'FontSize', 8, ...
              'HorizontalAlignment', 'left', 'Visible', 'on');
    uicontrol('Parent', paramPanel, 'Tag', 'erpYIMIMGStimType', ...
              'Style', 'edit', 'String', '', ...
              'Position', [148, 6, 110, 20], 'FontSize', 8, ...
              'TooltipString', 'Leave blank to count ALL events. Enter e.g. "HT B" to only count that type for position mapping.', ...
              'Visible', 'on');
    uicontrol('Parent', paramPanel, 'Tag', 'erpYIMIMGStimHint', ...
              'Style', 'text', 'String', '(blank=all; e.g. HT B)', ...
              'Position', [262, 8, 150, 16], 'FontSize', 7, 'FontAngle', 'italic', ...
              'HorizontalAlignment', 'left', 'Visible', 'on');

    % ---- Generic conditions section (visible when checkbox OFF) ----
    % Auto-detect note
    uicontrol('Parent', paramPanel, 'Tag', 'erpGenAutoNote', ...
              'Style', 'text', ...
              'String', 'Leave codes blank → auto-detect all unique event types from data', ...
              'Position', [15, 51, 415, 15], 'FontSize', 8, 'FontAngle', 'italic', ...
              'HorizontalAlignment', 'left', 'Visible', 'off');

    % Header
    uicontrol('Parent', paramPanel, 'Tag', 'erpGenHdr', ...
              'Style', 'text', 'String', 'Condition Name  (optional)', ...
              'Position', [40, 36, 120, 13], 'FontSize', 7, 'FontWeight', 'bold', ...
              'HorizontalAlignment', 'left', 'Visible', 'off');
    uicontrol('Parent', paramPanel, 'Tag', 'erpGenHdr2', ...
              'Style', 'text', 'String', 'Event Types / Codes  (space-sep, e.g.  HT B  or  1 2 3 — blank=auto)', ...
              'Position', [165, 36, 265, 13], 'FontSize', 7, 'FontWeight', 'bold', ...
              'HorizontalAlignment', 'left', 'Visible', 'off');

    % Row 1 — Condition 1 (Green)
    uicontrol('Parent', paramPanel, 'Tag', 'erpGenLbl1', 'Style', 'text', ...
              'String', 'Cond 1:', 'Position', [15, 18, 42, 16], ...
              'HorizontalAlignment', 'left', 'FontSize', 9, 'Visible', 'off');
    uicontrol('Parent', paramPanel, 'Tag', 'erpGenName1', 'Style', 'edit', ...
              'String', '', 'Position', [58, 16, 95, 20], ...
              'FontSize', 9, 'Visible', 'off');
    uicontrol('Parent', paramPanel, 'Tag', 'erpGenCodes1', 'Style', 'edit', ...
              'String', '', 'Position', [165, 16, 262, 20], ...
              'FontSize', 9, 'Visible', 'off');

    % Row 2 — Condition 2 (Orange)
    uicontrol('Parent', paramPanel, 'Tag', 'erpGenLbl2', 'Style', 'text', ...
              'String', 'Cond 2:', 'Position', [15, 0, 42, 14], ...
              'HorizontalAlignment', 'left', 'FontSize', 9, 'Visible', 'off');
    uicontrol('Parent', paramPanel, 'Tag', 'erpGenName2', 'Style', 'edit', ...
              'String', '', 'Position', [58, -2, 95, 18], ...
              'FontSize', 9, 'Visible', 'off');
    uicontrol('Parent', paramPanel, 'Tag', 'erpGenCodes2', 'Style', 'edit', ...
              'String', '', 'Position', [165, -2, 262, 18], ...
              'FontSize', 9, 'Visible', 'off');

    % --- Actions Panel ---
    actionPanel = uipanel('Parent', parent, ...
                          'Title', 'Actions', ...
                          'FontSize', 10, 'FontWeight', 'bold', ...
                          'Position', [0.72, 0.54, 0.26, 0.31]);

    uicontrol('Parent', actionPanel, 'Style', 'pushbutton', 'Tag', 'erpRunBtn', ...
              'String', 'RUN ERP ANALYSIS', ...
              'Position', [15, 200, 220, 40], ...
              'FontSize', 12, 'FontWeight', 'bold', ...
              'BackgroundColor', [0.15, 0.45, 0.70], 'ForegroundColor', [1, 1, 1], ...
              'Callback', @erpRunAnalysis);
    uicontrol('Parent', actionPanel, 'Style', 'pushbutton', 'String', 'Inspect Events', ...
              'Position', [15, 168, 220, 26], 'FontSize', 9, ...
              'BackgroundColor', [0.80, 0.45, 0.05], 'ForegroundColor', [1, 1, 1], ...
              'TooltipString', 'Show all event types and counts in the loaded file', ...
              'Callback', @erpInspectEvents);
    uicontrol('Parent', actionPanel, 'Style', 'pushbutton', 'String', 'Save Figure', ...
              'Position', [15, 136, 220, 26], 'FontSize', 9, 'Callback', @erpSaveFigure);
    uicontrol('Parent', actionPanel, 'Style', 'pushbutton', ...
              'String', 'Export Averaged ERPs (.mat)', ...
              'Position', [15, 104, 220, 26], 'FontSize', 9, 'Callback', @erpExportData);
    uicontrol('Parent', actionPanel, 'Style', 'pushbutton', ...
              'String', 'Channel Grid View', ...
              'Tag', 'erpGridBtn', ...
              'Position', [15, 72, 220, 26], 'FontSize', 9, ...
              'BackgroundColor', [0.45, 0.25, 0.65], 'ForegroundColor', [1, 1, 1], ...
              'Callback', @erpChannelGrid);
    uicontrol('Parent', actionPanel, 'Style', 'pushbutton', 'String', 'Clear Plot', ...
              'Position', [15, 44, 220, 22], 'FontSize', 9, 'Callback', @erpClearPlot);
    uicontrol('Parent', actionPanel, 'Style', 'text', 'Tag', 'erpStatusText', ...
              'String', 'Ready', 'Position', [15, 5, 220, 34], ...
              'FontSize', 9, 'HorizontalAlignment', 'center');

    % --- Plot Panel ---
    plotPanel = uipanel('Parent', parent, 'Title', 'ERP Plot', ...
                        'FontSize', 10, 'FontWeight', 'bold', ...
                        'Position', [0.02, 0.02, 0.62, 0.50]);
    erpAxes = axes('Parent', plotPanel, 'Tag', 'erpAxes', ...
                   'Position', [0.09, 0.14, 0.87, 0.80], 'Box', 'on', 'FontSize', 9);
    xlabel(erpAxes, 'Time (ms)', 'FontSize', 10);
    ylabel(erpAxes, 'Amplitude (\muV)', 'FontSize', 10);
    title(erpAxes, 'ERP  —  Easy (Green)  |  Medium (Orange)  |  Hard (Red)', ...
          'FontSize', 11, 'FontWeight', 'bold');
    grid(erpAxes, 'on');

    % --- Log Panel ---
    logPanel = uipanel('Parent', parent, 'Title', 'ERP Log', ...
                       'FontSize', 10, 'FontWeight', 'bold', ...
                       'Position', [0.66, 0.02, 0.33, 0.50]);
    uicontrol('Parent', logPanel, 'Style', 'listbox', 'Tag', 'erpLog', ...
              'Units', 'normalized', 'Position', [0.01, 0.01, 0.98, 0.98], ...
              'FontSize', 8, 'Max', 2, ...
              'Enable', 'inactive', ...
              'HorizontalAlignment', 'left', ...
              'String', {'ERP Analysis ready.', 'Load .set file(s) to begin.'});
end

%% ========================================================================
%  ERP ANALYSIS CALLBACKS
%  ========================================================================

function erpLoadFile(hObject, ~)
    fig = ancestor(hObject, 'figure');
    [filename, pathname] = uigetfile('*.set', 'Select cleaned EEGLAB .set file');
    if isequal(filename, 0), return; end

    appData = guidata(fig);
    appData.erpFiles = {fullfile(pathname, filename)};
    appData.erpMode  = 'single';

    % Peek at channel names from this file
    [fDir, fBase, ~] = fileparts(fullfile(pathname, filename));
    try
        EEGpeek = pop_loadset('filename', [fBase '.set'], 'filepath', fDir);
        appData.erpChanLabels = erpGetChanLabels(EEGpeek);
        appData.erpNChans     = EEGpeek.nbchan;
        chanStr = strjoin(appData.erpChanLabels, '  ');
        set(findobj(fig, 'Tag', 'erpDataInfo'), ...
            'String', sprintf('%d ch: %s', EEGpeek.nbchan, chanStr));
        erpLog(fig, sprintf('  Channels (%d): %s', EEGpeek.nbchan, strjoin(appData.erpChanLabels, ', ')));
    catch
        appData.erpChanLabels = {};
        appData.erpNChans = 0;
    end

    guidata(fig, appData);
    set(findobj(fig, 'Tag', 'erpFileText'), 'String', sprintf('Single file: %s', filename));
    set(findobj(fig, 'Tag', 'erpFileList'), 'String', {filename});
    erpLog(fig, sprintf('Loaded: %s', filename));
end

function erpLoadFolder(hObject, ~)
    fig = ancestor(hObject, 'figure');
    folder = uigetdir('', 'Select folder with cleaned .set files');
    if isequal(folder, 0), return; end

    files = dir(fullfile(folder, '*.set'));
    if isempty(files)
        errordlg('No .set files found in selected folder.', 'No Files');
        return;
    end

    appData = guidata(fig);
    appData.erpFiles = {};
    fileNames = {};
    for i = 1:length(files)
        appData.erpFiles{end+1} = fullfile(folder, files(i).name);
        fileNames{end+1}        = files(i).name;
    end
    appData.erpMode = 'batch';

    % Peek at channel names from first file
    try
        [fDir, fBase, ~] = fileparts(appData.erpFiles{1});
        EEGpeek = pop_loadset('filename', [fBase '.set'], 'filepath', fDir);
        appData.erpChanLabels = erpGetChanLabels(EEGpeek);
        appData.erpNChans     = EEGpeek.nbchan;
        chanStr = strjoin(appData.erpChanLabels, '  ');
        set(findobj(fig, 'Tag', 'erpDataInfo'), ...
            'String', sprintf('%d ch: %s', EEGpeek.nbchan, chanStr));
        erpLog(fig, sprintf('  Channels (%d): %s', EEGpeek.nbchan, strjoin(appData.erpChanLabels, ', ')));
    catch
        appData.erpChanLabels = {};
        appData.erpNChans = 0;
    end

    guidata(fig, appData);

    set(findobj(fig, 'Tag', 'erpFileText'), ...
        'String', sprintf('Batch: %d files from %s', length(files), folder));
    set(findobj(fig, 'Tag', 'erpFileList'), 'String', fileNames);
    erpLog(fig, sprintf('Batch loaded: %d .set files', length(files)));
end

function erpClearFiles(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);
    appData.erpFiles      = {};
    appData.erpMode       = '';
    appData.erpChanLabels = {};
    appData.erpNChans     = 0;
    guidata(fig, appData);

    set(findobj(fig, 'Tag', 'erpFileText'), 'String', 'No files loaded');
    set(findobj(fig, 'Tag', 'erpDataInfo'), 'String', '');
    set(findobj(fig, 'Tag', 'erpFileList'), 'String', {'(No files loaded)'});
    erpLog(fig, 'Files cleared.');
end

function erpToggleStudyMode(hObject, ~)
    % Show/hide YIMIMG info vs generic condition inputs based on checkbox state
    fig     = ancestor(hObject, 'figure');
    checked = get(hObject, 'Value');

    yimTags = {'erpYIMIMGInfo','erpYIMIMGStimLbl','erpYIMIMGStimType','erpYIMIMGStimHint'};
    genTags = {'erpGenAutoNote','erpGenHdr','erpGenHdr2', ...
               'erpGenLbl1','erpGenName1','erpGenCodes1', ...
               'erpGenLbl2','erpGenName2','erpGenCodes2'};

    if checked
        vis_yim = 'on';  vis_gen = 'off';
    else
        vis_yim = 'off'; vis_gen = 'on';
    end

    for i = 1:length(yimTags)
        h = findobj(fig, 'Tag', yimTags{i});
        if ~isempty(h), set(h, 'Visible', vis_yim); end
    end
    for i = 1:length(genTags)
        h = findobj(fig, 'Tag', genTags{i});
        if ~isempty(h), set(h, 'Visible', vis_gen); end
    end
end

function erpRunAnalysis(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if ~isfield(appData, 'erpFiles') || isempty(appData.erpFiles)
        errordlg('No files loaded. Please load .set file(s) first.', 'No Files');
        return;
    end

    % Read parameters (convert ms to seconds for pop_epoch)
    epochStart = str2double(get(findobj(fig, 'Tag', 'erpEpochStart'), 'String')) / 1000;
    epochEnd   = str2double(get(findobj(fig, 'Tag', 'erpEpochEnd'),   'String')) / 1000;
    baseStart  = str2double(get(findobj(fig, 'Tag', 'erpBaseStart'),  'String'));
    baseEnd    = str2double(get(findobj(fig, 'Tag', 'erpBaseEnd'),    'String'));

    % Channel: accept number or name (e.g. "Pz", "Cz")
    chanInput = strtrim(get(findobj(fig, 'Tag', 'erpChannel'), 'String'));
    chanNum   = str2double(chanInput);
    if isnan(chanNum)
        % Name-based: look up in stored labels
        chanNum = 0; % fallback to GFP
        if ~isempty(appData.erpChanLabels)
            idx = find(strcmpi(appData.erpChanLabels, chanInput), 1);
            if ~isempty(idx)
                chanNum = idx;
                erpLog(fig, sprintf('  Channel "%s" → index %d', chanInput, chanNum));
            else
                erpLog(fig, sprintf('  WARNING: Channel "%s" not found — using GFP', chanInput));
            end
        end
    end

    if isnan(epochStart) || isnan(epochEnd) || epochStart >= epochEnd
        errordlg('Invalid epoch window. Check Start/End values.', 'Parameter Error');
        return;
    end
    if isnan(baseStart) || isnan(baseEnd) || baseStart >= baseEnd
        errordlg('Invalid baseline window. Check Start/End values.', 'Parameter Error');
        return;
    end

    useYIMIMG = get(findobj(fig, 'Tag', 'erpYIMIMGCheck'), 'Value');

    if useYIMIMG
        % ---- YIMIMG mode: sequential position mapping → Easy/Medium/Hard ----
        condStr    = {{'1'}, {'2'}, {'3'}};
        condNames  = {'Easy', 'Medium', 'Hard'};
        condColors = {[0.0, 0.68, 0.18], [1.0, 0.50, 0.0], [0.85, 0.08, 0.08]};
    else
        % ---- Generic mode ----
        codes1 = strtrim(get(findobj(fig, 'Tag', 'erpGenCodes1'), 'String'));
        codes2 = strtrim(get(findobj(fig, 'Tag', 'erpGenCodes2'), 'String'));
        name1  = strtrim(get(findobj(fig, 'Tag', 'erpGenName1'),  'String'));
        name2  = strtrim(get(findobj(fig, 'Tag', 'erpGenName2'),  'String'));

        cstr1 = strsplit(codes1); cstr1 = cstr1(~cellfun(@isempty, cstr1));
        cstr2 = strsplit(codes2); cstr2 = cstr2(~cellfun(@isempty, cstr2));

        if isempty(cstr1) && isempty(cstr2)
            % Auto-detect: read unique event types from all files
            erpLog(fig, 'Generic mode: auto-detecting event types from data...');
            [condStr, condNames, condColors] = erpAutoDetectConditions(appData.erpFiles, fig);
            if isempty(condStr)
                errordlg('No events found in the loaded files.', 'No Events');
                return;
            end
            erpLog(fig, sprintf('  Auto-detected %d condition(s): %s', ...
                length(condNames), strjoin(condNames, ', ')));
        else
            % User-specified conditions
            if isempty(name1)
                if ~isempty(cstr1), name1 = strjoin(cstr1, ' '); else, name1 = 'Cond1'; end
            end
            if isempty(name2)
                if ~isempty(cstr2), name2 = strjoin(cstr2, ' '); else, name2 = 'Cond2'; end
            end
            condStr    = {cstr1, cstr2};
            condNames  = {name1, name2};
            condColors = {[0.0, 0.68, 0.18], [1.0, 0.50, 0.0]};
            % Remove empty conditions
            keep = ~cellfun(@isempty, condStr);
            condStr = condStr(keep); condNames = condNames(keep); condColors = condColors(keep);
        end
    end

    % Weighted accumulators: one cell per condition
    nCond       = length(condStr);
    sumERP      = cell(1, nCond);
    sumERPFull  = cell(1, nCond);   % all channels × time
    nTrials     = zeros(1, nCond);
    timeVec     = [];
    chanLabels  = {};               % picked up from first file loaded

    set(findobj(fig, 'Tag', 'erpRunBtn'), 'Enable', 'off');
    erpSetStatus(fig, 'Processing...');

    for fIdx = 1:length(appData.erpFiles)
        filePath = appData.erpFiles{fIdx};
        [fDir, fName, ~] = fileparts(filePath);
        erpLog(fig, sprintf('--- Processing: %s ---', fName));

        try
            EEG = pop_loadset('filename', [fName '.set'], 'filepath', fDir);
            EEG = eeg_checkset(EEG);   % ensure events sorted by latency
            erpLog(fig, sprintf('  Ch: %d  Srate: %d Hz  Events: %d  Duration: %.1f s', ...
                EEG.nbchan, EEG.srate, length(EEG.event), EEG.xmax));

            % Log all unique event types in this file
            if isfield(EEG, 'event') && ~isempty(EEG.event)
                allT = {};
                for ei = 1:length(EEG.event)
                    t = EEG.event(ei).type;
                    if isnumeric(t), t = num2str(t); end
                    t = strtrim(char(t));
                    allT{end+1} = t; %#ok<AGROW>
                end
                uTypes = unique(allT);
                for ut = 1:length(uTypes)
                    cnt = sum(strcmp(allT, uTypes{ut}));
                    erpLog(fig, sprintf('    event type ''%s'' : %d occurrences', uTypes{ut}, cnt));
                end
            else
                erpLog(fig, '  WARNING: No events found in this file!');
            end

            % Capture channel labels from first successfully loaded file
            if isempty(chanLabels)
                chanLabels = erpGetChanLabels(EEG);
            end

            % Resolve name-based channel to index (using this file's labels)
            resolvedChan = chanNum;
            if isnan(str2double(chanInput)) && chanNum == 0
                fileLabels = erpGetChanLabels(EEG);
                idx = find(strcmpi(fileLabels, chanInput), 1);
                if ~isempty(idx), resolvedChan = idx; end
            end

            if useYIMIMG
                stimFilt = strtrim(get(findobj(fig,'Tag','erpYIMIMGStimType'),'String'));
                EEG = erpRetypeEvents(EEG, fig, stimFilt);
                % Log how many events got each YIMIMG label after retyping
                typedT = {};
                for ei = 1:length(EEG.event)
                    t = char(EEG.event(ei).type);
                    typedT{end+1} = t; %#ok<AGROW>
                end
                for lbl = {'1','2','3'}
                    erpLog(fig, sprintf('    after retype: label ''%s'' → %d epochs', ...
                        lbl{1}, sum(strcmp(typedT, lbl{1}))));
                end
            end

            logParts = '';
            for c = 1:nCond
                if isempty(condStr{c}), continue; end
                [erp, tVec, n, erpFull] = erpComputeGroup(EEG, condStr{c}, ...
                    [epochStart epochEnd], [baseStart baseEnd], resolvedChan);
                logParts = [logParts, sprintf('%s=%d  ', condNames{c}, n)]; %#ok<AGROW>
                if ~isempty(tVec), timeVec = tVec; end
                if ~isempty(erp) && n > 0
                    if isempty(sumERP{c}),     sumERP{c}     = zeros(size(erp));     end
                    if isempty(sumERPFull{c}) && ~isempty(erpFull)
                        sumERPFull{c} = zeros(size(erpFull));
                    end
                    sumERP{c}  = sumERP{c} + erp * n;
                    if ~isempty(erpFull)
                        sumERPFull{c} = sumERPFull{c} + erpFull * n;
                    end
                    nTrials(c) = nTrials(c) + n;
                end
            end
            erpLog(fig, ['  ' strtrim(logParts)]);

        catch ME
            erpLog(fig, sprintf('  ERROR: %s', ME.message));
        end
    end

    % Grand averages
    finalERP     = cell(1, nCond);
    finalERPFull = cell(1, nCond);
    for c = 1:nCond
        if nTrials(c) > 0
            finalERP{c}     = sumERP{c}     / nTrials(c);
            if ~isempty(sumERPFull{c})
                finalERPFull{c} = sumERPFull{c} / nTrials(c);
            end
        end
    end

    % Store
    appData = guidata(fig);
    appData.erpResult.erp        = finalERP;
    appData.erpResult.erpFull    = finalERPFull;
    appData.erpResult.chanLabels = chanLabels;
    appData.erpResult.names      = condNames;
    appData.erpResult.colors     = condColors;
    appData.erpResult.nTrials    = nTrials;
    appData.erpResult.time       = timeVec;
    % Keep legacy fields for export compatibility
    appData.erpResult.easy  = [];  appData.erpResult.easyN = 0;
    appData.erpResult.med   = [];  appData.erpResult.medN  = 0;
    appData.erpResult.hard  = [];  appData.erpResult.hardN = 0;
    if nCond >= 1 && ~isempty(finalERP{1}), appData.erpResult.easy  = finalERP{1}; appData.erpResult.easyN = nTrials(1); end
    if nCond >= 2 && ~isempty(finalERP{2}), appData.erpResult.med   = finalERP{2}; appData.erpResult.medN  = nTrials(2); end
    if nCond >= 3 && ~isempty(finalERP{3}), appData.erpResult.hard  = finalERP{3}; appData.erpResult.hardN = nTrials(3); end
    guidata(fig, appData);

    % Plot
    erpPlotResultsGeneric(fig, timeVec, finalERP, condNames, condColors, nTrials);

    statusParts = '';
    for c = 1:nCond
        statusParts = [statusParts, sprintf('%s=%d  ', condNames{c}, nTrials(c))]; %#ok<AGROW>
    end
    erpLog(fig, 'ERP analysis complete.');
    erpSetStatus(fig, ['Done  |  ' strtrim(statusParts)]);
    set(findobj(fig, 'Tag', 'erpRunBtn'), 'Enable', 'on');
end

function EEGout = erpRetypeEvents(EEG, fig, stimTypeFilter)
    % Retype event types by SEQUENTIAL POSITION (Event Num 1..48).
    %
    % stimTypeFilter: optional string or cell of strings. If non-empty,
    %   only events whose type matches are counted for position ordering.
    %   Other events are left unchanged.
    %
    % Mapping (sequential stimulus position → type string):
    %   Easy   ('1'):  positions  1- 4, 21-24, 29-32, 37-40
    %   Medium ('2'):  positions  5- 8, 13-16, 33-36, 45-48
    %   Hard   ('3'):  positions  9-12, 17-20, 25-28, 41-44

    if nargin < 3, stimTypeFilter = ''; end
    if ischar(stimTypeFilter), stimTypeFilter = strtrim(stimTypeFilter); end

    EEGout = EEG;
    nEvents = length(EEG.event);

    if nEvents == 0
        erpLog(fig, '  WARNING: No events found in this file.');
        return;
    end

    easyPos   = [1:4,  21:24, 29:32, 37:40];
    mediumPos = [5:8,  13:16, 33:36, 45:48];
    hardPos   = [9:12, 17:20, 25:28, 41:44];

    % Build index of events to count (filtered or all)
    stimIdx = [];
    for i = 1:nEvents
        t = strtrim(char(EEG.event(i).type));
        if isempty(stimTypeFilter) || strcmpi(t, stimTypeFilter)
            stimIdx(end+1) = i; %#ok<AGROW>
        end
    end

    if isempty(stimIdx)
        erpLog(fig, sprintf('  WARNING: No events match filter "%s" — check the stim type field.', stimTypeFilter));
        return;
    end

    if ~isempty(stimTypeFilter)
        erpLog(fig, sprintf('  Filtering by type "%s": %d/%d events qualify', ...
            stimTypeFilter, length(stimIdx), nEvents));
    end

    nMap = min(length(stimIdx), 48);
    nE = 0; nM = 0; nH = 0;

    for pos = 1:nMap
        i = stimIdx(pos);   % actual event index in EEG.event
        if any(easyPos == pos)
            EEGout.event(i).type = '1';
            nE = nE + 1;
        elseif any(mediumPos == pos)
            EEGout.event(i).type = '2';
            nM = nM + 1;
        elseif any(hardPos == pos)
            EEGout.event(i).type = '3';
            nH = nH + 1;
        end
    end

    erpLog(fig, sprintf('  Retyped by position: Easy=%d  Medium=%d  Hard=%d  (of %d qualifying events)', ...
        nE, nM, nH, length(stimIdx)));
end

function [erpMean, timeVec, nEpochs, avgDataFull] = erpComputeGroup(EEG, codeStr, epochWin, baseWin, chanNum)
    erpMean = []; timeVec = []; nEpochs = 0; avgDataFull = [];
    if isempty(codeStr), return; end

    try
        EEGep = pop_epoch(EEG, codeStr, epochWin, 'epochinfo', 'yes');
        if EEGep.trials == 0, return; end
        EEGep   = pop_rmbase(EEGep, baseWin, []);
        nEpochs = EEGep.trials;
        timeVec = EEGep.times;            % in ms

        avgData     = mean(EEGep.data, 3);    % channels × timepoints
        avgDataFull = avgData;                 % always return full for grid view

        if isnan(chanNum) || chanNum <= 0 || chanNum > size(avgData, 1)
            % Global Field Power: RMS across channels
            erpMean = sqrt(mean(avgData .^ 2, 1));
        else
            erpMean = avgData(round(chanNum), :);
        end
    catch ME
        warning('erpComputeGroup: %s', ME.message);
    end
end

%% ========================================================================
%  INSPECT EVENTS — diagnostic button callback
%  ========================================================================
function erpInspectEvents(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if ~isfield(appData, 'erpFiles') || isempty(appData.erpFiles)
        errordlg('No files loaded. Load a .set file first.', 'No File');
        return;
    end

    filePath = appData.erpFiles{1};
    [fDir, fBase, ~] = fileparts(filePath);
    erpLog(fig, sprintf('=== INSPECT EVENTS: %s ===', fBase));

    try
        EEG = pop_loadset('filename', [fBase '.set'], 'filepath', fDir);
        EEG = eeg_checkset(EEG);
    catch ME
        errordlg(sprintf('Failed to load file:\n%s', ME.message), 'Load Error');
        return;
    end

    nEv = length(EEG.event);
    lines = {};
    lines{end+1} = sprintf('File: %s', fBase);
    lines{end+1} = sprintf('Channels: %d   Srate: %d Hz   Duration: %.2f s', ...
                            EEG.nbchan, EEG.srate, EEG.xmax);
    lines{end+1} = sprintf('Total events: %d', nEv);
    lines{end+1} = '';

    if nEv == 0
        lines{end+1} = 'NO EVENTS FOUND — cannot compute ERPs.';
        lines{end+1} = 'Check that the .set file was converted with events enabled.';
    else
        % Collect types
        allTypes = {};
        for ei = 1:nEv
            t = EEG.event(ei).type;
            if isnumeric(t), t = num2str(t); end
            allTypes{end+1} = strtrim(char(t)); %#ok<AGROW>
        end

        uTypes = unique(allTypes);
        lines{end+1} = 'EVENT TYPES  (as stored in .set file):';
        lines{end+1} = '  Type              Count   First latency (s)';
        lines{end+1} = '  -----------------------------------------------';
        for i = 1:length(uTypes)
            idx = find(strcmp(allTypes, uTypes{i}));
            firstLat = EEG.event(idx(1)).latency / EEG.srate;
            lines{end+1} = sprintf("  %-18s  %4d    %.3f s", uTypes{i}, length(idx), firstLat);
        end

        lines{end+1} = '';
        lines{end+1} = sprintf('Epoch window in GUI: [%s, %s] ms', ...
            get(findobj(fig,'Tag','erpEpochStart'),'String'), ...
            get(findobj(fig,'Tag','erpEpochEnd'),'String'));

        epochStartSec = str2double(get(findobj(fig,'Tag','erpEpochStart'),'String')) / 1000;
        epochEndSec   = str2double(get(findobj(fig,'Tag','erpEpochEnd'),  'String')) / 1000;

        % Check whether each event type has usable epochs (not hitting boundary)
        lines{end+1} = '';
        lines{end+1} = 'EPOCH FEASIBILITY CHECK:';
        for i = 1:length(uTypes)
            idx = find(strcmp(allTypes, uTypes{i}));
            lats = [EEG.event(idx).latency] / EEG.srate;
            ok = sum((lats + epochStartSec) >= 0 & (lats + epochEndSec) <= EEG.xmax);
            lines{end+1} = sprintf('  ''%s'': %d/%d events within data boundaries', ...
                uTypes{i}, ok, length(idx));
        end

        lines{end+1} = '';
        lines{end+1} = 'RECOMMENDATION:';
        useYIMIMG = get(findobj(fig,'Tag','erpYIMIMGCheck'),'Value');
        if useYIMIMG
            lines{end+1} = '  YIMIMG mode is ON — events will be retyped by sequential position.';
            lines{end+1} = sprintf('  File has %d total events; YIMIMG maps positions 1-48.', nEv);
            if nEv < 16
                lines{end+1} = '  WARNING: Too few events for YIMIMG mapping (need at least 16).';
            end
        else
            lines{end+1} = '  Generic mode — use type strings above as event codes.';
            lines{end+1} = '  Example: enter  HT B  in the Codes box for condition 1.';
            lines{end+1} = '  Or leave blank to auto-detect all types.';
        end
    end

    % Channel info
    lines{end+1} = '';
    labels = erpGetChanLabels(EEG);
    lines{end+1} = sprintf('CHANNELS (%d): %s', EEG.nbchan, strjoin(labels, ', '));

    % Log to ERP log
    for i = 1:length(lines)
        erpLog(fig, lines{i});
    end

    % Also show in a message dialog
    msgStr = strjoin(lines, newline);
    msgbox(msgStr, sprintf('Event Inspector — %s', fBase), 'help');
end

%% ========================================================================
%  HELPER: get channel labels from EEG struct
%  ========================================================================
function labels = erpGetChanLabels(EEG)
    if isfield(EEG, 'chanlocs') && ~isempty(EEG.chanlocs) && isfield(EEG.chanlocs, 'labels')
        labels = {EEG.chanlocs.labels};
        % Remove empty entries
        labels = labels(~cellfun(@isempty, labels));
    else
        labels = arrayfun(@(i) sprintf('Ch%d', i), 1:EEG.nbchan, 'UniformOutput', false);
    end
end

%% ========================================================================
%  HELPER: auto-detect unique event types across a list of .set files
%  ========================================================================
function [condStr, condNames, condColors] = erpAutoDetectConditions(fileList, fig)
    condStr = {}; condNames = {}; condColors = {};
    allTypes = {};

    for fi = 1:length(fileList)
        [fDir, fBase, ~] = fileparts(fileList{fi});
        try
            EEG = pop_loadset('filename', [fBase '.set'], 'filepath', fDir);
            if isfield(EEG, 'event') && ~isempty(EEG.event)
                for ei = 1:length(EEG.event)
                    t = EEG.event(ei).type;
                    if isnumeric(t), t = num2str(t); end
                    t = strtrim(char(t));
                    if ~isempty(t) && ~any(strcmp(allTypes, t))
                        allTypes{end+1} = t; %#ok<AGROW>
                    end
                end
            end
        catch
        end
    end

    if isempty(allTypes), return; end

    % Sort types (try numeric sort, fall back to string sort)
    nums = str2double(allTypes);
    if all(~isnan(nums))
        [~, ord] = sort(nums);
    else
        [~, ord] = sort(allTypes);
    end
    allTypes = allTypes(ord);

    erpLog(fig, sprintf('  Unique event types found: %s', strjoin(allTypes, ', ')));

    % Build a color palette cycling through distinct colors
    palette = {[0.0,0.68,0.18],[1.0,0.50,0.0],[0.85,0.08,0.08], ...
               [0.0,0.45,0.74],[0.49,0.18,0.56],[0.47,0.67,0.19], ...
               [0.30,0.75,0.93],[0.64,0.08,0.18],[0.93,0.69,0.13]};

    nT = length(allTypes);
    condStr    = cell(1, nT);
    condNames  = cell(1, nT);
    condColors = cell(1, nT);
    for i = 1:nT
        condStr{i}    = {allTypes{i}};
        condNames{i}  = allTypes{i};
        condColors{i} = palette{mod(i-1, length(palette)) + 1};
    end
end

%% ========================================================================
%  CHANNEL GRID VIEW
%  ========================================================================
function erpChannelGrid(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if ~isfield(appData, 'erpResult') || ...
       ~isfield(appData.erpResult, 'erpFull') || ...
       isempty(appData.erpResult.erpFull) || ...
       all(cellfun(@isempty, appData.erpResult.erpFull))
        errordlg('No ERP data available. Run ERP Analysis first.', 'No Data');
        return;
    end

    r = appData.erpResult;

    % Find first non-empty full ERP to determine nChan
    nChan = 0;
    for c = 1:length(r.erpFull)
        if ~isempty(r.erpFull{c})
            nChan = size(r.erpFull{c}, 1);
            break;
        end
    end
    if nChan == 0
        errordlg('No channel data in ERP results.', 'No Data');
        return;
    end

    labels = r.chanLabels;
    if isempty(labels)
        labels = arrayfun(@(i) sprintf('Ch%d', i), 1:nChan, 'UniformOutput', false);
    end
    % Ensure labels vector is long enough
    while length(labels) < nChan
        labels{end+1} = sprintf('Ch%d', length(labels)+1);
    end

    % Grid layout
    nCols = ceil(sqrt(nChan));
    nRows = ceil(nChan / nCols);

    figW = min(1800, max(900,  nCols * 160));
    figH = min(1000, max(600,  nRows * 140));

    gFig = figure('Name', 'ERP Channel Grid View', ...
                  'Position', [30, 30, figW, figH], ...
                  'NumberTitle', 'off');

    condColors = r.colors;
    condNames  = r.names;
    nCond      = length(r.erpFull);

    yAll = [];
    for c = 1:nCond
        if ~isempty(r.erpFull{c})
            yAll = [yAll, r.erpFull{c}(:)']; %#ok<AGROW>
        end
    end
    if ~isempty(yAll)
        yLim = [min(yAll)*1.15, max(yAll)*1.15];
        if yLim(1) == yLim(2), yLim = yLim + [-1 1]; end
    else
        yLim = [-5 5];
    end

    for ch = 1:nChan
        ax = subplot(nRows, nCols, ch);
        hold(ax, 'on');

        for c = 1:nCond
            if ~isempty(r.erpFull{c}) && ch <= size(r.erpFull{c}, 1)
                plot(ax, r.time, r.erpFull{c}(ch,:), '-', ...
                     'Color', condColors{c}, 'LineWidth', 1.2, ...
                     'DisplayName', condNames{c});
            end
        end

        xline(ax, 0, '--k', 'LineWidth', 0.6, 'HandleVisibility', 'off');
        yline(ax, 0,  '-k', 'LineWidth', 0.3, 'HandleVisibility', 'off');

        title(ax, labels{ch}, 'FontSize', 8, 'FontWeight', 'bold');
        set(ax, 'FontSize', 6.5, 'XLim', [r.time(1), r.time(end)], 'YLim', yLim, 'Box', 'on');
        xlabel(ax, 'ms', 'FontSize', 6);
        ylabel(ax, '\muV', 'FontSize', 6);

        hold(ax, 'off');
    end

    % Shared legend in its own invisible axes
    axLeg = axes('Parent', gFig, 'Position', [0, 0, 1, 1], 'Visible', 'off');
    hold(axLeg, 'on');
    for c = 1:nCond
        plot(axLeg, NaN, NaN, '-', 'Color', condColors{c}, 'LineWidth', 2, ...
             'DisplayName', sprintf('%s (n=%d)', condNames{c}, r.nTrials(c)));
    end
    legend(axLeg, 'show', 'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 9);
    hold(axLeg, 'off');

    sgtitle(gFig, 'ERP per Channel — all conditions', 'FontSize', 12, 'FontWeight', 'bold');
end

function erpPlotResultsGeneric(fig, timeVec, erpCell, condNames, condColors, nTrials)
    % Generic overlay plot for any number of conditions
    ax = findobj(fig, 'Tag', 'erpAxes');
    cla(ax);
    hold(ax, 'on');

    hasData = false;
    for c = 1:length(erpCell)
        if isempty(erpCell{c}) || isempty(timeVec), continue; end
        plot(ax, timeVec, erpCell{c}, '-', ...
             'Color', condColors{c}, 'LineWidth', 2.2, ...
             'DisplayName', sprintf('%s  (n=%d)', condNames{c}, nTrials(c)));
        hasData = true;
    end

    if hasData
        xline(ax, 0, '--k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        yline(ax, 0, '-k',  'LineWidth', 0.5, 'HandleVisibility', 'off');
        legend(ax, 'show', 'Location', 'northeast', 'FontSize', 10);
        xlabel(ax, 'Time (ms)', 'FontSize', 10);
        ylabel(ax, 'Amplitude (\muV)', 'FontSize', 10);
        % Build title from condition names
        titleStr = 'Grand Average ERPs';
        for c = 1:length(condNames)
            if ~isempty(erpCell{c})
                titleStr = [titleStr '  —  ' condNames{c}]; %#ok<AGROW>
            end
        end
        title(ax, titleStr, 'FontSize', 11, 'FontWeight', 'bold');
        grid(ax, 'on');
    end

    hold(ax, 'off');
    drawnow;
end

function erpSaveFigure(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if ~isfield(appData, 'erpResult') || isempty(appData.erpResult.time)
        errordlg('No ERP results to save. Run analysis first.', 'No Data');
        return;
    end

    [fname, pname] = uiputfile( ...
        {'*.png','PNG image'; '*.pdf','PDF file'; '*.fig','MATLAB figure'}, ...
        'Save ERP Figure', 'ERP_GrandAverage.png');
    if isequal(fname, 0), return; end

    r    = appData.erpResult;
    hFig = figure('Visible', 'off', 'Position', [100, 100, 960, 520]);
    axNew = axes('Parent', hFig);
    hold(axNew, 'on');
    for c = 1:length(r.erp)
        if isempty(r.erp{c}), continue; end
        plot(axNew, r.time, r.erp{c}, '-', 'Color', r.colors{c}, 'LineWidth', 2.2, ...
             'DisplayName', sprintf('%s  (n=%d)', r.names{c}, r.nTrials(c)));
    end
    xline(axNew, 0, '--k', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    yline(axNew, 0, '-k',  'LineWidth', 0.5, 'HandleVisibility', 'off');
    legend(axNew, 'show', 'Location', 'northeast', 'FontSize', 10);
    xlabel(axNew, 'Time (ms)', 'FontSize', 11);
    ylabel(axNew, 'Amplitude (\muV)', 'FontSize', 11);
    titleStr = 'Grand Average ERPs';
    for c = 1:length(r.names)
        if ~isempty(r.erp{c}), titleStr = [titleStr '  —  ' r.names{c}]; end %#ok<AGROW>
    end
    title(axNew, titleStr, 'FontSize', 13, 'FontWeight', 'bold');
    grid(axNew, 'on');
    hold(axNew, 'off');

    saveas(hFig, fullfile(pname, fname));
    delete(hFig);
    erpLog(fig, sprintf('Figure saved: %s', fullfile(pname, fname)));
end

function erpExportData(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if ~isfield(appData, 'erpResult') || isempty(appData.erpResult.time)
        errordlg('No ERP results to export. Run analysis first.', 'No Data');
        return;
    end

    [fname, pname] = uiputfile('*.mat', 'Export Averaged ERP Data', 'ERP_GrandAverage.mat');
    if isequal(fname, 0), return; end

    r = appData.erpResult;
    erpData.time    = r.time;
    erpData.erp     = r.erp;
    erpData.names   = r.names;
    erpData.nTrials = r.nTrials;
    erpData.info    = strjoin(r.names, ' | ');

    save(fullfile(pname, fname), 'erpData');
    erpLog(fig, sprintf('ERP data exported: %s', fullfile(pname, fname)));
end

function erpClearPlot(hObject, ~)
    fig = ancestor(hObject, 'figure');
    ax  = findobj(fig, 'Tag', 'erpAxes');
    cla(ax);
    xlabel(ax, 'Time (ms)', 'FontSize', 10);
    ylabel(ax, 'Amplitude (\muV)', 'FontSize', 10);
    title(ax, 'ERP  —  Load data and click RUN', 'FontSize', 11, 'FontWeight', 'bold');
    grid(ax, 'on');
    erpLog(fig, 'Plot cleared.');
end

function erpLog(fig, msg)
    logBox = findobj(fig, 'Tag', 'erpLog');
    if isempty(logBox), return; end
    currentLog = get(logBox, 'String');
    if ischar(currentLog), currentLog = {currentLog}; end
    newMsg = sprintf('[%s] %s', datestr(now, 'HH:MM:SS'), msg);
    currentLog{end+1} = newMsg;
    if length(currentLog) > 200
        currentLog = currentLog(end-199:end);
    end
    set(logBox, 'String', currentLog, 'Value', length(currentLog));
    drawnow;
end

function erpSetStatus(fig, status)
    h = findobj(fig, 'Tag', 'erpStatusText');
    if ~isempty(h), set(h, 'String', status); end
    drawnow;
end

%% ========================================================================
%  CLEANING CALLBACKS
%  ========================================================================

function cleanLoadFile(hObject, ~)
    fig = ancestor(hObject, 'figure');

    [filename, pathname] = uigetfile('*.set', 'Select EEGLAB .set file');
    if isequal(filename, 0)
        return;
    end

    filePath = fullfile(pathname, filename);

    appData = guidata(fig);
    appData.cleanFiles = {filePath};
    appData.cleanBatchResults = {};
    appData.cleanCurrentFileIdx = 1;
    guidata(fig, appData);

    cleanUpdateFileList(fig);
    cleanLoadCurrentFile(fig);
end

function cleanLoadFolder(hObject, ~)
    fig = ancestor(hObject, 'figure');

    folderPath = uigetdir('', 'Select folder containing .set files');
    if isequal(folderPath, 0)
        return;
    end

    setFiles = dir(fullfile(folderPath, '*.set'));

    if isempty(setFiles)
        cleanLog(fig, 'No .set files found in selected folder.');
        return;
    end

    appData = guidata(fig);
    appData.cleanFiles = cell(1, length(setFiles));
    for i = 1:length(setFiles)
        appData.cleanFiles{i} = fullfile(folderPath, setFiles(i).name);
    end
    appData.cleanBatchResults = {};
    appData.cleanCurrentFileIdx = 1;
    guidata(fig, appData);

    cleanUpdateFileList(fig);
    cleanLoadCurrentFile(fig);

    cleanLog(fig, sprintf('Loaded %d .set files for batch processing.', length(setFiles)));
end

function cleanClearFiles(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    appData.cleanFiles = {};
    appData.cleanEEG = [];
    appData.cleanEEGRaw = [];
    appData.cleanFilePath = '';
    appData.cleanBatchResults = {};
    appData.cleanCurrentFileIdx = 0;
    guidata(fig, appData);

    cleanUpdateFileList(fig);
    cleanResetMetrics(fig);

    fileText = findobj(fig, 'Tag', 'cleanFileText');
    set(fileText, 'String', 'No files loaded');
    infoText = findobj(fig, 'Tag', 'cleanDataInfo');
    set(infoText, 'String', '');

    cleanLog(fig, 'File list cleared.');
end

function cleanUpdateFileList(fig)
    appData = guidata(fig);
    listBox = findobj(fig, 'Tag', 'cleanFileList');

    if isempty(appData.cleanFiles)
        set(listBox, 'String', {'(No files loaded)'}, 'Value', 1);
    else
        fileNames = cell(size(appData.cleanFiles));
        for i = 1:length(appData.cleanFiles)
            [~, name, ext] = fileparts(appData.cleanFiles{i});
            fileNames{i} = [name, ext];
        end
        val = min(appData.cleanCurrentFileIdx, length(fileNames));
        if val < 1, val = 1; end
        set(listBox, 'String', fileNames, 'Value', val);
    end
end

function cleanFileListSelect(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    idx = get(hObject, 'Value');
    if idx > 0 && idx <= length(appData.cleanFiles)
        appData.cleanCurrentFileIdx = idx;
        guidata(fig, appData);
        cleanLoadCurrentFile(fig);
    end
end

function cleanLoadCurrentFile(fig)
    appData = guidata(fig);

    if isempty(appData.cleanFiles) || appData.cleanCurrentFileIdx < 1
        return;
    end

    filePath = appData.cleanFiles{appData.cleanCurrentFileIdx};
    [pathname, filename, ext] = fileparts(filePath);
    filename = [filename, ext];

    cleanLog(fig, sprintf('Loading: %s', filename));
    cleanSetStatus(fig, 'Loading...');

    try
        if ~exist('pop_loadset', 'file')
            cleanLog(fig, 'ERROR: EEGLAB not found. Please add EEGLAB to path.');
            cleanSetStatus(fig, 'EEGLAB not found');
            return;
        end

        EEG = pop_loadset('filename', filename, 'filepath', pathname);
        EEG = eeg_checkset(EEG);

        appData.cleanEEG = EEG;
        appData.cleanEEGRaw = EEG;
        appData.cleanFilePath = filePath;
        guidata(fig, appData);

        % Update UI
        fileText = findobj(fig, 'Tag', 'cleanFileText');
        if length(appData.cleanFiles) > 1
            set(fileText, 'String', sprintf('[%d/%d] %s', appData.cleanCurrentFileIdx, ...
                                            length(appData.cleanFiles), filePath));
        else
            set(fileText, 'String', filePath);
        end

        infoText = findobj(fig, 'Tag', 'cleanDataInfo');
        nEvents = 0;
        if isfield(EEG, 'event') && ~isempty(EEG.event)
            nEvents = length(EEG.event);
        end
        infoStr = sprintf('%d ch, %d samples, %.1f sec, %d Hz, %d events', ...
                          EEG.nbchan, EEG.pnts, EEG.xmax, EEG.srate, nEvents);
        set(infoText, 'String', infoStr);

        cleanLog(fig, sprintf('  Channels: %d, Samples: %d, Duration: %.1f sec, Events: %d', ...
                              EEG.nbchan, EEG.pnts, EEG.xmax, nEvents));
        cleanSetStatus(fig, 'File loaded');

        cleanResetMetrics(fig);

    catch ME
        cleanLog(fig, sprintf('ERROR loading file: %s', ME.message));
        cleanSetStatus(fig, 'Load failed');
    end
end

%% ========================================================================
%  MAIN PROCESSING
%  ========================================================================

function cleanRunProcessing(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.cleanFiles)
        cleanLog(fig, 'ERROR: No files loaded. Please load .set file(s) first.');
        return;
    end

    if appData.cleanIsProcessing
        cleanLog(fig, 'Processing already in progress...');
        return;
    end

    % Check GEDAI availability
    doGEDAI = get(findobj(fig, 'Tag', 'cleanGEDAICheck'), 'Value');
    if doGEDAI && ~exist('pop_GEDAI', 'file')
        cleanLog(fig, 'ERROR: GEDAI plugin not found.');
        cleanLog(fig, '  Install from: https://github.com/neurotuning/GEDAI-master');
        cleanLog(fig, '  Place GEDAI-master folder in EEGLAB/plugins/ and restart EEGLAB.');
        return;
    end

    appData.cleanIsProcessing = true;
    appData.cleanBatchResults = {};
    guidata(fig, appData);

    set(hObject, 'Enable', 'off', 'String', 'Processing...');
    drawnow;

    totalFiles = length(appData.cleanFiles);
    autoSave = get(findobj(fig, 'Tag', 'cleanAutoSave'), 'Value');

    cleanLog(fig, '========================================');
    cleanLog(fig, sprintf('Starting GEDAI Cleaning on %d file(s)...', totalFiles));
    cleanLog(fig, '========================================');

    for fileIdx = 1:totalFiles
        appData = guidata(fig);
        appData.cleanCurrentFileIdx = fileIdx;
        guidata(fig, appData);

        cleanUpdateFileList(fig);
        cleanLoadCurrentFile(fig);

        appData = guidata(fig);
        if isempty(appData.cleanEEG)
            cleanLog(fig, sprintf('[%d/%d] SKIP: Failed to load file', fileIdx, totalFiles));
            continue;
        end

        cleanLog(fig, sprintf('[%d/%d] Processing: %s', fileIdx, totalFiles, ...
                              appData.cleanEEG.setname));

        try
            [EEG, metrics] = cleanProcessSingleFile(fig, appData.cleanEEG);

            % Store results
            appData = guidata(fig);
            result = struct();
            result.filename = appData.cleanEEG.setname;
            result.filepath = appData.cleanFilePath;
            result.metrics = metrics;
            result.success = true;
            appData.cleanBatchResults{fileIdx} = result;

            % Update current EEG (keep raw for comparison)
            appData.cleanEEG = EEG;
            guidata(fig, appData);

            % Update metrics display
            cleanUpdateMetrics(fig, metrics);

            % Auto-save if enabled
            if autoSave
                [savePath, saveName, ~] = fileparts(appData.cleanFilePath);
                cleanedFolder = fullfile(savePath, 'GEDAI_Cleaned');
                if ~exist(cleanedFolder, 'dir')
                    mkdir(cleanedFolder);
                end
                cleanedName = [saveName, '_gedai.set'];
                pop_saveset(EEG, 'filename', cleanedName, 'filepath', cleanedFolder);
                cleanLog(fig, sprintf('  Saved: %s', fullfile('GEDAI_Cleaned', cleanedName)));
            end

            cleanLog(fig, sprintf('  Result: %s', metrics.overallQuality));

        catch ME
            cleanLog(fig, sprintf('  ERROR: %s', ME.message));
            appData = guidata(fig);
            result = struct();
            result.filename = appData.cleanEEG.setname;
            result.filepath = appData.cleanFilePath;
            result.metrics = struct('overallQuality', 'ERROR', 'error', ME.message);
            result.success = false;
            appData.cleanBatchResults{fileIdx} = result;
            guidata(fig, appData);
        end

        drawnow;
    end

    % Summary
    cleanLog(fig, '========================================');
    cleanLog(fig, 'GEDAI Cleaning Complete!');

    appData = guidata(fig);
    successCount = sum(cellfun(@(x) x.success, appData.cleanBatchResults));
    cleanLog(fig, sprintf('  Processed: %d / %d files', successCount, totalFiles));

    if autoSave
        cleanLog(fig, '  Output folder: GEDAI_Cleaned');
    end
    cleanLog(fig, '========================================');

    % Enable save button
    saveBtn = findobj(fig, 'Tag', 'cleanSaveBtn');
    set(saveBtn, 'Enable', 'on');

    appData.cleanIsProcessing = false;
    guidata(fig, appData);
    set(hObject, 'Enable', 'on', 'String', 'RUN GEDAI');
    cleanSetStatus(fig, 'Complete');
end

function [EEG, metrics] = cleanProcessSingleFile(fig, EEG)
    metrics = struct();

    % Store original data info
    origData = EEG.data;
    origVar = var(EEG.data(:));

    % Get options
    doFilter = get(findobj(fig, 'Tag', 'cleanFilterCheck'), 'Value');
    doGEDAI = get(findobj(fig, 'Tag', 'cleanGEDAICheck'), 'Value');

    % ---- 1. Bandpass Filter ----
    if doFilter
        cleanLog(fig, '  Applying bandpass filter...');
        cleanSetStatus(fig, 'Filtering...');

        highpass = str2double(get(findobj(fig, 'Tag', 'cleanHighpass'), 'String'));
        lowpass = str2double(get(findobj(fig, 'Tag', 'cleanLowpass'), 'String'));

        if exist('pop_eegfiltnew', 'file')
            EEG = pop_eegfiltnew(EEG, highpass, lowpass);
        elseif exist('pop_basicfilter', 'file')
            EEG = pop_basicfilter(EEG, 1:EEG.nbchan, 'Cutoff', [highpass lowpass], ...
                                  'Design', 'butter', 'Filter', 'bandpass');
        else
            cleanLog(fig, '    WARNING: Filter functions not found, skipping...');
        end
        metrics.filterApplied = true;
        metrics.highpass = highpass;
        metrics.lowpass = lowpass;
        cleanLog(fig, sprintf('    Bandpass: %.1f - %.0f Hz', highpass, lowpass));
    else
        metrics.filterApplied = false;
    end

    % ---- 2. GEDAI Cleaning ----
    metrics.gedaiApplied = false;
    metrics.gedaiArtifacts = 0;
    metrics.gedaiThreshold = [];

    if doGEDAI
        cleanLog(fig, '  Running GEDAI artifact removal...');
        cleanSetStatus(fig, 'Running GEDAI...');

        artThreshold = str2double(get(findobj(fig, 'Tag', 'cleanGEDAIThreshold'), 'String'));
        epochCycles = str2double(get(findobj(fig, 'Tag', 'cleanGEDAIEpoch'), 'String'));
        useParallel = get(findobj(fig, 'Tag', 'cleanGEDAIParallel'), 'Value');

        refTypeMenu = findobj(fig, 'Tag', 'cleanGEDAIRefType');
        refTypes = get(refTypeMenu, 'String');
        refType = refTypes{get(refTypeMenu, 'Value')};

        % Get highpass value for GEDAI (use filter HP if applied, else default)
        if doFilter
            gedaiLowcut = highpass;
        else
            gedaiLowcut = 0.5;
        end

        % Ensure data is double
        EEG.data = double(EEG.data);

        try
            cleanLog(fig, sprintf('    Threshold: %g, Epochs: %g cycles, Ref: %s', ...
                                  artThreshold, epochCycles, refType));

            [EEG, ARTIFACTS, ~, ~, ~, ~] = pop_GEDAI(EEG, artThreshold, ...
                                                       epochCycles, gedaiLowcut, ...
                                                       refType, useParallel, 0);

            metrics.gedaiApplied = true;
            metrics.gedaiThreshold = artThreshold;
            metrics.gedaiEpochCycles = epochCycles;
            metrics.gedaiRefType = refType;

            % Count artifact components
            if ~isempty(ARTIFACTS)
                if isstruct(ARTIFACTS)
                    metrics.gedaiArtifacts = numel(fieldnames(ARTIFACTS));
                elseif ismatrix(ARTIFACTS)
                    metrics.gedaiArtifacts = size(ARTIFACTS, 2);
                else
                    metrics.gedaiArtifacts = numel(ARTIFACTS);
                end
            end

            cleanLog(fig, sprintf('    GEDAI complete. Artifacts identified: %d', ...
                                  metrics.gedaiArtifacts));

        catch ME
            cleanLog(fig, sprintf('    GEDAI error: %s', ME.message));
            cleanLog(fig, '    Check GEDAI installation and channel locations.');
        end
    end

    % ---- Calculate quality metrics ----

    % Retained variance
    newVar = var(EEG.data(:));
    metrics.retainedVariance = (newVar / origVar) * 100;

    % Data rank
    metrics.dataRank = rank(double(EEG.data'));
    metrics.nbchan = EEG.nbchan;
    metrics.pnts = EEG.pnts;
    metrics.srate = EEG.srate;
    metrics.duration = EEG.xmax;

    % Event count
    if isfield(EEG, 'event') && ~isempty(EEG.event)
        metrics.nEvents = length(EEG.event);
    else
        metrics.nEvents = 0;
    end

    % SNR estimation
    signalVar = var(mean(EEG.data, 1));
    noiseVar = mean(var(EEG.data, 0, 2));
    metrics.snr = 10 * log10(signalVar / max(noiseVar, eps));

    % Overall quality rating
    metrics.overallQuality = calculateCleanQuality(metrics, EEG);
end

function quality = calculateCleanQuality(metrics, EEG)
    score = 0;
    maxScore = 0;

    % Retained variance (weight: 30)
    maxScore = maxScore + 30;
    if metrics.retainedVariance >= 85
        score = score + 30;
    elseif metrics.retainedVariance >= 70
        score = score + 22;
    elseif metrics.retainedVariance >= 55
        score = score + 15;
    elseif metrics.retainedVariance >= 40
        score = score + 8;
    end

    % Data rank (weight: 30)
    maxScore = maxScore + 30;
    rankRatio = metrics.dataRank / EEG.nbchan;
    if rankRatio >= 0.9
        score = score + 30;
    elseif rankRatio >= 0.7
        score = score + 22;
    elseif rankRatio >= 0.5
        score = score + 15;
    else
        score = score + 5;
    end

    % SNR (weight: 40)
    maxScore = maxScore + 40;
    if metrics.snr >= 10
        score = score + 40;
    elseif metrics.snr >= 5
        score = score + 30;
    elseif metrics.snr >= 0
        score = score + 20;
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

%% ========================================================================
%  METRICS DISPLAY
%  ========================================================================

function cleanUpdateMetrics(fig, metrics)
    qualityText = findobj(fig, 'Tag', 'cleanOverallQuality');
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

    set(findobj(fig, 'Tag', 'cleanVariance'), 'String', sprintf('%.1f%%', metrics.retainedVariance));
    set(findobj(fig, 'Tag', 'cleanArtifacts'), 'String', sprintf('%d components', metrics.gedaiArtifacts));
    set(findobj(fig, 'Tag', 'cleanRank'), 'String', sprintf('%d / %d', metrics.dataRank, metrics.nbchan));
    set(findobj(fig, 'Tag', 'cleanSNR'), 'String', sprintf('%.1f dB', metrics.snr));
    set(findobj(fig, 'Tag', 'cleanEvents'), 'String', sprintf('%d', metrics.nEvents));
end

function cleanResetMetrics(fig)
    set(findobj(fig, 'Tag', 'cleanOverallQuality'), 'String', '---', 'ForegroundColor', [0, 0, 0]);
    set(findobj(fig, 'Tag', 'cleanVariance'), 'String', '---');
    set(findobj(fig, 'Tag', 'cleanArtifacts'), 'String', '---');
    set(findobj(fig, 'Tag', 'cleanRank'), 'String', '---');
    set(findobj(fig, 'Tag', 'cleanSNR'), 'String', '---');
    set(findobj(fig, 'Tag', 'cleanEvents'), 'String', '---');

    saveBtn = findobj(fig, 'Tag', 'cleanSaveBtn');
    set(saveBtn, 'Enable', 'off');
end

%% ========================================================================
%  ACTION CALLBACKS
%  ========================================================================

function cleanSaveData(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.cleanEEG)
        cleanLog(fig, 'ERROR: No data to save.');
        return;
    end

    [origPath, origName, ~] = fileparts(appData.cleanFilePath);
    defaultName = [origName, '_gedai.set'];

    [filename, pathname] = uiputfile('*.set', 'Save Cleaned Data', fullfile(origPath, defaultName));
    if isequal(filename, 0)
        return;
    end

    try
        cleanLog(fig, sprintf('Saving to: %s', filename));
        pop_saveset(appData.cleanEEG, 'filename', filename, 'filepath', pathname);
        cleanLog(fig, 'Data saved successfully.');
        cleanSetStatus(fig, 'Saved');
    catch ME
        cleanLog(fig, sprintf('ERROR saving: %s', ME.message));
    end
end

function cleanViewData(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.cleanEEG)
        cleanLog(fig, 'ERROR: No data loaded.');
        return;
    end

    try
        if exist('pop_eegplot', 'file')
            pop_eegplot(appData.cleanEEG, 1, 1, 1);
            cleanLog(fig, 'Opened EEGLAB data viewer.');
        else
            cleanLog(fig, 'ERROR: EEGLAB viewer not available.');
        end
    catch ME
        cleanLog(fig, sprintf('ERROR: %s', ME.message));
    end
end

function cleanCompare(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.cleanEEG) || isempty(appData.cleanEEGRaw)
        cleanLog(fig, 'ERROR: No data available. Run GEDAI first.');
        return;
    end

    if ~exist('pop_eegplot', 'file')
        cleanLog(fig, 'ERROR: EEGLAB viewer not available.');
        return;
    end

    EEGraw = appData.cleanEEGRaw;
    EEGclean = appData.cleanEEG;

    if isequal(EEGraw.data, EEGclean.data)
        cleanLog(fig, 'No difference — run GEDAI cleaning first.');
        return;
    end

    % Open Raw in EEGLAB scroll viewer
    EEGraw.setname = [EEGraw.setname ' (Raw)'];
    pop_eegplot(EEGraw, 1, 1, 1);
    cleanLog(fig, 'Opened Raw data in EEGLAB viewer.');

    % Open Cleaned in EEGLAB scroll viewer
    EEGclean.setname = [EEGclean.setname ' (GEDAI Cleaned)'];
    pop_eegplot(EEGclean, 1, 1, 1);
    cleanLog(fig, 'Opened Cleaned data in EEGLAB viewer.');
    cleanLog(fig, 'Compare both windows side by side.');
end

function cleanViewSpectrum(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.cleanEEG)
        cleanLog(fig, 'ERROR: No data loaded.');
        return;
    end

    EEG = appData.cleanEEG;

    specFig = figure('Name', sprintf('Power Spectrum - %s', EEG.setname), ...
                     'NumberTitle', 'off', ...
                     'Position', [150, 120, 800, 500]);

    nfft = min(EEG.srate * 4, EEG.pnts);
    fMax = min(50, EEG.srate / 2);

    % Average across channels
    avgData = mean(double(EEG.data), 1);
    [pxx, f] = pwelch(avgData, hanning(nfft), nfft/2, nfft, EEG.srate);
    fIdx = f <= fMax;

    % Also show raw if available
    hasRaw = ~isempty(appData.cleanEEGRaw) && ~isequal(appData.cleanEEGRaw.data, EEG.data);

    if hasRaw
        avgRaw = mean(double(appData.cleanEEGRaw.data), 1);
        [pxxRaw, fRaw] = pwelch(avgRaw, hanning(nfft), nfft/2, nfft, EEG.srate);
        fIdxRaw = fRaw <= fMax;

        plot(fRaw(fIdxRaw), 10*log10(pxxRaw(fIdxRaw)), 'r', 'LineWidth', 1.5);
        hold on;
        plot(f(fIdx), 10*log10(pxx(fIdx)), 'b', 'LineWidth', 1.5);
        legend('Raw', 'Cleaned', 'Location', 'northeast');
        hold off;
    else
        plot(f(fIdx), 10*log10(pxx(fIdx)), 'b', 'LineWidth', 1.5);
    end

    xlabel('Frequency (Hz)');
    ylabel('Power (dB)');
    title(sprintf('Average Power Spectrum — %s', EEG.setname));
    xlim([0, fMax]);
    grid on;

    cleanLog(fig, 'Opened power spectrum plot.');
end

%% ========================================================================
%  EXPORT FUNCTIONS
%  ========================================================================

function cleanExportExcel(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.cleanBatchResults)
        cleanLog(fig, 'ERROR: No results to export. Run GEDAI first.');
        return;
    end

    if ~isempty(appData.cleanFiles)
        [defaultPath, ~, ~] = fileparts(appData.cleanFiles{1});
    else
        defaultPath = pwd;
    end

    defaultName = sprintf('GEDAI_Report_%s.xlsx', datestr(now, 'yyyy-mm-dd_HHMMSS'));
    [filename, pathname] = uiputfile('*.xlsx', 'Export GEDAI Report to Excel', ...
                                      fullfile(defaultPath, defaultName));
    if isequal(filename, 0)
        return;
    end

    try
        cleanLog(fig, 'Exporting to Excel...');

        nFiles = length(appData.cleanBatchResults);

        headers = {'Filename', 'Quality', 'Retained_Var_pct', 'GEDAI_Artifacts', ...
                   'Data_Rank', 'Channels', 'SNR_dB', 'Events', ...
                   'Samples', 'Duration_sec', 'SampleRate_Hz', ...
                   'Filter_Applied', 'Highpass_Hz', 'Lowpass_Hz', ...
                   'GEDAI_Applied', 'GEDAI_Threshold', 'GEDAI_Epochs', ...
                   'GEDAI_RefType', 'Filepath'};

        data = cell(nFiles, length(headers));

        for i = 1:nFiles
            result = appData.cleanBatchResults{i};
            m = result.metrics;

            data{i, 1} = result.filename;
            data{i, 2} = m.overallQuality;

            if result.success
                data{i, 3} = m.retainedVariance;
                data{i, 4} = m.gedaiArtifacts;
                data{i, 5} = m.dataRank;
                data{i, 6} = m.nbchan;
                data{i, 7} = m.snr;
                data{i, 8} = m.nEvents;
                data{i, 9} = m.pnts;
                data{i, 10} = m.duration;
                data{i, 11} = m.srate;

                if isfield(m, 'filterApplied')
                    data{i, 12} = m.filterApplied;
                    if m.filterApplied
                        data{i, 13} = m.highpass;
                        data{i, 14} = m.lowpass;
                    end
                end

                data{i, 15} = m.gedaiApplied;
                if m.gedaiApplied
                    data{i, 16} = m.gedaiThreshold;
                    if isfield(m, 'gedaiEpochCycles')
                        data{i, 17} = m.gedaiEpochCycles;
                    end
                    if isfield(m, 'gedaiRefType')
                        data{i, 18} = m.gedaiRefType;
                    end
                end
            else
                data{i, 3} = 'ERROR';
            end

            data{i, 19} = result.filepath;
        end

        T = cell2table(data, 'VariableNames', headers);
        writetable(T, fullfile(pathname, filename), 'Sheet', 'GEDAI_Results');

        % Summary sheet
        summaryData = {
            'GEDAI Cleaning Report', '';
            'Generated', datestr(now);
            'Total Files', nFiles;
            'Excellent', sum(strcmp(data(:, 2), 'EXCELLENT'));
            'Good', sum(strcmp(data(:, 2), 'GOOD'));
            'Moderate', sum(strcmp(data(:, 2), 'MODERATE'));
            'Poor', sum(strcmp(data(:, 2), 'POOR'));
            'Errors', sum(strcmp(data(:, 2), 'ERROR'));
        };

        writecell(summaryData, fullfile(pathname, filename), 'Sheet', 'Summary');

        cleanLog(fig, sprintf('Excel report saved: %s', filename));
        cleanSetStatus(fig, 'Excel exported');

    catch ME
        cleanLog(fig, sprintf('ERROR exporting Excel: %s', ME.message));
    end
end

function cleanExportReport(hObject, ~)
    fig = ancestor(hObject, 'figure');
    appData = guidata(fig);

    if isempty(appData.cleanBatchResults)
        cleanLog(fig, 'ERROR: No results to export. Run GEDAI first.');
        return;
    end

    if ~isempty(appData.cleanFiles)
        [defaultPath, ~, ~] = fileparts(appData.cleanFiles{1});
    else
        defaultPath = pwd;
    end

    defaultName = sprintf('GEDAI_Report_%s.txt', datestr(now, 'yyyy-mm-dd_HHMMSS'));
    [filename, pathname] = uiputfile('*.txt', 'Export GEDAI Report', fullfile(defaultPath, defaultName));
    if isequal(filename, 0)
        return;
    end

    try
        fid = fopen(fullfile(pathname, filename), 'w');

        fprintf(fid, 'WiBCI EEG GEDAI Cleaning Report\n');
        fprintf(fid, '================================\n\n');
        fprintf(fid, 'Date: %s\n', datestr(now));
        fprintf(fid, 'Total Files: %d\n\n', length(appData.cleanBatchResults));

        for i = 1:length(appData.cleanBatchResults)
            result = appData.cleanBatchResults{i};
            m = result.metrics;

            fprintf(fid, '----------------------------------------\n');
            fprintf(fid, 'File %d: %s\n', i, result.filename);
            fprintf(fid, '----------------------------------------\n');

            if result.success
                fprintf(fid, 'Overall Quality: %s\n', m.overallQuality);
                fprintf(fid, 'Retained Variance: %.1f%%\n', m.retainedVariance);
                fprintf(fid, 'GEDAI Artifacts: %d\n', m.gedaiArtifacts);
                fprintf(fid, 'Data Rank: %d / %d\n', m.dataRank, m.nbchan);
                fprintf(fid, 'SNR: %.1f dB\n', m.snr);
                fprintf(fid, 'Events: %d\n', m.nEvents);
                fprintf(fid, 'Channels: %d, Samples: %d, Duration: %.1f sec\n', ...
                        m.nbchan, m.pnts, m.duration);

                if m.filterApplied
                    fprintf(fid, 'Filter: %.1f - %.0f Hz\n', m.highpass, m.lowpass);
                end
                if m.gedaiApplied
                    fprintf(fid, 'GEDAI: threshold=%g, epochs=%g cycles\n', ...
                            m.gedaiThreshold, m.gedaiEpochCycles);
                end
            else
                fprintf(fid, 'ERROR: %s\n', m.error);
            end
            fprintf(fid, '\n');
        end

        % Summary
        fprintf(fid, '========================================\n');
        fprintf(fid, 'SUMMARY\n');
        fprintf(fid, '========================================\n');

        qualities = cellfun(@(x) x.metrics.overallQuality, appData.cleanBatchResults, 'UniformOutput', false);
        fprintf(fid, 'Excellent: %d\n', sum(strcmp(qualities, 'EXCELLENT')));
        fprintf(fid, 'Good: %d\n', sum(strcmp(qualities, 'GOOD')));
        fprintf(fid, 'Moderate: %d\n', sum(strcmp(qualities, 'MODERATE')));
        fprintf(fid, 'Poor: %d\n', sum(strcmp(qualities, 'POOR')));
        fprintf(fid, 'Errors: %d\n', sum(strcmp(qualities, 'ERROR')));

        fclose(fid);

        cleanLog(fig, sprintf('Report exported to: %s', filename));
    catch ME
        cleanLog(fig, sprintf('ERROR exporting report: %s', ME.message));
    end
end

%% ========================================================================
%  UTILITY FUNCTIONS
%  ========================================================================

function cleanLog(fig, msg)
    logBox = findobj(fig, 'Tag', 'cleanLog');
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

function cleanSetStatus(fig, status)
    statusText = findobj(fig, 'Tag', 'cleanStatusText');
    set(statusText, 'String', status);
    drawnow;
end

%% ========================================================================
%  COMMON CALLBACKS
%  ========================================================================

function closeCallback(hObject, ~)
    appData = guidata(hObject);
    if isfield(appData, 'cleanIsProcessing') && appData.cleanIsProcessing
        choice = questdlg('Processing in progress. Are you sure you want to close?', ...
                          'Close Confirmation', 'Yes', 'No', 'No');
        if strcmp(choice, 'No')
            return;
        end
    end
    delete(hObject);
end
