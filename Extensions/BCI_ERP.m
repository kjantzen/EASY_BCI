% BCI_ERP() Returns a handle to an ERP object that maitains and
% updates information about an ERP with three different experimental
% conditions
%
%Usage:
%
%   obj = BCI_ERP - creates an object for calculating and updating an ERP 
%       with three different experimental conditions.  The object is
%       created with and initialized with no parameters.  The parameters
%       are set using the information from the first BNS_HBSpikerBox trial 
%       packet that is passed to the UpdateERP Method.  All subsequent
%       trials must have the same number of pre and post stimulus samples.
%   
% Methods
%
%   obj.UpdateERP(trial) - adds the sample points in trail to the ERP.  
%       The trial information will be used to initialzie the BCI_ERP properties
%       on the firt call to to UpdateERP.  See below for a list of
%       properties.  The conditions (1,2 or 3) is determined from the trial
%       structure and the samples are added to the appropraite ERP.
%
% Properties
%   ERP - A [3,n] array of averaged sample points where the 3 rows represent
%       the different ERP conditions and the n columns represent the averaged 
%       sample points.
%   TimePnts - A [1xn] vector of values indicating the time of each sample
%       in ms relative to the onset of the timelocking event.
%   TrialCount - a [1, 3] vector of integers indicating the number of
%       trials in each of the 3 conditions.
%   PreSamples - The number of samples collected prior to the onset of the
%       timelocking event.
%   Srate - the sample rate 
%   Samples - the total number of samples in each ERP
%   StdErr - A [3,n] array n is the number of Samples in each ERP.
%       Contains the standard error of each ERP calculated as the stadard
%       deviation of the trials divided by the square root of the number of
%       trials
% 
% for ploting or further analysis, the properties can be read directly from
% the object
% example:
%   %create an erp object
%   erp = BCI_ERP();
% 
%   %create a .5 second trial with a .1 second baseline and a sample rate
%   %of 500 Hz
%   trial.sampleRate = 500;
%   trial.samples = 250;
%   trial.preSamp = 50;
%   trial.timePnts = ((0:trial.samples-1) - trial.preSamp)./trial.sampleRate
% 
%   %assign the trial to the first event marker
%   trial.evt = 1;
% 
%   %add some random data
%   trial.EEG = rand(1,trial.samples);
% 
%   %update the erp
%   erp.UpdateERP(trial)
%  
%   %plot all the ERP's
%   plot(erp.TimePnts, erp.ERP())
            %
classdef BCI_ERP < handle
    properties 
        ERP         %the actual erp
        FFT
        TimePnts    %the x axis time values
        FreqPnts
        TrialCount  %how many trial in each bin
        Trials
        PreSamples
        SRate
        Samples
        StdErr
    end
    properties (Access=private)
        erpSum
        fftSum
    end
    methods
        function obj = BCI_ERP()
       
            %the constructor takes no arguments because the parameters are
            %set using the first trial passed to UpdateERP
            obj.ERP = [];
            obj.Trials = [];
            obj.TrialCount = 0;
            obj.Samples = 0;
            obj.PreSamples = 0;
        end
        % *****************************************************************
        function obj = UpdateERP(obj, trial)            
            if obj.TrialCount == 0
                obj.TrialCount = zeros(1,3);
                obj.erpSum = zeros(3, trial.samples);  
                obj.ERP = obj.erpSum;
                obj.StdErr = obj.erpSum;
                obj.fftSum = zeros(3,trial.samples /2 + 1);
                obj.FFT = obj.fftSum;
                obj.TimePnts = trial.timePnts;
                obj.FreqPnts = trial.sampleRate * (0:trial.samples/2)/trial.samples;
                obj.SRate = trial.sampleRate;
                obj.Samples = trial.samples;
                obj.PreSamples = trial.preSamp;
                for ii = 1:3
                    obj.Trials(ii).Samples = zeros(trial.samples,1);
                end
            end

            if trial.samples ~= obj.Samples || trial.preSamp ~= obj.PreSamples
                error('BCI_ERP:BadTrialProperty', 'The trial properties do not match the ERP properties');
            end

            bline = mean(trial.EEG(1:trial.preSamp));
            trial.EEG  = trial.EEG - bline;
            obj.TrialCount(trial.evt) = obj.TrialCount(trial.evt) + 1;
            obj.erpSum(trial.evt,:) = obj.erpSum(trial.evt,:) + trial.EEG;
            obj.fftSum(trial.evt,:) = obj.fftSum(trial.evt,:) + obj.performFFT(trial);
            obj.Trials(trial.evt).Samples(:,obj.TrialCount(trial.evt)) = trial.EEG;
            obj.ERP(trial.evt,:) = obj.erpSum(trial.evt,:)./obj.TrialCount(trial.evt);
            obj.FFT(trial.evt,:) = obj.fftSum(trial.evt,:)./obj.TrialCount(trial.evt);
            obj.StdErr(trial.evt,:) = std(obj.Trials(trial.evt).Samples, 1,2)./sqrt(obj.TrialCount(trial.evt));
               
        end
    end
    methods (Access = private)
    function fftData = performFFT(obj, trial)
            twoSided = abs(fft(trial.EEG)/trial.samples);
            fftData  = twoSided(1:trial.samples/2+1);
            fftData(2:end-1) = 2 .* fftData(2:end-1);
            fftData = fftData .^2;
    end
    end
end
