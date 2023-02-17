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
classdef BCI_Chart
    properties 
        scrolling       %flag to know whether the plot is srolling yet
        insertPoint     %the current place that data is being inserted into the plot
        plotHandle      %the handle to the actual plot

        displaySeconds  %the number of seconds to display in the plot
        displayPoints   %the number of points to display in the plot
        tAxis           %the current time axis to display
        sampleRate
        ax
    end
    properties (Access = private)
        tempBuffer;
        eventHandle
    end
    methods
        function obj = BCI_Chart(SampleRate, ChartLength, plotAxis)
            if nargin < 3
                f = figure;
                f.Color = 'w';
                plotAxis = axes(f);
            end
            if nargin < 2
                obj.displaySeconds = 3;
            else
                obj.displaySeconds = ChartLength;
            end
            if nargin < 1 
                error('Please provide a valid sample rate...');
            else 
                obj.sampleRate = SampleRate;
            end
            
            obj.scrolling = false;
            obj.insertPoint = 1;
            obj.displayPoints = obj.displaySeconds * SampleRate;
            obj.tempBuffer = zeros(1,obj.displayPoints);
            obj.tAxis = (1:obj.displayPoints)./SampleRate;
            h1 = plot(plotAxis, obj.tAxis, zeros(1,obj.displayPoints));
           % h2 = line(plotAxis, obj.tAxis, zeros(1,obj.displayPoints));
            obj.plotHandle = [h1];
            obj.plotHandle.LineWidth = 1.5;
         %   obj.plotHandle(2).Color = 'g';
            obj.ax = plotAxis;
                
        end
        function obj = UpdateChart(obj, eegChunk, eventChunk, plotRange)
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
            ln = length(eegChunk);
            lt = ln ./ obj.sampleRate;
            d = (obj.insertPoint + ln-1) - obj.displayPoints;
            
            dataChunk = eegChunk;%[eegChunk;double(eventChunk)];
            %maybe try accessing the ydata only once to improve speed
            
            nchans = size(dataChunk,1);

            if obj.scrolling 
                for ii = 1:nchans    
                    obj.plotHandle(ii).YData(1:obj.displayPoints-ln) = obj.plotHandle(ii).YData(ln+1:end);
                    obj.plotHandle(ii).YData(obj.displayPoints-ln+1:obj.displayPoints) = dataChunk(ii,:);
                    obj.plotHandle(ii).XData = obj.plotHandle(ii).XData + lt;
                end

            elseif d<=0
                for ii = 1:nchans
                obj.plotHandle(ii).YData(obj.insertPoint: obj.insertPoint + ln-1) = dataChunk(ii,:);
                obj.plotHandle(ii).YData(obj.insertPoint + ln: end) = mean(dataChunk(ii,:));
                end
                obj.insertPoint = obj.insertPoint + ln;
                
            else 
                for ii = 1:nchans
                obj.plotHandle(ii).YData(1:obj.displayPoints-ln) = obj.plotHandle(ii).YData(d:obj.displayPoints-ln-1+d);
                obj.plotHandle(ii).YData(obj.displayPoints-ln+1:obj.displayPoints) = dataChunk(ii,:);
         
                obj.plotHandle(ii).XData = obj.plotHandle(ii).XData + (d./obj.sampleRate);
                end
                obj.scrolling = true;
            end
            
            axis(obj.ax,'tight');
            if ~autoScale
                obj.ax.YLim = plotRange;
            end
            drawnow();
          
        end
    end
end
