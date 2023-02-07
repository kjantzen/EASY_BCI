%Generic data handler template
function outStruct = simpleERP(inStruct, varargin)
	if nargin == 1
		outStruct = initialize(inStruct);
	else
		outStruct = analyze(inStruct, varargin{1});
	end
end
%this function gets called when data is passed to the handler
function p = analyze(p,data)
   p.ERP =  p.ERP.UpdateERPPlot(data);
%plot(data);
%   p.ERP.trialCount
%   plot(p.ax, p.ERP(1).timePnts, p.ERP.erp');
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

    p.ax = axes(p.handles.outputFigure);
    p.ax.FontSize = 14;
    p.ax.YLabel.String = "ERP amplitude (uV)";
    p.ax.YLabel.FontSize = 16;
    p.ax.XLabel.String = "Time (s)";
    p.ax.XLabel.FontSize = 16;

    p.ERP = BCI_ERPplot(p.ax);

end
