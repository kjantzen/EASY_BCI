classdef BCI_CCA < handle
    % BCI_CCA - object for conducting canonical correlation analysis (CCA)
    % on SSVEP data
    %
    % obj = BCI_CCA() creates the object with default settings.
    %
    % Optional Inputs Variable, value pairs
    %   Frequencies = fVect assigns the analysis frequencies to the values
    %   found in the 1xN vector fVect where N is the number of frequences.
    %   Default is [8.57, 10, 12, 15]
    %
    %   nHarmonics = k where k is a value between 1 and 8.  Sets the number
    %   of harmonics to use in computing the correlation basis functions.
    %   Default is 4.
    %
    %   SampleRate = sr where sr is a positive integer. Set the sample rate
    %   (in Hz) of the data that will be analyzed with BCI_CCA.  Default is 
    %   500.
    %
    %   SampleDuration = sd where is d is a positive scalar.  Sets the
    %   duration in seconds of the data segment that will be analyzed with
    %   BCI_CCA.  Each data segment analyzed must be this length.  The
    %   number of data points is calculated internally as the
    %   SampleDuration x SampleRate.  Default is 1.
    %
    % Usage:
    %   A set of basis functions of length SampleDuration are calculated 
    %   for each of the base frequencies identified by the Frequencies property.  
    %   The basis functions for a single frequency f are calculated using 
    %   both the sin and cos at each harmonic of f ranging from from 1:h, 
    %   where h is the value of nHarmonics property.   The basis functions
    %   are stored in the variable YData as a fx(2*h)xs array where f is the
    %   number of freqencies, h is nHarmonics, and s is the number of
    %   samples.  The number of harmonics is 2*h because both sin and cos
    %   are used for each harmonic.
    %
    %   The CCA is performed whenever data is assigned to the XData
    %   property of the BCI_CCA object.  The canonical correlation is computed
    %   between the observed data (XData) and the basis functions (YData).
    %   The canonical correlation is computed seperately for each frequency.
    %   The analysis results are stored in the following outputs object properties
    %   as cell arrays with length f (number of frequencies).
    %       XCoef - the canonical coefficients for the variable XData
    %       YCoef - the canonical coeffcients for teh variable YData
    %       Rho   - the canonical correlation
    %   BCI_CCA defines the frequency category of the XData by the set of
    %   basis function that produce the highest RHO.  The property
    %   FrequencyCategory provides the index of the frequency in the
    %   Frequency parameter that best describes the observed XData.
    %   
    %   e.g. if obj,Frequencies = [8.57, 10, 12, 15], an
    %   obj.FrequencyCategory value of 2 indicates that the obj.XData is
    %   fit best by the 10 Hz basis functions 
    %
    properties
        Frequencies %the frequencies for creating target timeseries Y
        NHarmonics %the number of harmonics to use in calculating Y
        XSampleDuration %the number of samples of XData
        XData   %the obseved data to use in the CCA
    end
    properties (SetAccess = private)
        YData
        XCoef
        YCoef
        Rho
        SampleRate
        NSamples
        FrequencyCategory

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
                    obj.XCoef{ii} = Xw;
                    obj.YCoef{ii} = Yw;
                    obj.Rho{ii} = R;
                end
                [~, obj.FrequencyCategory] = max(cell2mat(obj.Rho)); 
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