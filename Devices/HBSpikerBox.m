% HBSpikerBox
% 
% The HBSPikerBox object controls communication with and acquisition from the B
% ack Yard Brains Heart Brain SpikerBox.  This object will establish 
% communication with the Spikerbox over the serial port, acquire data, 
% store it in a circular buffer (at least is will eventually
% see BYB_CircularBuffer) and return data frames to a user defined 
% handler for further processing.
% 
% The HBSpikerBox extension is implemented in the SpikerBCI and it is not 
% expected you will use it unless you are creating your own BCI interface.
%  
%  USAGE:
%  
%   mySpikerBox = HBSPikerBox(port, inputbufferduration, handler) 
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

classdef HBSpikerBox < handle
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
        ADC2MV = (5/1024)/1.27281e-3; %convert to mV based on the adc and gain 
    end

    methods
        function obj = HBSpikerBox(port, varargin)
            if nargin > 3
                obj.DownSample = varargin{3};
            end
            if nargin < 3

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
            obj.SerialPort.flush
            obj.Collecting = true;
            configureCallback(obj.SerialPort,"byte",obj.InputBufferSamples * 3, @obj.readSerialCallback);
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
            obj.SerialPort =  serialport(obj.PortName,230400);
            obj.LastInputBufferTime = clock; %initialize the time of the first input block


            %configure the serialport to fire a callback when the expected
            %number of bytes are placed in the buffer. This is three times
            %the number of samples becaue each EEG sample is two bytes and
            %the digital line is a third byte
            %turn the callback off
            configureCallback(obj.SerialPort,"off");

                   
         end
         %read data from the serial port when the buffer is full
         function readSerialCallback(obj,src, evt)
         
             timeStamp = clock;
                
             inputBytes = read(src, obj.InputBufferSamples * 3, "uint8");
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

             %the brain heart spiker box ads a text string at the beginning of the first
             %data package so we have to remove it dfirst
             ind = strfind(data, 'StartUp!');
             if ~isempty(ind)
                 data = data(ind+10:end);%eliminate 'StartUp!' string with new line characters (8+2)
             end
             %unpacking data from frames
             EEG = [];
             Event = [];
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

                     %extract the 2 bit event marker from the bit 6 & 7
                     %using a bitmask and longical AND then shift it to the
                     %LSB
                     %inout = bitshift(bitand(uint8(data(i)), 96), -5);
                     i = i+1;
                     %the second byte uses 7 bits and the last will be
                     %zero so a straight addition here is good
                     intout = intout + uint16(uint8(data(i)));
                     EEG = [EEG intout];
                     i = i + 1;

                     intout = uint8(data(i)); %could use a mask here for only hte 3 lsb if we get noise on the channel
                     Event = [Event,intout];
                 end
                 i = i+1;
             end

             %return the new data chunk
             EEG = double(EEG) .* obj.ADC2MV;
             if obj.DownSample > 1
                 EEG = decimate(EEG, 4);
                 Event = Event(1:obj.DownSample: length(Event));
             end

         end
    end
end