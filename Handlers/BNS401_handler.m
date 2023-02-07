%Generic data handler template
function outStruct = singleChart(inStruct, varargin)
	if nargin == 1
		outStruct = initialize(inStruct);
	else
		outStruct = analyze(inStruct, varargin{1}, varargin{2});
	end
end
%this function gets called when data is passed to the handler
function p = analyze(p,data, event)

    %delete any data from event
    event = int8(event); %convert to signed integer so we can get negs too
    event(:) = 0; %erase any content

    %remove the baseline from the data before doing anything with it
   data = data - .65;

   %smooth the data before plotting it and detecting the peaks - this is
   %basically a moving window average
   data = smoothdata(data, 2, "movmean", 10);

   %detect the peaks
   p.Eye = p.Eye.Detect(data, 0);

   if ~isempty(p.Eye.Peaks)
       for ii = 1:length(p.Eye.Peaks)
           p.Eye.Peaks(ii)
           if p.Eye.Peaks(ii).index > 0
                event(p.Eye.Peaks(ii).index)  = sign(p.Eye.Peaks(ii).adjvalue);
           end
       end
   end
   
   p.Chart =  p.Chart.UpdateChart(data, event, [-.8, .8]);

end

%this function gets called when the analyse process is initialized
function p = initialize(p)

    existingFigure = findobj('Name', 'Very Simple BYB BCI Data Display');
    if ~isempty(existingFigure)
        p.handles.outputFigure = existingFigure(1);
        clf(p.handles.outputFigure);
    else
       %create a new figure to hold all the plots etc
        p.handles.outputFigure = figure('Position',[200,200,1000,300]);
        %name it so we can recognize it later if the software is rerun
        p.handles.outputFigure.Name  = 'Very Simple BYB BCI Data Display';
    end

    ax = axes(p.handles.outputFigure);
    p.Chart = BYB_Chart(p.sampleRate,5, ax);
    p.Eye = BYB_Peaks(.05, 10, 0, false, true);


end

