%Returns a handle to an chart object for dynamically displaying 
%timeseries data in real-time.
%
%Usage:
%
%   obj = BYB_Chart(Fs) - creates a chart based on data
%   collected at the samplerate Fs.  The default is to create the
%   plotting axis in a new figure.  The default plot length is 3 seconds.
% 
%   obj = BYB_Chart(Fs, ChartLength) - specifies the length of the
%   chart in seconds.  The plot will begin scrolling once
%   ChartLength seconds of data are plotted.
%
%   obj = BYB_Chart(Fs, ChartLength, axis) - specifies the axis
%   into which the data should be plotted.
%
%   pass data to the functions UpdateChart method to add data to
%   the plot
%
% Methods
%
%   chart = chart.UpdateChart(eeg, event) - updates the chart adding the
%   data in eeg the EEG/EMG channel and adding the data in event to the event
%   channel.  The plot is automatically scaled to the range of the data.
%
%   chart = chart.UpdateChart(eeg, event, [min, max]) - optionally scales
%   the data between min and max.  
%
            %
classdef BCI_ERPplot < handle
    properties 
        PlotHandle       %the handle to the actual plot
        Axis             %the axis to plot in
        ERP              %handle to an BCI_ERP object
        Legend           %legend handle
    end
    properties (Access = private)
        legendText = [];
        baseLine
        zeroLine
    end
    methods
        function obj = BCI_ERPplot(plotAxis)

            %create the figure and axis if it does not exist
            if nargin < 1
                f = figure;
                f.Color = 'w';
                plotAxis = axes(f);
                plotAxis.ColorOrder = [0,0,1;1,0,0;0,1,0];
                plotAxis.XLimitMethod = 'tight';
            end
            
            obj.ERP = BCI_ERP();
            obj.Axis = plotAxis;

        end
        %*****************************************************************
        function refreshPlot(obj)
            %refreshes the plot without changing the underlying ERP
            obj.PlotHandle = [];
            cla(obj.Axis);
        end
        %*****************************************************************
        function clearERP(obj)
            %clears the ERP by creating an new ERP object and deleting the
            %plotting handle
            obj.ERP = BCI_ERP();
            obj.refreshPlot;
        end
        %*****************************************************************
        function UpdateERPPlot(obj, trial, plotRange)
            %Adds data the the existing plot for this chart object         
            if nargin < 3
                autoScale = true;
            else
                autoScale = false;
            end
            obj.ERP.UpdateERP(trial);
            trialCount = obj.ERP.TrialCount;
          
            %initialize the plot if it does not exist
            if isempty(obj.PlotHandle)
             
             l = line(obj.Axis, trial.timePnts, zeros(size(trial.timePnts)), 'Color', 'k');
             l.Annotation.LegendInformation.IconDisplayStyle = "off";
             h = line(obj.Axis, trial.timePnts, obj.ERP.ERP);
             obj.PlotHandle = h;
             for ii = 1:3
                obj.PlotHandle(ii).LineWidth = 1.5;
             end
   
             %draw a baseline 
             obj.baseLine = line(obj.Axis, trial.TimePnts, zeros(1, length(timePnts)), 'Color', 'k');
             obj.zeroLine = line(obj.Axis, [0,0], [-1,1], 'Color', 'k');

            end                
          
            obj.PlotHandle(trial.evt).YData = obj.ERP.ERP(trial.evt,:);
                    
            if ~autoScale
                obj.Axis.YLim = plotRange;
            end
            for ii = 1:3
                obj.legendText{ii} = sprintf('Event %i, (%i trials)',ii, trialCount(ii));
            end
            if isempty(obj.Legend)
                obj.Legend = legend(obj.Axis,obj.legendText);
                obj.Legend.AutoUpdate = true;
                obj.Legend.Box = false;
                obj.Legend.FontSize = 16;
            else
                obj.Legend.String = obj.legendText;
          
            end
            drawnow();
            obj.zeroLine.YLim = obj.Axis.YLim;
          
        end
    end
end
