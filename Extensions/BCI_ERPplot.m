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
classdef BCI_ERPplot
    properties 
        plotHandle     %the handle to the actual plot
        ax
        erp             %handle to an BCI_ERP object
    end
    properties (Constant)
        plotColors = {'#1B98E0', '#A62639', '#79B791'};
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

        function obj = UpdateERPPlot(obj, trial, plotRange)
            %Adds data the the existing plot for this chart object
            %
            %obj = UpdateChart(d) - adds the timeseries data in d to the
            %existing data chart.
            %
            %obj = UpdateChart(d, scaleRange) - adjust the vertical scale
            %of the axis to the values in 1x2 double array scaleRange. Eg -
            %to scale between -1 and 2 pass [-1,2] as the scaleRagen
            %parameter
            
            if nargin < 3
                autoScale = true;
            else
                autoScale = false;
            end
            obj.erp = obj.erp.UpdateERP(trial);
          
            %initialize the plot if it does not exist
            if isempty(obj.plotHandle)
             line(obj.ax, trial.timePnts, zeros(size(trial.timePnts)), 'Color', 'k');
             h = line(obj.ax, trial.timePnts, obj.erp.erp);
             obj.plotHandle = h;
             for ii = 1:3
                obj.plotHandle(ii).Color = obj.plotColors{ii};
                obj.plotHandle(ii).LineWidth = 1.5;
             end
             
                
            end                
          
            obj.plotHandle(trial.evt).XData = obj.erp.timePnts;
            obj.plotHandle(trial.evt).YData = obj.erp.erp(trial.evt,:);
                    
            axis(obj.ax,'tight');
            if ~autoScale
                obj.ax.YLim = plotRange;
            end
          
            drawnow();
          
        end
    end
end
