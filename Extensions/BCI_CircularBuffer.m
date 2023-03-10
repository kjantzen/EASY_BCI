classdef BCI_CircularBuffer
    properties
        EEGBuffer   %the main circular buffer
        BufferLength     %the length of the buffer in samples
        EEGChunk    %the incoming data chunk
        ChunkLength     %number of samples in the chunk
        NextWriteIndex  %to keep track of where to write in the buffer
        NextReadIndex   %not currently used
        MaxChunks   %the number of chunks to collect before wrapping the buffer
        Event.Value = 0;    %keep track of the digital trigger
        Event.Index = 0;
        ReturnBuffer            %the data to send back from the buffer
        ReturnBufferLength     %this is the length of the buffer to return 
        %                        which can be equal to or greater than
        %                       the ChunkLength.  If larger than the
        %                       chunklength, data from previous chunks will
        %                       be added.
    end
    methods
        function obj = BCI_CircularBuffer(ChunkLength, varargin)
        %constructor method for creating an instance of the circular buffer class
        %
        %buffer = CircularBuffer(ChunkLength) will create a circular buffer
        %that will accept indivudal data packets containing ChunkLength samples 
        % and will have total length of 10 * ChunkLength samples.
        %
        %Note that ChunkLength refers to the number of samples in the buffer
        %and not the number of bytes.  Each sample will consist of 2 bytes
        %(2 for the 10 bit ADC value representing the EEG recording and 1 
        %for the 8 bit digital event marker).  So this ChunkLength should
        %be 1/3 the size of the buffer you use to read from the serial port
        %
        %buffer = CircularBuffer(ChunkLength, BufferLength) -  Creates a
        %buffer with BufferLength Points.  BufferLength should be several 
        %times longer than ChunkLength and should be long enough to contain
        %your ERP trial wihout overwriting.  For safety I suggest it should
        %be twice the length of your ERP.  If BufferLength is not a
        %multiple of ChunkLength it will be rounded up to the next multiple
        %
        %
            obj.ChunkLength = ChunkLength;
            if nargin < 3
                obj.ReturnBufferLength = ChunkLength;
            elseif
                obj.ReturnBufferLength = varargin{3}
                if obj.ReturnBufferLength < ChunkLength
                    warning('Return buffer length cannot be smaller than the chunk size! Reset to ChunkLength');
                    obj.ReturnBufferLength = ChunkLength;
                end
            end
            if nargin < 2
                %default to a buffer length that is 10 times the length of
                %the individual data chunks
                obj.MaxChunks = 10;
            else
                %if a bufferlength is passed, make sure it is a multiple of
                %the chunklength
                obj.MaxChunks = ciel(varargin{1} / ChunkLength);
            end
            
            obj.BufferLength = ChunkLength * obj.MaxChunks;
            %initialize the buffer and write index
            obj.EEGBuffer = zeros(1,obj.BufferLength);
            obj.ReturnBuffer = zeros(1,obj.ReturnBufferLength);
            obj.NextWriteIndex = 1;
            obj.NextReadIndex = 1;

            if obj.ReturnBufferLength > obj.BufferLength
                warning('Return buffer length cannot be larger than the circular buffer size! Reset to max');
                obj.ReturnBufferLength = obj.BufferLength;
            end
       
        end
        function obj = AddChunkToBuffer(obj,rawdata)
        %function for adding a new chunk of data to the circular buffer
            
            %use the internal function to convert the data to 16 bit
            [obj.EEGChunk, Event] = obj.unpack(rawdata);

            %get the first event
            %and assign it to the event item
            [v, i] = find(Event, 1);
            if ~isempty(v)
                obj.Event.Value = v;
                obj.Event.Index = i;
            else 
                obj.Event.Value = 0;
                obj.Event.Value = 0;
            end

            %sometimes there are bytes missing
            actualChunkLength = length(obj.Chunk);
            %add the chunk of data to the circular buffer
            obj.EEGBuffer(obj.NextWriteIndex:obj.NextWriteIndex + actualChunkLength-1) = obj.EEGChunk;
            obj.EventBuffer(obj.NextWriteIndex:obj.NextWriteIndex + actualChunkLength-1) = obj.EventChunk;
            %update the write index and wrap it around to 1 if it exceeds
            %the length of the buffer
            obj.NextWriteIndex = obj.NextWriteIndex + obj.ChunkLength;
            if obj.NextWriteIndex > obj.BufferLength
                obj.NextWriteIndex = 1;
            end

            %put the desired amount of data on the returnbuffer
            indx = obj.NextWriteIndex - obj.ReturnBufferLength - 1;
            if indx > 0 %data are contiguous in the buffer
                obj.ReturnBuffer = obj.EEGBuffer(indx:indx + obj.ReturnBufferLength);
            else
                obj.ReturnBuffer(1:-indx) = obj.EEGBuffer(end+indx+1:end);
                obj.ReturnBuffer(-indx+1:obj.ReturnBufferLength) = obj.EEGBuffer(1:obj.ReturnBufferLength +indx);
            end  
        end
      
    end
   
    methods (Access = private)
         
        function [EEG, event] = unpack(obj,data)
            %convert the data packet to unsigned integers
            data = uint8(data);

            %the brain heart spiker box ads a text string at the beginning of the first
            %data package so we have to remove it dfirst
            ind = strfind(data, 'StartUp!');
            if ~isempty(ind)
                data = data(ind+10:end);%eliminate 'StartUp!' string with new line characters (8+2)
            end
            %unpacking data from frames
            EEG = [];
            event = [];
            i=1;
 
            %loop through all the data and convert the two 8 bit values into a single
            %16 bit value
            while (i<length(data)-1)
                    if(uint8(data(i))>127)
                        %extract one sample from 2 bytes
                        %the first byte uses only the first 3 bits all
                        %onther bits should be zero except the MSB so we
                        %can mask with a bitand operaiton with 127 and then
                        %shift it up to MSB side by multiplying by 128
                        intout = uint16(uint16(bitand(uint8(data(i)),127)).*128);
                        i = i+1;
                        %the second byte uses 7 bits and the last will be
                        %zero so a straight addition here is good
                        intout = intout + uint16(uint8(data(i)));
                        EEG = [EEG intout];
                        i = i + 1;

                        intout = uint8(data(i)); %could use a mask here for only hte 3 lsb if we get noise on the channel
                        obj. = [event,intout];
                    end
                    i = i+1;
             end
          
            %return the new data chunk
            EEG = double(EEG);
        end
    
    end
    
end
