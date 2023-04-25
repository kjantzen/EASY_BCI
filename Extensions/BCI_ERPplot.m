%BCI_ERPplot returns a handle to an ERPplot object dynamically displaying 
% ERP for three different conditions in real time
% Optional name.parameter pairs
%   'AxisHandle' - a graphics Axes handle in which the mean time domain ERP
%   will be plotted. If not provided a default axis will be created.
%   
%   'FFTAxisHandle' - a graphics Axes handle in which the mean frequency
%   domain ERP will be plotted.  If not present the FFT data will not be
%   plotted.  Note that the FFT is the mean of the FFT of each single trial
%   and NOT the FFT of the mean ERP.
%
%Usage:
%
%   obj = BYB_ERPplot() - creates a blank plot in a new figure and returns
%       the object for adding trials and updating the plot.  
%   
%   myAxis = axes %create new axes
%   obj = BYB_Chart('AxisHandle', myAxis) - specifies the handle of the axis for
%       plotting
%
%   create an object that will plot both the time and frequency means
%   timeAxis = axes; fftAxis = axes
%   obj = BYB_Chart('AxisHandle', timeAxis, 'FFTAxisHandle', fftAxis);
% Methods
%
% obj.UpdateERPplot(trial) - adds the data in trial to the existing ERP
%   and updates the plot. The variable trial is structure that contains a 
%   single trial as returned from the BNS_HBSpikerbox driver.  Scale is a 2 
%   element vector of the form [min, max] that provides the vertical plot
%   range of the data.  If scale is not provided, the plot will scale
%   automatically.
%   Optional name, parameter pairs 
%       ERPScale - a (1,2) numeric vector indicating the  (min, max) plotting
%                   range of the ERP (in uV).
%       ShowStdErr - a scalar logical that when true will result in plotting 
%                   +- the standard error of the mean around each ERP.
%                   Default is to automatically scale to the size of the
%                   ERP.
%       PlotFFTLog - a scalar logical indicating whether the FFT amplitudes
%                   are displayed on a log scale.
%       FFTRange  - (1,2) numeric vector indicating the (min max) frequency
%                   range to plot on the FFT plot.  The default is (0,
%                   Nyquist)
%
% obj.ClearERP() - reinitializes the ERP and the plot.  Previous ERP data
%   will be lost
% obj.RefreshPlot() - erases the ERP plot without impacting the existing EEG
%   data.  Only the display is impacted.
%
% See also: 
%   BCI_ERP

