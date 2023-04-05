classdef BCI_CCA < handle
    properties
        Frequencies %the frequencies for creating target timeseries Y
        NHarmonics %the number of harmonics to use in calculating Y
        XSampleDuration %the number of samples of XData
        XData   %the obseved data to use in the CCA
    end
    properties (SetAccess = private)
        YData
        XCor
        YCor
        Rho
        SampleRate
        RefreshRate
        NSamples
        FrequencyClass

    end
    methods
        % *****************************************************************
        function obj = BCI_CCA(options)
            arguments
                options.Frequencies (1,:) {mustBeNumeric, mustBePositive} = [8.57, 10, 12, 15];
                options.nHarmonics (1,1) {mustBeNumeric, mustBePositive, ...
                    mustBeInRange(options.nHarmonics, 1, 8)} = 4;
                options.SampleRate (1,1) {mustBeInteger, mustBePositive} = 500;
                options.SampleDuration (1,1) {mustBeNumeric, mustBePositive} = 1;
            end
            obj.Frequencies = options.Frequencies;
            obj.NHarmonics = options.nHarmonics;
            obj.SampleRate = options.SampleRate;
            obj.XSampleDuration = options.SampleDuration;
            obj.NSamples = obj.XSampleDuration * obj.SampleRate;

            obj.calculateBasisFunctions;
        end
        % *****************************************************************
        function set.XData(obj, XData)
            arguments
                obj
                XData (1,:) {mustBeNumeric}
            end
            obj.XData = XData;
            obj.computeCCA;
        end    
    end
    methods (Access = private)
        % *****************************************************************
        function computeCCA(obj)
            try
                for ii = 1:length(obj.Frequencies)
                    [Xw, Yw, R] = canoncorr(obj.XData', squeeze(obj.YData(ii,:,:))');
                    obj.XCor{ii} = Xw;
                    obj.YCor{ii} = Yw;
                    obj.Rho{ii} = R;
                end
                [~, obj.FrequencyClass] = max(cell2mat(obj.Rho)); 
            catch ME
                throwAsCaller(ME);
            end
        end
        % *****************************************************************
        function calculateBasisFunctions(obj) 
            nPoints = obj.XSampleDuration * obj.SampleRate;
            t = (1:nPoints)./obj.SampleRate;
            %preallocate an array
            obj.YData = zeros(length(obj.Frequencies), obj.NHarmonics*2, nPoints);

            for ii = 1:length(obj.Frequencies)
                basisCount = 1;
                for jj = 1:obj.NHarmonics
                    %need both sin and cos basis functions here
                    obj.YData(ii,basisCount,:) = sin(2*pi*obj.Frequencies(ii)*jj*t);
                    obj.YData(ii,basisCount+1,:) = cos(2*pi*obj.Frequencies(ii)*jj*t);
                    basisCount = basisCount + 2;
                end
            end
        end
    end
end