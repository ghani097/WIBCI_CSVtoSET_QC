function WiBCIData = loadWiBCIData_UG(filePath, fillMissingPackets)

fileAsTable = readtable(filePath, 'VariableNamingRule', 'preserve');

fileAsArray = table2array(fileAsTable);
fileAsArray(isnan(fileAsArray)) = 0.0;

fileAsArray(2:end, 1) = fileAsArray(2:end, 1) + 1;
fileAsArray(2:end, 2:3) = fileAsArray(2:end, 2:3) + 4000;

fileAsArray(2:end, 4:19) = fileAsArray(2:end, 4:19) .* 0.02235;

dataMatrix = cumsum(fileAsArray);

[dataMatrix, numMissing] = appendNans(dataMatrix);
warning('%.1f percent of data is missing', numMissing/size(dataMatrix, 1)*100);

if(fillMissingPackets)
    dataMatrix = fillmissing(dataMatrix, "pchip");
    warning('Missing data is filled using pchip method. For more details, see "help fillmissing" in MATLAB.');
end

WiBCIData.channelData = dataMatrix;

dataChannelNames = getChannelNames(fileAsTable, 4:19);

WiBCIData.channelNames = {'Packet Number (n)',...
    'App Timestamp (us)',...
    'Sensor Timestamp (us)',...
    dataChannelNames{1},...
    dataChannelNames{2},...
    dataChannelNames{3},...
    dataChannelNames{4},...
    dataChannelNames{5},...
    dataChannelNames{6},...
    dataChannelNames{7},...
    dataChannelNames{8},...
    dataChannelNames{9},...
    dataChannelNames{10},...
    dataChannelNames{11},...
    dataChannelNames{12},...
    dataChannelNames{13},...
    dataChannelNames{14},...
    dataChannelNames{15},...
    dataChannelNames{16},...
    'AccX (mg)',...
    'AccY (mg)',...
    'AccZ (mg)',...
    'Event A',...
    'Event B'};


    function names = getChannelNames(fileTable, channelNums)
        namesCell = cellfun(@(x)strsplit(x, '(uV)'), fileTable.Properties.VariableNames(channelNums), 'UniformOutput', false);
        names = cellfun(@(x)strtrim(x{1}), namesCell, 'UniformOutput', false);
    end

    function [newMatrix, numMissing] = appendNans(dataMatrix)
    % Find all packet gaps at once
    packetNumbers = dataMatrix(:, 1);
    expectedDiffs = ones(size(packetNumbers, 1) - 1, 1);
    actualDiffs = diff(packetNumbers);
    gapSizes = actualDiffs - expectedDiffs;
    gapIndices = find(gapSizes > 0);
    
    % If no gaps, return original matrix
    if isempty(gapIndices)
        newMatrix = dataMatrix;
        numMissing = 0;
        return
    end
    
    % Calculate total missing packets
    numMissing = sum(gapSizes(gapIndices));
    
    % Pre-allocate the new matrix
    newSize = size(dataMatrix, 1) + numMissing;
    numCols = size(dataMatrix, 2);
    newMatrix = NaN(newSize, numCols);
    
    % Fill in the data iteratively
    srcIdx = 1;  % Current position in source matrix
    dstIdx = 1;  % Current position in destination matrix
    
    for i = 1:length(gapIndices)
        gapIdx = gapIndices(i);
        
        % Copy data before this gap
        numRowsToCopy = gapIdx - srcIdx + 1;
        newMatrix(dstIdx:dstIdx + numRowsToCopy - 1, :) = dataMatrix(srcIdx:gapIdx, :);
        dstIdx = dstIdx + numRowsToCopy;
        srcIdx = gapIdx + 1;
        
        % Insert NaN rows for missing packets
        numMissingHere = gapSizes(gapIdx);
        lastPacketNum = dataMatrix(gapIdx, 1);
        missingPacketNums = (lastPacketNum + 1):(lastPacketNum + numMissingHere);
        
        % Fill packet numbers
        newMatrix(dstIdx:dstIdx + numMissingHere - 1, 1) = missingPacketNums';
        
        % Fill event columns with zeros (columns 23:24)
        newMatrix(dstIdx:dstIdx + numMissingHere - 1, 23:24) = 0;
        
        dstIdx = dstIdx + numMissingHere;
    end
    
    % Copy remaining data after the last gap
    if srcIdx <= size(dataMatrix, 1)
        numRowsToCopy = size(dataMatrix, 1) - srcIdx + 1;
        newMatrix(dstIdx:dstIdx + numRowsToCopy - 1, :) = dataMatrix(srcIdx:end, :);
    end
end
end

