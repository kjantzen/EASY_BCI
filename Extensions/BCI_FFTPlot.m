%BYB_FFTPlot - plots the the FFT power of input data packets.
%
%USAGE
%
%   myFFT = BYB_FFT(SRate, BSec, Ax) - creates an instance of the BYB_FFT
%   plotting object for analysing data segments with sample rate SRate and
%   of duration BSec seconds.  Data will be plotted in the axis passed as
%   Ax.
%
%
classdef BCI_FFTPlot
    properties 
        FAxis           %the current time axis to display
        SampleRate
        BufferSeconds
        BufferPoints
        DataBuffer
        FFTData
        Nyquist
        Axis
        PlotPower = true;
    end
    properties (Hidden)
        PlotHandle      %the handle to the actual plot
        FFTPoints
    end
    methods
        function obj = BCI_FFTPlot(SampleRate, BufferSeconds, plotAxis)
            if nargin < 2
                obj.BufferSeconds = 3;
            else
                obj.BufferSeconds = BufferSeconds;
            end
            if nargin < 1 
                obj.SampleRate = 512;
            else 
                obj.SampleRate = SampleRate;
            end
            obj.Nyquist = obj.SampleRate /2;
            obj.BufferPoints = obj.BufferSeconds * obj.SampleRate;
            %for speed, make sure the data is a multiple of a power of 2
            obj.BufferPoints = pow2(nextpow2(obj.BufferPoints));
      
            obj.FFTPoints = obj.BufferPoints/2+1;
            obj.DataBuffer = zeros(1,obj.BufferPoints);
            
            obj.FAxis = obj.SampleRate * (0:(obj.BufferPoints/2))/obj.BufferPoints;
            obj = computeFFT(obj);

            obj.PlotHandle = plot(plotAxis, obj.FAxis, obj.FFTData);
            ob.PlotHandle.LineWidth = 1.5;
            obj.Axis = plotAxis;
            obj.Axis.YLabel.String = 'amplitude';
            obj.Axis.XLabel.String = 'frequency (Hz)';
                
        end
        function obj = computeFFT(obj)
            twoSided = abs(fft(obj.DataBuffer)/obj.BufferPoints);
            obj.FFTData  = twoSided(1:obj.BufferPoints/2+1);
            obj.FFTData(2:end-1) = 2 .* obj.FFTData(2:end-1);
            if obj.PlotPower
                obj.FFTData = obj.FFTData .^ 2;
            end
             
        end
        function obj = updateChart(obj, dataChunk, fRange)
            
            ln = length(dataChunk);
            obj.DataBuffer(1:obj.BufferPoints-ln) = obj.DataBuffer(ln + 1: obj.BufferPoints);
            obj.DataBuffer(obj.BufferPoints-ln+1:obj.BufferPoints) = dataChunk;
            obj = computeFFT(obj);
            obj.PlotHandle.YData = obj.FFTData;
            
            
      
            obj.Axis.XLim = fRange/obj.Nyquist * length(obj.FFTData);
            drawnow();
          
        end
    end
end
