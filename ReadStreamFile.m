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
   
    dStruct.EEG = [];
    dStruct.event = [];
    
    packetCount = 0;

    if dStruct.mode == CollectionMode.Continuous
        while ~feof(fh)
            packetCount = packetCount + 1;
            dStruct.EEG = [dStruct.EEG;fread(fh, dStruct.packet_length, 'single')];
            dStruct.event = [dStruct.event;fread(fh, dStruct.packet_length, 'uint8')];
        end
    else
        while ~feof(fh)
            packetCount = packetCount + 1;
            eeg = fread(fh, dStruct.packet_length, 'single');
            if isempty(eeg)
                packetCount = packetCount -1;
                break
            end
            dStruct.EEG(packetCount,:) = eeg;
            dStruct.event(packetCount,:) = fread(fh, dStruct.packet_length, 'uint8');
            dStruct.trialMarker(packetCount) = dStruct.event(packetCount,dStruct.pre_sample_pnts);
        end
        
    end

    fclose(fh);
    dStruct.packetCount = packetCount;
        

end

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

function [name, value] = parseHeaderLine(line)
  
  delimiter = ":";
  
  n = strfind(line, delimiter);
  if isempty(n) || length(n) > 1
    error("An invalid header line was encountered");
  end
  name = line(1:n-1);
  value = line(n+1:end);
end