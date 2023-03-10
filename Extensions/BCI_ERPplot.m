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
        plotHandle      %the handle to the actual plot
        ax              %the axis to plot in
        erp             %handle to an BCI_ERP object
    end
    properties (Constant)
        plotColors = {'#1B98E0', '#A62639', '#79B791'};
    end
    properties (Access = private)
        legendText = []
        leg       %legend handle
    end
    methods
        function obj = BCI_ERPplot(plotAxis)
            if nargin < 1
                f = figure;
                f.Color = 'w';
                plotAxis = axes(f);
            end
            
            obj.erp = BCI_ERP();
            obj.ax = plotAxis;

        end
        function refreshPlot(obj)
            obj.plotHandle = [];
            cla(obj.ax);
        end
        function clearERP(obj)
            obj.plotHandle = [];
            obj.erp = BCI_ERP();
        end
        function UpdateERPPlot(obj, trial, plotRange)
            %Adds data the the existing plot for this chart object         
            if nargin < 3
                autoScale = true;
            else
                autoScale = false;
            end
            obj.erp = obj.erp.UpdateERP(trial);
            trialCount = obj.erp.TrialCount;
          
            %initialize the plot if it does not exist
            if isempty(obj.plotHandle)
             
             l = line(obj.ax, trial.timePnts, zeros(size(trial.timePnts)), 'Color', 'k');
             l.Annotation.LegendInformation.IconDisplayStyle = "off";
             h = line(obj.ax, trial.timePnts, obj.erp.ERP);
             obj.plotHandle = h;
             for ii = 1:3
                obj.plotHandle(ii).Color = obj.plotColors{ii};
                obj.plotHandle(ii).LineWidth = 1.5;
             end
             %plot the single trial
           %   obj.plotHandle(4) = line(obj.ax, trial.timePnts, trial.EEG);  
            end                
          
            obj.plotHandle(trial.evt).YData = obj.erp.ERP(trial.evt,:);
                    
            axis(obj.ax,'tight');
            if ~autoScale
                obj.ax.YLim = plotRange;
            end
            for ii = 1:3
                obj.legendText{ii} = sprintf('Event %i, (%i trials)',ii, trialCount(ii));
            end
            if isempty(obj.leg)
                obj.leg = legend(obj.ax,obj.legendText);
                obj.leg.AutoUpdate = true;
                obj.leg.Box = false;
                obj.leg.FontSize = 16;
            else
                obj.leg.String = obj.legendText;
          
            end
            drawnow();
          
        end
    end
end
