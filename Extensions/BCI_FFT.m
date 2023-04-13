% BCI_FFT calculated the magnitude of the Fourier transform for 
classdef BCI_FFT < handle
    properties (SetAccess = private)
        SampleRate
        BufferSeconds
        BufferPoints
        DataBuffer
        FFTAmplitude
        FFTPoints
        Nyquist
        Bins
        fAxis
    end
    properties (Constant)
        FreqBinNames = {'delta', 'theta', 'alpha', ;'beta1', 'beta2', 'gamma'}
        FreqBinRange = [0, 3; 3, 8; 8, 12; 12,20; 20,30;30,50];
    end
    properties (Hidden)
        freqBinPnts
    end
    methods
        function obj = BCI_FFT(SampleRate, options)
            arguments
                SampleRate (1,1) {mustBeInteger, mustBePositive}
                options.BufferDuration (1,1) {mustBeNumeric, mustBePositive} = 1
            end
            obj.SampleRate = SampleRate;
            obj.BufferSeconds = options.BufferDuration;            
            obj.Nyquist = obj.SampleRate /2;
            
            obj.BufferPoints = obj.BufferSeconds * obj.SampleRate;
            obj.BufferPoints = pow2(nextpow2(obj.BufferPoints));
            
            obj.BufferSeconds = obj.BufferPoints/obj.SampleRate;
       
            
            obj.FFTPoints = obj.BufferPoints/2+1;
            obj.DataBuffer = zeros(1,obj.BufferPoints);
            obj.FFTAmplitude = zeros(1,obj.FFTPoints);

            obj.fAxis = obj.SampleRate * (0:(obj.BufferPoints/2))/obj.BufferPoints;

            %convert the bin range values to actual offsets into the fft
            %array
            obj.freqBinPnts = round(obj.FreqBinRange * obj.BufferPoints / obj.SampleRate);
                
        end
    % *********************************************************************
    function obj = FFT(obj, dataChunk)

            
            ln = length(dataChunk);
            if ln > obj.BufferPoints
                error('The length of a data chunk cannot exceed the FFT buffer size');
            end
            %shift the data down and add the new data chunk
            obj.DataBuffer(1:obj.BufferPoints-ln) = obj.DataBuffer(ln + 1: obj.BufferPoints);
            obj.DataBuffer(obj.BufferPoints-ln+1:obj.BufferPoints) = dataChunk;
            obj = computeFFT(obj);

            twoSided = abs(fft(obj.DataBuffer)/obj.BufferPoints);
            obj.FFTAmplitude  = twoSided(1:obj.BufferPoints/2+1);
            obj.FFTAmplitude(2:end-1) = 2 * obj.FFTAmplitude(2:end-1);

            for ii = 1:size(obj.freqBinPnts, 1)
                obj.Bins(ii) = mean(obj.FFTAmplitude(obj.freqBinPnts(ii,1)+1 : obj.freqBinPnts(ii,2)));
            end
        end
 
    end
end
