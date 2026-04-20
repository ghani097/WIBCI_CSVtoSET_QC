function [ eventStruct ] = eegLabEventStructW(softEventAVector, softEventBVector, hardEventAVector, hardEventBVector, ...
                                               softEventACodes, softEventBCodes, hardEventACodes, hardEventBCodes)
%eegLabEventStructW  Takes event onset sample vectors (and optional code
%   values) and returns an EEGLAB-compatible event structure.
%
%   Each event gets:
%     .type     - string label  ('ST A', 'ST B', 'HT A', 'HT B')
%     .latency  - sample index of onset
%     .duration - 1 sample
%     .urevent  - sequential index
%     .code     - numeric trigger value at onset (NaN if not provided)

% Backward-compatible defaults for code arguments
if nargin < 5 || isempty(softEventACodes), softEventACodes = nan(size(softEventAVector)); end
if nargin < 6 || isempty(softEventBCodes), softEventBCodes = nan(size(softEventBVector)); end
if nargin < 7 || isempty(hardEventACodes), hardEventACodes = nan(size(hardEventAVector)); end
if nargin < 8 || isempty(hardEventBCodes), hardEventBCodes = nan(size(hardEventBVector)); end

eventStruct = struct([]);
offset = 0;
eventStruct = insertEvents(softEventAVector, 'ST A', softEventACodes, eventStruct, offset);
offset = offset + length(softEventAVector);
eventStruct = insertEvents(softEventBVector, 'ST B', softEventBCodes, eventStruct, offset);
offset = offset + length(softEventBVector);
eventStruct = insertEvents(hardEventAVector, 'HT A', hardEventACodes, eventStruct, offset);
offset = offset + length(hardEventAVector);
eventStruct = insertEvents(hardEventBVector, 'HT B', hardEventBCodes, eventStruct, offset);

    function eventStruct = insertEvents(eventVector, eventType, codesVector, eventStruct, numEventsOffset)
        numEvents = length(eventVector);
        for eventNum = 1:numEvents
            idx = eventNum + numEventsOffset;
            eventStruct(idx).type     = eventType;
            eventStruct(idx).latency  = eventVector(eventNum);
            eventStruct(idx).duration = 1;
            eventStruct(idx).urevent  = idx;
            if ~isempty(codesVector)
                eventStruct(idx).code = codesVector(eventNum);
            else
                eventStruct(idx).code = NaN;
            end
        end
    end

end
