%Generic data handler template
function outStruct = eyeBlink(inStruct, varargin)
    if nargin == 1
        outStruct = initialize(inStruct);
    else
        outStruct = analyze(inStruct, varargin{1}, varargin{2});
    end
end
%this function gets called when data is passed to the handler
function p = analyze(p,data, event)

    peaks = zeros(size(data));
    data = data - .65;
    data = p.BPFilt.filter(data);
    p.PeakDetect = p.PeakDetect.Detect(data, 0);
    if ~isempty(p.PeakDetect.Peaks)
        for ii = 1: length(p.PeakDetect.Peaks)
            if p.PeakDetect.Peaks(ii).adjvalue < 0 %ignore negative peaks
                continue
            end
            p.HBeatIndex(1:end-1) = p.HBeatIndex(2:end);
            p.HBeatIndex(end) = p.PeakDetect.Peaks(ii).absindex;
            if p.PeakDetect.Peaks(ii).index > 0
                peaks(p.PeakDetect.Peaks(ii).index) = sign(p.PeakDetect.Peaks(ii).adjvalue);
            end
        end
    
    end
    
    
    p.Chart =  p.Chart.UpdateChart(data, peaks, [-450, 450]);
 
    %calculate the RRInterval for the 60 samples
    RRInterval = diff(p.HBeatIndex)./p.sampleRate;

    %here is where it could be cleaned up if we wanted to get an NN
    HR = round( 60 / (mean(RRInterval)));
    HRV = round(std(RRInterval * 1000));
    p.handles.HR.Text = sprintf('%i BPM', HR);
    p.handles.HRV.Text = sprintf('%i msec.', HRV);
    

end

%this function gets called when the analyse process is initialized
function p = initialize(p)

    %create a figure for showing stuff
    existingFigure = findall(0,'Type', 'figure', 'Name', 'Example of heart beat recordings');
    if ~isempty(existingFigure)
        p.handles.outputFigure = existingFigure(1);
        clf(p.handles.outputFigure);
    else
        %create a new figure to hold all the plots etc
        p.handles.outputFigure = uifigure('Position',[400,400,1000,600]);
        %name it so we can recognize it later if the software is rerun
        p.handles.outputFigure.Name  = 'Example of heart beat recordings';
    end
    
    %create an axis for plotting the ACG
    ax = uiaxes(p.handles.outputFigure, 'Position', [10,10,700,580]);
    ax.XLabel.String = 'Time (s)';
    ax.YLabel.String = 'Amplitude (mV)';
    ax.Title.String = 'Electrocardiogram';

    uilabel('Parent', p.handles.outputFigure,...
        'Position', [750, 450, 200, 20],...
        'Text', 'Heart Rate (R-R Interval)')

    p.handles.HR = uilabel('Parent', p.handles.outputFigure,...
        'Position', [750, 400, 200, 40],...
        'Text', 'measuring...', ...
        'FontSize', 24);

    uilabel('Parent', p.handles.outputFigure,...
        'Position', [750, 300, 200, 20],...
        'Text', 'Heart Rate Variability (SDRR)')

    p.handles.HRV = uilabel('Parent', p.handles.outputFigure,...
        'Position', [750, 250, 200, 40],...
        'Text', 'measuring...',...
        'FontSize', 24);
    
    
    %create a chart oobject that uses the axis
    p.Chart = BCI_Chart(p.sampleRate,5, ax);
    
    %create a peak detection object
    p.PeakDetect = BCI_Peaks(200, 10, 0, false, true);
    
    %create a lowpass filter
    p.BPFilt = BCI_Filter(p.sampleRate, [0, 40], 'low');
    
    %initialize a variable to hold information about when a peak occured
    p.HBeatIndex = zeros(1,30);

end
