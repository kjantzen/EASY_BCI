%DEVICE: ERPminTrial 
%
% A simple device driver for ineracting with the ERPmini in single trial
% mode
%
% The ERPminiTrial device driver controls communication with and acquisition 
% from the ERP mini% when in single trial mode.  This driver will establish
% communication with the ERPmini over the serial port, acquire data,
% return data frames to a user defined handler for further processing.
%
% The ERPminiTask device is implemented in the Easy_BCI package and it is not
% expected you will use it directly unless you are creating your own BCI interface.
%
%  USAGE:
%
%  ERPminiTrial = ERPminiTrial(port, handler)
%
%  Input parameters
%       port -  a string or character vector specifying the communications
%               port to which the SpikerBox is connected. E.g. "COM3"
%       handler - the callback function to invoke when a single trial
%               is recieved from the ERPmini.
%               The handler must accept at least two input parameters.  
%               inStruct - a Matlab structure that contains handles to the 
%                   processing extension, figures, axes, etc, defined by and 
%                   accessed by the handler.
%               Trial - a structure containin the single trail information.
%                   The Trial structure has the following fields
%                   evt         :(unit8) the trigger code for the trial
%                   sampleRate  :(uint16) the sample rate
%                   preSamp     :(uint16) The number of pre stimulus samples
%                   postBytes   :(uint16) The number of post stimulus
%                               samples
%                   samples     :(unit16)  The total number of samples in the trial
%                   preTime     :(uint16) the duration (seconds) of the pre stimulus
%                               period
%                   posTime     :(uint16) the duration (seconds) of the post timulus
%                               period
%                   timePnts    :(double) the  time of each sample in seconds.  
%                               All times are in the range
%                               [-preTime:1/sampleRate:postTime]
%                   EEG:        :(double) a vector containing the EEG samples
%   
%
%   Properties
%       ADC2MV -  convert to mV based on the adc and gain
%       Collecting – an internal flag indicating the current state of
%               collection.  The Start and Stop methods operate on this flag.
%       InputBufferFilledCallback – The handler function to call when a
%               trial is recieved.  Passed by function reference from the handler during creation.
%       PortName - The port for communicating with the spiker box passed
%               during creation.
%       SampleRate – The sample rate of data acquisition.  Set internally
%               to 512 Hz.
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

classdef HBSpiker_ERP < handle
    properties
        PortName   %the port for communicating with the spiker box
        InputBufferFilledCallback = [] %called when new data is recieved from the spiker box
        Collecting          %flag used to start and stop acquisition
        ProcessObjects      %a structure containing the objects used in analysing the data
    end
    properties (Access = private)
        SerialPort
        LastInputBufferTime = 0;
    end
    properties (Constant = true)
        SampleRate = 500;
        ADC2MV =  (5/1024)/3840 * 1000000; %1.2715 %convert to uV based on the adc and gain
    end

    methods
        function obj = HBSpiker_ERP(port, varargin)

            if isa(varargin{1}, 'function_handle')
                obj.InputBufferFilledCallback = varargin{1};
            else
                warning('The InputBufferFilledCallback must be a function reference.  You passed a %s', class(varargin{2}));
            end

            obj.Collecting = false;
            obj = obj.setPort(port);

        end
        function obj = Start(obj)

            flush(obj.SerialPort)
            %put the device in single trial mode
          
            obj.Collecting = true;
            configureCallback(obj.SerialPort,"terminator",@obj.readSerialCallback);
            configureTerminator(obj.SerialPort,"CR/LF");
            write(obj.SerialPort, 'm:1', "char");
     
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
            obj.SerialPort =  serialport(obj.PortName,115200);
      
            configureCallback(obj.SerialPort,"off");


        end
        %read data from the serial port when the buffer is full
        function readSerialCallback(obj,src, ~)

       
            inputBytes = read(src, src.NumBytesAvailable, "uint8");
            Trial = obj.UnpackData(inputBytes);

            %send the data to the callback
            if isa(obj.InputBufferFilledCallback, 'function_handle')
                obj.ProcessObjects = obj.InputBufferFilledCallback(obj.ProcessObjects, Trial);
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
            trial.sampleRate = double(bitor(bitshift(uint16(bytes(13)), 8), uint16(bytes(14))));
            trial.preSamp = double(bitor(bitshift(uint16(bytes(15)), 8), uint16(bytes(16)))/2);
            trial.postSamp = double(bitor(bitshift(uint16(bytes(17)), 8), uint16(bytes(18)))/2);
            trial.samples = trial.preSamp + trial.postSamp;
            trial.preTime = trial.preSamp/trial.sampleRate;
            trial.posTime = trial.postSamp/trial.sampleRate;

            trial.timePnts = (0:(trial.samples)-1)./ trial.sampleRate - trial.preTime;
            trial.EEG = zeros(1,trial.samples);
            sampleCount = 1;
            for jj = 1:2:trial.samples * 2
                %combine the two bytes into a 16 bit integer
                b1 = bitshift(int16(bytes(jj+headerBytes)), 7);
                b2 = bitand(int16(bytes(jj+headerBytes+1)), 128);
                temp = bitor(b1, b2);
                %temp = bitor(bitshift(int16(bytes(jj+headerBytes)), 8), int16(bytes(jj+headerBytes+1)));
                trial.EEG(sampleCount) = double(temp) * obj.ADC2MV; % convert to uV
                sampleCount = sampleCount + 1;
            end
      
        end
    end
end