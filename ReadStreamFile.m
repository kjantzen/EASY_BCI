function dStruct = ReadStreamFile(fileName)
% READSTREAMFILE - reads the contents of a BCI_STREAM data file
%   struct = ReadStreamFile(filename) - reads the contents of the
%   BCI_Stream file given by FILENAME and returns a structure that holds
%   file information and the EEG data
%
    arguments
        fileName {mustBeTextScalar(fileName), mustBeFile(fileName)}
    end
    
    fh = fopen(fileName, 'r');
    if (fh < 1)
        error("Could not open file: %s", fileName);
    end
    
    try
        dStruct = readHeader(fh);
    catch ME
        fclose(fh);
        throwAsCaller(ME);
    end
    
    dStruct.filename = fileName;
    dStruct.setname = "BNS Spiker Data";
    dStruct.nbchan = 1;

    
    dStruct.data = [];
    dStruct.eventchan = [];
    
    packetCount = 0;
    
    if dStruct.mode == CollectionMode.Continuous
        while ~feof(fh)
            packetCount = packetCount + 1;
            dStruct.data = [dStruct.data;fread(fh, dStruct.packet_length, 'single')];
            dStruct.eventchan = [dStruct.eventchan;fread(fh, dStruct.packet_length, 'uint8')];
     
        end
        dStruct.trials = 1;
        dStruct.pnts = length(dStruct.data);
        dStruct.xmin = 0;
        dStruct.srate = double(dStruct.sample_rate);
        dStruct.xmax = double(dStruct.pnts-1) / dStruct.srate;
        while ~feof(fh)
            packetCount = packetCount + 1;
            eeg = fread(fh, dStruct.packet_length, 'single');
            if isempty(eeg)
                packetCount = packetCount -1;
                break
            end
            dStruct.data(packetCount,:) = eeg;
            dStruct.eventchan(packetCount,:) = fread(fh, dStruct.packet_length, 'uint8');
            dStruct.trialMarker(packetCount) = dStruct.event(packetCount,dStruct.pre_sample_pnts);
        end
        dStruct.trial = packetCount;
        
        
    end
    
    fclose(fh);

    %make compatible with EEGlab
    dStruct.packetCount = packetCount;
    dStruct.event = findTriggerOnsets(dStruct.eventchan);
    dStruct.data = dStruct.data';
    dStruct.icawinv = [];
    dStruct.icaweights = [];
    dStruct.icasphere = [];
    dStruct.icaact = [];
    dStruct.chanlocs = [];
    dStruct = eeg_checkset(dStruct);
    
    


end
%**************************************************************************
function header = readHeader(fh)
% header = readHeader(h)
%   reads and parses the header from a BCS_Stream file
%
    header = [];
    
    ln = fgetl(fh);
    try
        [name, value] = parseHeaderLine(ln);
    catch ME
        throwAsCaller(ME)
    end
    
    if ~contains(name, "header_length")
        error("header length expected as the first line.  Found %\n", name);
    end
    nHLines = int8(str2double(value));
    if nHLines <6
        error("There are not enough header lines indicated\n");
    end
    for ii = 1: nHLines-1
        ln = fgetl(fh);
        try
            [name, value] = parseHeaderLine(ln);
        catch ME
            throwAsCaller(ME)
        end
        switch name
            case {'version' 'mode'}
                header.(name) = strtrim(value);
            otherwise
                header.(name) = uint16(str2double(value));
        end
    end
end
%**************************************************************************
function [name, value] = parseHeaderLine(line)
    delimiter = ":";
    
    n = strfind(line, delimiter);
    if isempty(n) || length(n) > 1
        error("An invalid header line was encountered");
    end
    name = line(1:n-1);
    value = line(n+1:end);
end
%**************************************************************************
function events = findTriggerOnsets(eventChunk)
    trigs = find(diff(eventChunk));
    events = [];
    evt_count = 0;
    if ~isempty(trigs)
        for ii = 1:length(trigs)            
            if eventChunk(trigs(ii)+1)~= 0
                evt_count = evt_count + 1;
                events(evt_count).type = eventChunk(trigs(ii)+1);
                events(evt_count).latency = trigs(ii);
                events(evt_count).urevent = evt_count;
            end
        end
    end
end