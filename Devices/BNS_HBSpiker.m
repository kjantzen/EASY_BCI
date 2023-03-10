classdef BNS_HBSpiker < handle
% BNS_HBSPIKER Create a client for communicating withe the Backyardbrains
% Heart and Brain Spikerbox running BNS firmware version 0.1 or higher
% 
%   OBJ = BNS_HBSPiker(PORT) connects a bns_hbspiker object that
%   communicates with a spikerbox over serialport PORT.
%
%   OBJ = BNS_HBSPiker(PORT, CONTBUFFERDURATION) connects a bns_hbspiker object that
%   communicates with a spikerbox over serialport PORT and sets the sise of the 
%   input buffer for when in continuous mode to CONTBUFFERDURATION.  When
%   in continuous mode, the ContinuousPacketReceivedCallback will be called
%   when CONTBUFFERDURATION amount of data is read from the BNS_HBSpiker.
%  
%   
%   Handles both continuous and single trial mode
%
%  
%  Input parameters
%       port -  a string or character vector specifying the communications 
%               port to which the SpikerBox is connected. E.g. "COM3"
%       inputbufferduration - a scalar specifying the length in seconds 
%               of the buffer that holds data from the SpikerBox. 
%       
%   Properties
%       ADC2MV -  convert to mV based on the adc and gain 
%       Collecting – an internal flag indicating the current state of 
%               collection.  The Start and Stop methods operate on this flag.
%       InputBufferDuration – The duration of the input the input buffer in 
%               seconds.  Set by inputbufferduration parameter during creation.
%       InputBufferFilledCallback – The handler function to call when the 
%               buffer is full.  Passed by function reference as handler during creation.
%       InputBufferSamples – The length of the input buffer in samples. 
%               Equals  SampleRate * InputBufferDuration.
%       PortName - The port for communicating with the spiker box passed 
%               during creation.
%       SampleRate – The sample rate of data acquisition.  Set internally 
%               to 1000 Hz.
% 
%   Methods
%       Start – the Start methods starts collection 
%       Stop  - the stop method stops collection
%       Delete - deletes the object
%  
%  Examples
%  
%   Communicate with a Heart Brain Spiker Box connected to 
%   COM3 and send data in 200 ms chunks to the simpleChart handler
%  
%   mySpikerBox = HBSpikerBox('COM3', .2)
%   mySpikerBox.Start

    properties (Access = public)
        
        % ProcessObjects - variables, handles or objects the user wants to 
        % pass to the InputBufferFilledCallback function when a valid data 
        % sample is received.
        % Accepted Values - ANY
        ProcessObjects      %a structure containing the objects used in analysing the data

        % PacketReceivedCallback - callback invoked when a valid continuous
        % data packet is recieved
        PacketReceivedCallback = []

        % TrialReceivedCallback - callback invoked when a valid trial data
        % packet is received
        TrialReceivedCallback = []
       
    end
    properties (SetAccess = private)
        % ContinuousBufferDuration - the length (s) of the input buffer
        % when operating in continuous mode.
        ContinuousBufferDuration = .1

        % InputBufferSamples - number of samples in the serial input buffer
        % for each read packet.  
        % Read only - calculated internally from ContinuousBufferDuration
        InputBufferSamples  

        % Collecting - logical flag that indicates if the device is
        % currently collecting data
        % Read only - toggles with calls to obj.Start and obj.Stop
        Collecting          

        % CollectinMode - indicates if the device is currently in
        % Continuous or Single Trial mode.  Set this variable using the
        % obj.SetMode method
        CollectionMode

        % InputBufferFilledCallback - handle to a callback function to
        % which recieved data packets are passed
        % Holds the currently active callback.  Callbacks are switched when
        % the collection mode of the device changes
        InputBufferFilledCallback = [] 

        % PortName - The name of the port over which the device is connected
        % This is read only once the device is created and is passed to the
        % function during construction.
        PortName

        % PreStimSamples - The number of samples in the pre stimulus period
        % of a single trial.  Set using the obj.SetTrialLimits method.
        % Default 50 (100 ms)
        PreStimSamples = 50;

        % PstStimSamples - The number of samples in teh post stimulus period
        % of a single trial.  Set using the obj.SetTrialLimits method.
        % Default 300 (600 ms)
        PstStimSamples = 300;

        % Streaming - a logical value indicating if the BNS_HBSPiker box is
        % curerntly streaming data (Streaming = true)
        % Set when calling the obj.StartStreaming and obj.StopStreaming
        % methods
        Streaming

        % SerialPort - a Matlab serialport object that handles communication
        % between the BNS_HBSPiker object and the serial port
        SerialPort        
    end
    
    properties (Constant = true)

        %Self explanatory
        Version = "BNS_HBSpiker_V0.1";

        % ADC2UV - the converstion from raw adc units to microvolts basedon
        % the reference votage of 5 volts, the sample range of 1024 (10 bit)
        % and a gain of 3840
        ADC2UV =  (5/1024)/3840 * 1000000; %refVoltage/maxsample/gain * 1 million
        
        %BaudRate - is the baud rate determined by the BNS_HBSpiker
        %firmware
        BaudRate = 115200;

        % SampleRate - the sampling frequeny determined by the BNS_HBSpiker
        % firmware
        SampleRate = 500;
    end

    methods (Access = public)
        function obj = BNS_HBSpiker(varargin)
         %BNS_HBSpiker Constructs a BNS_HBSpiker object.
         % 
         %  OBJ = BNS_HBSPIKER(PORT) - constructs a BNS_HBSPIKER object to 
         %  communicate with the spikerbox hardware connected to the serial
         %  port specifed in the PORT argument.
         %
         %  OBJ = BNS_HBSpiker(PORT, CONTINUOUSBUFFERSDURATION) constructs 
         %  a BNS_HBSPIKER connected to serialport PORT with an input
         %  buffer duration of CONTINUOUSBUFFERDURATION
         %
         % Input Arguments
         %  PORT specifies the serialport to connect to
         %  CONTINUOUSBUFFERDURATION specifies the length (seconds) of each
         %      data packet read when in continuous mode
         %

            if nargin == 0
                error("BNS_HBSpiker:missingInputParameters",...
                    'A valid serialport name is required to intialize the BNS_HBSpiker');
           end
           
           try
            validateattributes(varargin{1}, {'string', 'char'},{'scalartext', 'nonempty'}, mfilename,'serialport');
           catch ME
               throwAsCaller(ME);
           end
           port = varargin{1};

           %set the length of the continuous buffer if it is included in
           %the call to the constructor
           if nargin > 1
                dur = varargin{2};
                if ~isnumeric(dur) || ~isscalar(dur) || dur<=0
                    error('The continuous collection data buffer must be a positive scalar value.');
                end
                %make sure the duraction leads to an integer number of
                %samples
                d2 = round(dur * obj.SampleRate)/obj.SampleRate;
                if d2~=dur
                    fprintf(['Buffer duration results in non-integer sample points!\n...' ...
                        'Changing from %d to %d'], dur, d2);
                end
                obj.ContinuousBufferDuration = d2;
           end
      
            obj.CollectionMode = BNS_HBSpikerModes.Continuous;  %default to continous mode
            obj.InputBufferSamples = obj.ContinuousBufferDuration * obj.SampleRate;
            obj.Collecting = false;
            
            %open the serial port 
            obj.setPort(port);      

        end
        
        function Start(obj)   
            %START - starts collecting from the BNS_HBSpiker
            %
            %   obj.Start - Starts collection from an existing BNS_HBSpiker
            %   device
            %

            if obj.Collecting
                error("THe device is already running.  Please stop the device before restarting");
            end

            %setup the Spikerbox and the serial port for communication
            %based on the current mode of collection
            %
            if obj.CollectionMode == BNS_HBSpikerModes.Continuous
                mcheck = 0;
                msg = 'm:0';
            else
                mcheck = 1;
                msg = sprintf('m:1;p:%i;t:%i', obj.PreStimSamples, obj.PstStimSamples);
            end

            %switch to the appropriate callback when packets are received
            obj.switchCallbacks;
         
            %needs time between configuring the port and writing
            pause(1);

            %send the configuration command to the device
            write(obj.SerialPort, msg, "char");
            %check for a hand shack from the device
            tic
            haveHandShake = false;
            mcheck = sprintf('mode set: %i', mcheck);

            while (~haveHandShake  && toc < 1)
                if obj.SerialPort.NumBytesAvailable >= 12
                    jnk = read(obj.SerialPort, obj.SerialPort.NumBytesAvailable, 'uint8');
                    if contains(char(jnk), mcheck)
                        haveHandShake = true;
                    end
                end
            end
            
            if ~haveHandShake 
                obj.Stop
                error('The device did not complete the mode set handshake');
            end

            %clear the port of any backedup data
            flush(obj.SerialPort)
            
            if obj.CollectionMode == BNS_HBSpikerModes.Continuous
                configureTerminator(obj.SerialPort,"LF");
                configureCallback(obj.SerialPort,"byte",obj.InputBufferSamples * 2, @obj.readSerialCallback);
            else
                configureCallback(obj.SerialPort,"terminator",@obj.readSerialCallback);
                configureTerminator(obj.SerialPort,"CR/LF");
            end

            %set the collecting flag
            obj.Collecting = true;

            
        end

        function Stop(obj)
        %STOP - stop collecting but do not close or delete the device
        %   
        %   obj.Stop = stop or pause collection from the BNS_HBSpiker
        %   device
        %
            obj.Collecting = false;
            configureCallback(obj.SerialPort,"off");
        end    

        function Delete(obj)
         %DELETE - delete the object and all its contents
         %
         %  obj.Delete - deletes the BNS_HBSpiker device
         %
            delete(obj);
        end

        function SetTrialLimits(obj, prePnts, pstPnts)
        %SWTRTRIALLIMITS - sets the pre and post stim durations to use when
        %in single trial mode
        %   obj.SetTrialLimits(prePnts, pstPnts) - sets the number of pre 
        %   and post stimulus sample points for use when operating in single
        %   trial mode.
        %   
        %   the total trial duration must be greater than 10 (.02 s) and 
        %   cannot exceed the BNS_HBSpiker maximum of 600 (1.2 s).
        %
        % Input parameters
        %   
        %   preDur - the number of sample points to collect prior to the
        %   onset of an event marker.  This is typically considered to be 
        %   the baseline period. 
        %
        %   pstDur - the numher of sample points to collect following the
        %   onset of an event marker.  
        %
        %   An error will occur if the limits are set while the BNS_HBSpiker
        %   is already running.
        % 
        % Input parameters
        %   prePnts - number of pre stimulus sample points.  Minimum = 1
        %   pstPnts - number of post stimulus points.  Minimum = 1
        %

            if nargin == 1
                error("BNS_HBSpiker:missingInputParameters",...
                    'Pre and Post stimulus event sample points must be provided in call to SetTrialLimits');
            end
            
            try
                validateattributes(prePnts,{'numeric'}, {'scalar', 'integer','positive'},'SetTrialLimits', 'prePnts');
                validateattributes(pstPnts,{'numeric'}, {'scalar', 'integer','positive'},'SetTrialLimits', 'pstPnts');
            catch ME
                throwAsCaller(ME);
            end
                
            tp = prePnts + pstPnts;
            try 
                validateattributes(tp, {'numeric'},{'scalar', '>',9,'<',601});
            catch ME
                throwAsCaller(ME);
            end

           if obj.Collecting
                error("BNS_HBSpiker:changesWhileRunning",...
                    'Parameters cannot be changed while the device is running');
            end
            obj.PreStimSamples = prePnts;
            obj.PstStimSamples = pstPnts;

        end
        
        function SetMode(obj, mode)
        % SETMODE - sets the collection mode of the BNS_HBSpiker
        %   
        %   obj.SetMode(mode) - sets the BNS_HBSpiker into MODE wich can be
        %   one of either continouous collection mode or single trial
        %   collection mode.
        %
        % Modes
        %   CONTINUOUS - in continuous collection mode data from the
        %   BNS_HBSpkiker are streamed to the client continuously in
        %   packets, the size of which are defined in the
        %   InputBufferDuration property that is set when the device is
        %   created.
        %
        %   SINGLE TRIAL - in sinlgle trial mode data is stored in a buffer
        %   on the BNS_HBSPiker until an event marker (or trigger) signal
        %   is recieved by the hardware, at which time a single trial fo
        %   data is transmitted to the client.  Trial limits are set using
        %   the obj.SetTrialLimits method
        %   
        % Input arguments
        %   MODE - a string or char vector indicating the the mode to set.
        %           "Contiuous"  - indicates continuous mode
        %           "Trial"      - indicates single trial mode
        %
            if (mode ~= BNS_HBSpikerModes.Trial && mode ~= BNS_HBSpikerModes.Continuous)
                error("the mode passed to the SetMode method is not a valid mode\n" + ...
                    "Mode must one of either continuous mode (%i) or trial mode (%i)", BNS_HBSpikerModes.Continuous, BNS_HBSpikerModes.Trial);
            end
            if (mode==obj.CollectionMode)
                return
            end
            if (mode == BNS_HBSpikerModes.Trial)
                if obj.Streaming
                    obj = obj.StopStreaming;
                end
            end
            obj.CollectionMode = mode;
            obj.Stop;  
        end
    
    end
    methods (Hidden, Access = private)
         
        function setPort(obj, portname)
            % Internal private function to create the serialport object for
            % communicating with the spikerbox 
            
            % make sure the port exists and is available
            if ~any(contains(serialportlist("all"), portname))
                error("BNS_HBSpiker:portNotFound", 'The port "%s" was not found on this device!', portname);
            end
            if ~any(contains(serialportlist("available"), portname))
                error("BNS_HBSpiker:portNotAvailable", 'The port "%s" is not currenlty available and may already be in use!', portname);
            end
            
            delete(obj.SerialPort);
            obj.PortName = portname;
            obj.SerialPort =  serialport(obj.PortName,obj.BaudRate);

            %now wait to get handshake information 
            tic
            haveHandShake = false;
            while ~haveHandShake && toc <= 5
                if obj.SerialPort.NumBytesAvailable >= 16
                    msg = read(obj.SerialPort, 16, "char");
                    if contains(msg, "BNS_HBSpiker")
                        haveHandShake = true;
                    end
                end
            end
            if ~haveHandShake
                error("BNS_HBSpiker:deviceNotResponding", 'The BNS_HBSpiker is not responding.\nPlease make sure it is plugged in and powered on and that you have selected the correct port.')
            end
            
            %turn the callback off until the user explicity starts
            %the device
            configureCallback(obj.SerialPort,"off");                 
         end

         function switchCallbacks(obj)
          % SWITCHCALLBACKS - switches between the continuous and single
          % trial mode callbacks depending on teh current collection mode.
          %
            if obj.CollectionMode  == BNS_HBSpikerModes.Continuous
                obj.InputBufferFilledCallback = obj.PacketReceivedCallback;
            else
                obj.InputBufferFilledCallback = obj.TrialReceivedCallback;
            end
         end

         function readSerialCallback(obj,src, ~)
             % READSERIALCALLBACK - serial port callback function invoked
             % when the serial buffer is filled 
             %
             if obj.CollectionMode == BNS_HBSpikerModes.Continuous
                inputBytes = read(src, obj.InputBufferSamples * 2, "uint8");
             else
                inputBytes = read(src, src.NumBytesAvailable, "uint8");
             end
             Packet = obj.UnpackData(inputBytes);
             if isempty(Packet)
                 return
             end
             if obj.Streaming
                 fwrite(obj.FileHandle, Packet.EEG, "double");
                 fwrite(obj.FileHandle, Packet.Event, "double");
             end

             %send the data to the clients callback function for display,
             %analysis etc.
             %
             if isa(obj.InputBufferFilledCallback, 'function_handle')
                 obj.ProcessObjects = obj.InputBufferFilledCallback(obj, obj.ProcessObjects, Packet);
             end
         end

         function dataPacket = UnpackData(obj, data)      
         % convert data from the input stream to samples
             bytes = uint8(data);
             dataPacket = [];

             %ignore the packet if it contains the SPikerbox handshake
             %message because this likely indicates the device was
             %powercycled while connected to the driver
             if contains(char(bytes), "BNS_HBSpiker")
                 return
             end
            
             %convert based on the current collection mode
             if (obj.CollectionMode == BNS_HBSpikerModes.Continuous)
                %preallocate the EEG array to the maximum size necessary
                 EEG = zeros(1,length(bytes)/2);
                 Event = EEG;
                 i=1;
                 count = 0;
    
                 while (i<length(bytes))
                     %make sure the sample is the first byte of the 10 bit integer   
                     [intout, evt] = obj.ConvertBytes(bytes(i), bytes(i+1));
                     if ~isempty(intout)
                         count = count + 1;
                         EEG(count) = intout;
                         Event(count) = evt;
                         i = i + 2;
                         
                     else
                        i=i+1;
                     end


                 end
    
                 EEG = single(EEG(1:count)) .* obj.ADC2UV;
                 %combine into a single packet structure
                 dataPacket.samples = length(EEG);
                 dataPacket.sampleRate = 500;
                 dataPacket.EEG = EEG;
                 dataPacket.Event = Event;
             
             else
                         
                headerBytes = 18;
                if ~strcmp(char(bytes(1:11)), "trial onset")
                    fprintf('Not a valid trial\n')
                    fprintf(char(bytes(1:11)));
                    return;
                end
    
                dataPacket.evt = bytes(12);
                dataPacket.sampleRate = double(bitor(bitshift(uint16(bytes(13)), 8), uint16(bytes(14))));
                dataPacket.preSamp = double(bitor(bitshift(uint16(bytes(15)), 8), uint16(bytes(16)))/2);
                dataPacket.postSamp = double(bitor(bitshift(uint16(bytes(17)), 8), uint16(bytes(18)))/2);
                dataPacket.samples = dataPacket.preSamp + dataPacket.postSamp;
                dataPacket.preTime = dataPacket.preSamp/dataPacket.sampleRate;
                dataPacket.posTime = dataPacket.postSamp/dataPacket.sampleRate;
    
                dataPacket.timePnts = (0:(dataPacket.samples)-1)./ dataPacket.sampleRate - dataPacket.preTime;
                dataPacket.EEG = zeros(1,dataPacket.samples);
                sampleCount = 1;

                for jj = 1:2:dataPacket.samples * 2
                    [intout, evt] = obj.ConvertBytes(bytes(jj+headerBytes), bytes(jj+headerBytes+1));
                    dataPacket.EEG(sampleCount) = single(intout) * obj.ADC2UV; % convert to uV
                    dataPacket.Event(sampleCount) = evt;
                    sampleCount = sampleCount + 1;
                end
             end
             dataPacket.version = obj.Version;
         end

         function [intout, evt] = ConvertBytes(~, b1, b2)
         % covert from the input butes to a 16 bit integer
          if(b1>127)
                  
           %save only the lower 3 bits from the byte
           hb = bitand(b1, 7) ;
           evt = bitshift(bitand(b1, 96), -5);
           
           %combine with the lower byte     
            intout = bitor(bitshift(int16(hb), 7), int16(b2)) - 512;
          else
              intout = [];
              evt = [];
          end
         end

    end
    %setters
    methods
         function set.ContinuousBufferDuration(obj, value)
            try
                validateattributes(value,{'numeric'},{'scalar', 'nonnegative', ...
                    'positive', 'finite'}, mfilename, 'ContinuousBufferDuration');
                obj.ContinuousBufferDuration = value;
            catch ME
                throwascaller(ME);
            end
         end

        function set.PacketReceivedCallback(obj, callback)
            if isa(callback, 'function_handle')
                obj.PacketReceivedCallback = callback;
                obj.switchCallbacks();
            end
        end
        
        function set.TrialReceivedCallback(obj, callback)
            if isa(callback, 'function_handle')
                obj.TrialReceivedCallback = callback;
                obj.switchCallbacks;
            end

        end
    end
end