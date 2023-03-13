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
   p.ERP.UpdateERPPlot(data);
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
   
    p.ax.ColorOrder(1,:) = [25/255, 130/255, 196/255];
    p.ax.ColorOrder(2,:) = [255/255, 89/255, 94/255];
    p.ax.ColorOrder(3,:) = [138/255, 201/255, 38/255];
    
    %initialize the plotting object by calling it and passing the axis in
    %which to plot
    p.ERP = BCI_ERPplot(p.ax);

end
