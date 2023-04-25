%Generic data handler template
function outStruct = eyeBlink(inStruct, varargin)
    if nargin == 1
        outStruct = initialize(inStruct);
    else
        outStruct = analyze(inStruct, varargin{1}, varargin{2});
    end
end
%%
%this function gets called when data is passed to the handler
function p = analyze(obj, p, data)
    
    %erase any digital triggers that may be in the event vector
    event = double(data.Event) * 0;
    
    %smooth the data and remove the baseline
    eeg = smoothdata(data.EEG, 2, 'movmean', 10);
    eeg = eeg - 100;
    
    p.BCI_State = 'Center';
    %detect the peaks 
    p.PeakDetect = p.PeakDetect.Detect(eeg, 0);
    
    if ~isempty(p.PeakDetect.Peaks)
    
        %loop through each peak
        for ii = 1:length(p.PeakDetect.Peaks)
            
            %should ignore any peak that is too close to the last one
            if ~isempty(p.lastPeak) && p.PeakDetect.Peaks(ii).absindex - p.lastPeak.absindex < 192
              continue;
            else
              p.lastPeak = p.PeakDetect.Peaks(ii);
            end
        
                
            %get the direction of the peak - peak value and slope (not
            %available yet) may also be important for how to interpret the peak
            direction = sign(p.PeakDetect.Peaks(ii).adjvalue);
         
    
            %if the direction is negative we assume that is a look to the right
            if direction < 0
                if strcmp(p.BCI_State,'Left')  %if the current state is left, it will change to center
                    p.BCI_State = 'Center';
                else
                    p.BCI_State = 'Right';  %otherwise it will change to right
                end
            else % this is the other case when the movement is the the left
                if strcmp(p.BCI_State,'Right')  %if the current state is right, it moves to the center
                    p.BCI_State = 'Center';
                else
                    p.BCI_State = 'Left'; %otherwise it becomes left
                end
            end
           p.handles.knob.Value = p.BCI_State; %update the knob
           drawnow;
    
           if p.PeakDetect.Peaks(ii).index > 0
                event(p.PeakDetect.Peaks(ii).index) = direction;
           end
    
        end
    
    end
    p.Chart =  p.Chart.UpdateChart(eeg, event, [-1, 1]);
    p.Snake = p.Snake.Move(p.BCI_State);

end
%% THIS FUNCTION IS CALLED WHEN INITIALIZING THE BCI
%this function gets called when the analyse process is initialized
function p = initialize(p)

    existingFigure = findall(0,'Type', 'figure', 'Name', 'Example of an Eye Blink BCI');
    if ~isempty(existingFigure)
        p.handles.outputFigure = existingFigure(1);
        clf(p.handles.outputFigure);
    else
        %create a new figure to hold all the plots etc
        p.handles.outputFigure = uifigure('Position',[400,400,1000,600]);
        %name it so we can recognize it later if the software is rerun
        p.handles.outputFigure.Name  = 'Example of an Eye Movement BCI';
    end

     existingFigure = findall(0,'Type', 'figure', 'Name', 'Snake Game');
    if ~isempty(existingFigure)
        f = existingFigure(1);
      clf(f);
    else
        %create a new figure to hold all the plots etc
       f = figure('Position',[400,400,1000,600]);
        %name it so we can recognize it later if the software is rerun
        f.Name  = 'Example of an Eye Movement BCI';
    end
    
    
    ax = uiaxes(p.handles.outputFigure, 'Position', [10,10,700,580]);
    ax.XLabel.String = 'Time (s)';
    ax.YLabel.String = 'Amplitude (mV)';
    ax.Title.String = 'Electrooculogram';
    p.Chart = BYB_Chart(p.sampleRate,5, ax);
    p.PeakDetect = BYB_Peaks(0.15, 10, 10, false, true);
    p.handles.knob = uiknob(p.handles.outputFigure, 'discrete','Position', [780, 50, 150, 200]);
    p.handles.knob.Items = {'Left','Center','Right'};
    p.BCI_State = 'Center';
    p.lastPeak = [];
    p.handles.knob.Value = p.BCI_State;

   
    ax = axes('Parent', f);
    ax.XGrid = "on";
    ax.YGrid = "on";
    ax.XAxis.Visible = "off";
    ax.YAxis.Visible = "off";
    p.Snake = BYB_Snake(ax);


end
