%BYB_FFT calculated the magnitude of the Fourier transform for 
classdef BYB_FFT
    properties 
        SampleRate
        BufferSeconds
        BufferPoints
        DataBuffer
        FFTtData
        FFTPoints
        Nyquist
        Bins
    end
    properties (Constant)
        FreqBinNames = {'delta', 'theta', 'alpha', ;'beta1', 'beta2', 'gamma'}
        FreqBinRange = [0, 3; 3, 8; 8, 12; 12,20; 20; 20, 30];
    end
    properties (Hidden)
        freqBinPnts
    end
    methods
        function obj = BYB_FFT(SampleRate, BufferSeconds)
            if nargin < 2
                obj.BufferSeconds = 1;
            else
                obj.BufferSeconds = BufferSeconds;
            end
            if nargin < 1 
                obj.SampleRate = 1000;
            else 
                obj.SampleRate = SampleRate;
            end
            obj.Nyquist = obj.SampleRate /2;
            obj.BufferPoints = obj.BufferSeconds * obj.SampleRate;
            obj.BufferPoints = pow2(nextpow2(obj.BufferPoints));

            obj.FFTPoints = obj.BufferPoints/2+1;
            obj.DataBuffer = zeros(1,obj.BufferPoints);
            
            obj.fAxis = obj.SampleRate * (0:(obj.BufferPoints/2))/obj.BufferPoints;
            obj.FFTtData = zeros();

            %convert the bin range values to actual offsets into the fft
            %array
            obj.freqBinPnts = obj.FreqBinRange * obj.BufferPoints / obj.SampleRate;
                
        end
    
        function obj = FFT(obj, data)

            ln = length(dataChunk);
            obj.DataBuffer(1:obj.BufferPoints-ln) = obj.DataBuffer(ln + 1: obj.BufferPoints);
            obj.DataBuffer(obj.BufferPoints-ln+1:obj.BufferPoints) = dataChunk;
            obj = computeFFT(obj);

            twoSided = abs(fft(obj.DataBuffer)/obj.BufferPoints);
            obj.FFTtData  = twoSided(1:obj.BufferPoints/2+1);
            obj.FFTtData(2:end-1) = 2 * obj.FFTtData(2:end-1);

            for ii = 1:size(obj.freqBinPnts, 1)
                obj.Bins(ii) = mean(obj.FFTtData(obj.freqBinPnts(ii,1)+1 : obj.freqBinPnts(ii,2)));
            end
        end
 
    end
end
