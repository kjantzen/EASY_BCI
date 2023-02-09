% ERPminTrial single trial device
%
% The ERPmini object controls communication with and acquisition from the ERP mini
% when in single trial mode.  This object will establish
% communication with the ERPmini over the serial port, acquire data,
% return data frames to a user defined
% handler for further processing.
%
% The ERPmini extension is implemented in the SpikerBCI and it is not
% expected you will use it unless you are creating your own BCI interface.
%
%  USAGE:
%
%   ERPmini = ERPmini(port, inputbufferduration, handler)
%
%  Input parameters
%       port -  a string or character vector specifying the communications
%               port to which the SpikerBox is connected. E.g. "COM3"
%       inputbufferduration - a scalar specifying the length in seconds
%               of the buffer that holds data from the SpikerBox.
%       handler - the function to call when the input buffer is filled.
%               The frequency of this call will be inversely proportional
%               to the input buffer length.  The callback must accept at
%               least three input parameters.  The first parameter is a MATLAB
%               struct, the second is the data vector and the third is the
%               event code vector (see creating your own handler for more
%               information)
%
%   Properties
%       ADC2MV -  convert to mV based on the adc and gain
%       Collecting – an internal flag indicating the current state of
%               collection.  The Start and Stop methods operate on this flag.
%       DownSample – Not impimented yet
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
%
%  Examples
%
%   Communicate with a Heart Brain Spiker Box connected to
%   COM3 and send data in 200 ms chunks to the simpleChart handler
%
%   mySpikerBox = HBSpikerBox('COM3', .2, @simpleChart)
%   mySpikerBox.Start

classdef ERPminiTrial < handle
    properties
        PortName   %the port for communicating with the spiker box
        InputBufferFilledCallback = [] %called when new data is recieved from the spiker box
        InputBufferDuration = .25 %length of the input buffer in seconds
        InputBufferSamples  %number of samples in the input buffer
        Collecting          %flag used to start and stop acquisition
        ProcessObjects      %a structure containing the objects used in analysing the data
        DownSample = 1;
    end
    properties (Access = private)
        SerialPort
        LastInputBufferTime = 0;
    end
    properties (Constant = true)
        SampleRate = 512;
        ADC2MV =  0.2197; %convert to mV based on the adc and gain
    end

    methods
        function obj = ERPminiTrial(port, varargin)

            if isa(varargin{1}, 'function_handle')
                obj.InputBufferFilledCallback = varargin{1};
            else
                warning('The InputBufferFilledCallback must be a function reference.  You passed a %s', class(varargin{2}));
            end

            obj.InputBufferSamples = obj.InputBufferDuration * obj.SampleRate;
            obj.Collecting = false;
            obj = obj.setPort(port);

        end
        function obj = Start(obj)
            flush(obj.SerialPort)
            obj.Collecting = true;
            configureCallback(obj.SerialPort,"terminator",@obj.readSerialCallback);
            configureTerminator(obj.SerialPort,"CR/LF");
        end
        function obj = Stop(obj)
            obj.Collecting = false;
            configureCallback(obj.SerialPort,"off");
        end
        function delete(obj)
            delete(obj.SerialPort);  %make sure the serial port object is deleted

        end

    end
    methods (Access = private)
        %create the serial port object
        function obj = setPort(obj, portname)

            if ~any(contains(serialportlist, portname))
                error('The port %s was not found on this device.', portname);
            end

            delete(obj.SerialPort); %delete the old handle
            obj.PortName = portname;
            obj.SerialPort =  serialport(obj.PortName,57600);
      
            %put the device in single trial mode
            write(obj.SerialPort, 'cm1', "char");

            %configure the serialport to fire a callback when the expected
            %number of bytes are placed in the buffer. This is three times
            %the number of samples becaue each EEG sample is two bytes and
            %the digital line is a third byte
            %turn the callback off
            configureCallback(obj.SerialPort,"off");


        end
        %read data from the serial port when the buffer is full
        function readSerialCallback(obj,src, ~)

       
            inputBytes = read(src, src.NumBytesAvailable, "uint8");
            Trial = obj.UnpackData(inputBytes);
            Events = [];

            %send the data to the callback
            if isa(obj.InputBufferFilledCallback, 'function_handle')
                obj.ProcessObjects = obj.InputBufferFilledCallback(obj.ProcessObjects, Trial, Events);
            end

        end
        %covert data from the input stream to samples
        function trial = UnpackData(obj, data)

            %convert the data packet to unsigned integers
            bytes = uint8(data);
            
            trial = [];
            headerBytes = 18;
            if ~strcmp(char(bytes(1:11)), "trial onset")
                fprintf('Not a valid trial\n')
                return;
            end

            trial.evt = bytes(12);
            trial.sampleRate = bitor(bitshift(uint16(bytes(13)), 8), uint16(bytes(14)));
            trial.preBytes = bitor(bitshift(uint16(bytes(15)), 8), uint16(bytes(16)));
            trial.postBytes = bitor(bitshift(uint16(bytes(17)), 8), uint16(bytes(18)));
            trial.numBytes = trial.preBytes + trial.postBytes;
            trial.preTime = double(trial.preBytes/2)/trial.sampleRate;
            trial.posTime = double(trial.postBytes/2)/trial.sampleRate;

            trial.timePnts = double(0:(trial.numBytes/2)-1)./ double(trial.sampleRate) - double(trial.preTime);

            sampleCount = 1;
            for jj = 1:2:trial.numBytes
                %combine the two bytes into a 16 bit integer
                temp = bitor(bitshift(int16(bytes(jj+headerBytes)), 8), int16(bytes(jj+headerBytes+1)));
                %this is to convert from twos complement
                temp = bin2dec(['0b', dec2bin(temp), 's16']);
                trial.EEG(sampleCount) = double(temp) * obj.ADC2MV; % convert to uV
                sampleCount = sampleCount + 1;
            end
            %preallocate the EEG array to the maximum size necessary
      
        end
    end
end