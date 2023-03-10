%Generic data handler template
function outStruct = singleChart(inStruct, varargin)
	if nargin == 1
		outStruct = initialize(inStruct);
	else
		outStruct = analyze(inStruct, varargin{1}, varargin{2});
	end
end
%this function gets called when data is passed to the handler
function p = analyze(obj, p,data)
   p.Chart =  p.Chart.UpdateChart(data.EEG, [], [-450, 450]);
end

%this function gets called when the analyse process is initialized
function p = initialize(p)

    existingFigure = findobj('Name', 'ERP example');
    if ~isempty(existingFigure)
        p.handles.outputFigure = existingFigure(1);
        clf(p.handles.outputFigure);
    else
       %create a new figure to hold all the plots etc
        p.handles.outputFigure = figure('Position',[200,200,1000,300]);
        %name it so we can recognize it later if the software is rerun
        p.handles.outputFigure.Name  = 'ERP example';
    end

    ax = axes(p.handles.outputFigure);
    p.Chart = BCI_Chart(p.sampleRate,5, ax);
    p.ERP = [];

end