classdef BCI_ERPplot < handle
    properties 
        PlotHandles         %the handles to the time line plots
        StdErrHandles       %handle to the patch objects for showing the stderr        
        PlotAxis            %the axss to plot the time series in
        FFTAxis             %the axis to plot the fft in
        ERP                 %handle to an BCI_ERP object
        Legend              %legend handle
    end
    properties (Access = private)
        legendText = [];
        baseLine    %a line object that marks uV = 0
        zeroLine    %a line object that marks t = 0
    end
    methods
        function obj = BCI_ERPplot(options)
            arguments
                options.AxisHandle (1,1) {mustBeA(options.AxisHandle,'matlab.graphics.axis.Axes')} = gobjects;
                options.FFTAxisHandle (1,1) {mustBeA(options.FFTAxisHandle,'matlab.graphics.axis.Axes')} = gobjects;
            end
            
            if ~isgraphics(options.AxisHandle)
                obj.PlotAxis = obj.newAxes;
            else
                obj.PlotAxis = options.AxisHandle;
            end

            obj.ERP = BCI_ERP();
            obj.FFTAxis = options.FFTAxisHandle;
            obj.PlotAxis.XLimitMethod = 'tight';
            obj.StdErrHandles = gobjects(3,1);
        end
        %*****************************************************************
        function RefreshPlot(obj)
            %refreshes the plot without changing the underlying ERP
            obj.PlotHandles = [];
            cla(obj.PlotAxis);
            if isgraphics(obj.FFTAxis)
                cla(obj.FFTAxis)
            end
        end
        %*****************************************************************
        function ClearERP(obj)
            %clears the ERP by creating an new ERP object and deleting the
            %plotting handle
            obj.ERP = BCI_ERP();
            obj.RefreshPlot;
        end
        %*****************************************************************
        function UpdateERPPlot(obj, trial, options)
            %Adds data the the existing plot for this chart object
            arguments
                obj
                trial
                options.ERPScale = 'auto';
                options.ShowStdErr (1,1) {mustBeNumericOrLogical} = false;
                options.FFTRange (1,2) {mustBeNumeric} = [0, trial.SampleRate/2];
                options.PlotFFTLog (1,1) {mustBeNumericOrLogical} = false;
            end
                
            if strcmp('auto', options.ERPScale)
                autoScale = true;
            else
                autoScale = false;
            end
            obj.ERP.UpdateERP(trial);
            trialCount = obj.ERP.TrialCount;
          
            %initialize the plot if it does not exist
            if isempty(obj.PlotHandles)
                 %draw a baseline 
                 obj.baseLine = line(obj.PlotAxis, trial.timePnts, zeros(1, length(trial.timePnts)), 'Color', 'k');
                 obj.zeroLine = line(obj.PlotAxis, [0,0], [-1,1], 'Color', 'k');
                 obj.baseLine.Annotation.LegendInformation.IconDisplayStyle = "off";
                 obj.zeroLine.Annotation.LegendInformation.IconDisplayStyle = "off";
                         
                 %create a time series for the std err
                 tv = [obj.ERP.TimePnts, fliplr(obj.ERP.TimePnts)];
                for ii = 1:3
                    %add the standard error
                    yv = [obj.ERP.ERP(ii,:)+obj.ERP.StdErr(ii,:), fliplr(obj.ERP.ERP(ii,:) - obj.ERP.StdErr(ii,:))];
                    obj.StdErrHandles(ii) = patch(obj.PlotAxis, tv, yv,obj.PlotAxis.ColorOrder(ii, :), 'FaceAlpha', .35, 'EdgeColor', 'none');
                    obj.StdErrHandles(ii).Annotation.LegendInformation.IconDisplayStyle = "off";
                end
                obj.PlotHandles = line(obj.PlotAxis, trial.timePnts, obj.ERP.ERP, 'LineWidth', 2);
            end                

            for ii = 1:3
                obj.StdErrHandles(ii).Visible = options.ShowStdErr;
            end

            yv = [obj.ERP.ERP(trial.evt,:)+obj.ERP.StdErr(trial.evt,:), fliplr(obj.ERP.ERP(trial.evt,:) - obj.ERP.StdErr(trial.evt,:))];
            obj.StdErrHandles(trial.evt).YData = yv;
            obj.PlotHandles(trial.evt).YData = obj.ERP.ERP(trial.evt,:);
            obj.zeroLine.YData = [-1,1]; %temporarily scale down to allow for rescaling of data
 
            if ~autoScale
                obj.PlotAxis.YLim = plotRange;
            else 
                obj.PlotAxis.YLimMode = 'auto';
            end
            for ii = 1:3
                obj.legendText{ii} = sprintf('Event %i, (%i trials)',ii, trialCount(ii));
            end
            if isempty(obj.Legend)
                obj.Legend = legend(obj.PlotAxis,obj.legendText);
                obj.Legend.AutoUpdate = true;
                obj.Legend.Box = false;
                obj.Legend.FontSize = 16;
            else
                obj.Legend.String = obj.legendText;          
            end

            %quick and dirty add of fft drawing
            %should probably pre-draw this and just change hte y data
            %during update.
            if isgraphics(obj.FFTAxis)
                plot(obj.FFTAxis, obj.ERP.FreqPnts, obj.ERP.FFT, 'LineWidth',2)
                obj.FFTAxis.XLim = options.FFTRange;
                if options.PlotFFTLog
                    obj.FFTAxis.YScale = 'log';
                else
                    obj.FFTAxis.YScale = 'linear';
                end
            end

            drawnow();
            obj.zeroLine.YData = obj.PlotAxis.YLim;
          
        end
    end
    % ********************************************************************
    % private helper functions
    methods (Access = private)
        function a = newAxes(~)
             if nargin < 1
                f = figure;
                f.Color = 'w';
                a = axes(f);
             end
        end
    end


end