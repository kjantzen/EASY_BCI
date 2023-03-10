classdef BCI_Stream < handle
    properties (SetAccess = private)
        BytesWritten 
        FileName
        PacketsWritten
        IsStreaming
        DataType
        FileHandle
    end
    
    methods
        function obj = BCI_Stream(FileName, options)
         
            arguments
                FileName {mustBeTextScalar(FileName)}
                options.Overwrite logical = true
            end
        
            obj.DataType = [];
            obj.BytesWritten = 0;
            obj.PacketsWritten = 0;
            obj.IsStreaming = false;

            if (isfile(FileName) && (options.Overwrite == false))
                obj = [];
                error('The file alread exists and no overwrite was indicated.');
            end
            obj.FileName = FileName;
            obj.FileHandle = fopen(FileName,'w');
            if (obj.FileHandle == 0)
                obj = [];
                error("The file %i could not be opened", options.FileName);
            end
            obj.IsStreaming = true;

        end

        function Save(obj, Packet)
        %SAVE - saves a data packet to the data stream
            if isfield(Packet, 'evt') 
                packetType = CollectionMode.SingleTrial;
            else
                packetType = CollectionMode.Continuous;
            end
            if isempty(obj.DataType)
                obj.DataType = packetType;
                obj.writeFileHeader(Packet);
            elseif obj.DataType ~= packetType
                error("The mode of the current packet is inconsistent with the mode at initiation.")
            end

            %write the number of samples
            fwrite(obj.FileHandle, Packet.EEG, 'single');
            fwrite(obj.FileHandle, Packet.Event, 'uint8');
            obj.PacketsWritten = obj.PacketsWritten + 1;
            bytes = length(Packet.EEG) * 5;
            obj.BytesWritten = obj.BytesWritten + bytes;
            
        end

        function Close(obj)
            obj.delete;
        end

        function delete(obj)
            if obj.FileHandle > 0
                obj.FileHandle = fclose(obj.FileHandle);
            end   
        end

    end
    methods (Access = private, Hidden)
        function writeFileHeader(obj, packet) 
            if obj.DataType == CollectionMode.Continuous
                HeaderLength = 6;
            else
                HeaderLength = 8;
            end
            fprintf(obj.FileHandle, "header_length: %i\n", HeaderLength);
            fprintf(obj.FileHandle, "version: %s\n", packet.version);
            fprintf(obj.FileHandle, "mode: %s\n",obj.DataType);
            fprintf(obj.FileHandle, "sample_rate: %i\n", packet.sampleRate);
            fprintf(obj.FileHandle, "channels: 2\n");
            fprintf(obj.FileHandle, "packet_length: %i\n", packet.samples);
            
            if obj.DataType == CollectionMode.SingleTrial
                fprintf(obj.FileHandle,'pre_sample_pnts: %i\n', packet.preSamp);
                fprintf(obj.FileHandle,'pst_sample_pnts: %i\n', packet.postSamp);
            end      
            
        end
    end
end