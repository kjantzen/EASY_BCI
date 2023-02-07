%Generic data handler template
function outStruct = snakeGame(inStruct, varargin)
    if nargin == 1
        outStruct = initialize(inStruct);
    else
        outStruct = analyze(inStruct, varargin{1}, varargin{2});
    end
end
%%
%this function gets called when data is passed to the handler
function p = analyze(p,data, event)
    
    %erase any digital triggers that may be in the event vector
    event = double(event) * 0;
    
    %smooth the data and remove the baseline
    data = smoothdata(data, 2, 'movmean', 10);
    data = data - .65;
    
    %assume looking to the middle
    p.BCI_State = 'Center';

    %detect the peaks 
    p.PeakDetect = p.PeakDetect.Detect(data, 0);
    
    if ~isempty(p.PeakDetect.Peaks) %only do this if there are peaks
        
        for ii = 1:length(p.PeakDetect.Peaks) %loop through each peak
            
            %should ignore any peak that is too close to the last one
            if ~isempty(p.lastPeak) && p.PeakDetect.Peaks(ii).absindex - p.lastPeak.absindex < 192
              continue;
            else
              p.lastPeak = p.PeakDetect.Peaks(ii);
            end
        
                
            %get the direction of the peak
            direction = sign(p.PeakDetect.Peaks(ii).adjvalue);
         
    
            %if the direction is negative we assume that is a look to the right
            if direction < 0
                p.BCI_State = 'Right';  
            else % 
                p.BCI_State = 'Left'; %otherwise it becomes left
            end
  
           %as long as the index is positive, add the peak to the event list 
           if p.PeakDetect.Peaks(ii).index > 0
                event(p.PeakDetect.Peaks(ii).index) = direction;
           end
        end
    end

    p.Chart =  p.Chart.UpdateChart(data, event, [-1, 1]);
    p.Snake = p.Snake.Move(p.BCI_State);

end
%% THIS FUNCTION IS CALLED WHEN INITIALIZING THE BCI
%this function gets called when the analyse process is initialized
function p = initialize(p)

    existingFigure = findall(0,'Type', 'figure', 'Name', 'Snake Game Demonstration');
    if ~isempty(existingFigure)
        p.handles.outputFigure = existingFigure(1);
        clf(p.handles.outputFigure);
    else
        %create a new figure to hold all the plots etc
        p.handles.outputFigure = uifigure('Position',[400,400,1000,600]);
        %name it so we can recognize it later if the software is rerun
        p.handles.outputFigure.Name  = 'Snake Game Demonstration';
    end

    
    ax = uiaxes(p.handles.outputFigure, 'Position', [10,10,500,580]);
    ax.XLabel.String = 'Time (s)';
    ax.YLabel.String = 'Amplitude (mV)';
    ax.Title.String = 'Electrooculogram';
    p.Chart = BYB_Chart(p.sampleRate,5, ax);
    p.PeakDetect = BYB_Peaks(0.15, 10, 10, false, true);
   
    p.BCI_State = 'Center';
    p.lastPeak = [];
    
   
    ax = uiaxes('Parent', p.handles.outputFigure, 'Position',[510, 10, 480,580]);
    p.Snake = BYB_Snake(ax);


end
