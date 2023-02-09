% ERPmini Continous device 
% 
% The ERPmini object controls communication with and acquisition from the ERP mini
% whenin continuous mode.  This object will establish 
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

classdef ERPminiCont < handle
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
        function obj = ERPminiCont(port, varargin)
            if nargin > 3
                obj.DownSample = varargin{3};
            end
            if nargin < 2

                obj.InputBufferFilledCallback = [];
            else
                if isa(varargin{2}, 'function_handle')
                    obj.InputBufferFilledCallback = varargin{2};
                else
                    warning('The InputBufferFilledCallback must be a function reference.  You passed a %s', class(varargin{2}));
                end
            end
            if nargin > 1
                if isnumeric(varargin{1})
                    obj.InputBufferDuration = varargin{1};
                else
                    warning('The Input Buffer Duration parameter must be numeric.  You passed a %s.', class(varargin{1}));
                end
            end

            obj.InputBufferSamples = obj.InputBufferDuration * obj.SampleRate;
            obj.Collecting = false;
            obj = obj.setPort(port);
          
        end
        function obj = Start(obj)
            flush(obj.SerialPort)
            obj.Collecting = true;
            configureCallback(obj.SerialPort,"byte",obj.InputBufferSamples * 2, @obj.readSerialCallback);
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
            obj.LastInputBufferTime = clock; %initialize the time of the first input block

            %turn the callback off
            configureCallback(obj.SerialPort,"off");

                   
         end
         %read data from the serial port when the buffer is full
         function readSerialCallback(obj,src, evt)
         
             timeStamp = clock;
                
             inputBytes = read(src, obj.InputBufferSamples * 2, "uint8");
             [InputBuffer, Events] = obj.UnpackData(inputBytes);

             %send the data to the callback
             if isa(obj.InputBufferFilledCallback, 'function_handle')
                 obj.ProcessObjects = obj.InputBufferFilledCallback(obj.ProcessObjects, InputBuffer, Events, timeStamp);
             end

         end
         %covert data from the input stream to samples
         function [EEG, Event] = UnpackData(obj, data)
            
             %convert the data packet to unsigned integers
             data = uint8(data);

             %preallocate the EEG array to the maximum size necessary
             EEG = zeros(1,length(data)/2);
             Event = [];
             i=1;
             count = 0;

             %loop through all the data and convert the two 8 bit values into a single
             %16 bit value
             while (i<length(data)-1)
                % data(i)
                 if(data(i)>127)
              
                     %save only the lower 5 bits from the byte
                     hb = bitand(data(i), 31) ;
      
                     %combine with the lower byte
                     i = i + 1;
                     intout = bitor(bitshift(uint16(hb), 7), uint16(data(i)));
                     
                     %finally, subtract 2048
                     intout = int16(intout) - 2048;
                     count = count + 1;
                     EEG(count) = intout;%[EEG intout];
         
                 end
                 i = i+1;
             end

             %return the new data chunk
             EEG = double(EEG(1:count)) .* obj.ADC2MV;
    
         end
    end
end