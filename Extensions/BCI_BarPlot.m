classdef BYB_BarPlot
    properties 
        ax
        Range = [0, 1];
        Value = 0;
        Bar = [];
        
    end
    methods
        function obj = BYB_BarPlot(plotAxis, varargin)
            %obj = BYB_barplot(plotAxis): Initializer for the barplotting
            %object
            %obj = BYB_barplot(plotAxis, range): Additionally initializes
            %the plotting range for subsequent data.  Range must be a 1x2
            %vector of real values with Range(1) < Range(2).
            %
            obj.ax = plotAxis;
  
        end
        function obj = set.Value(obj, Value)
            obj.Value = Value;
            obj = replot(obj);
            %b = bar(obj.ax, obj.Value);
            %obj.ax.YLim = obj.Range;
            %drawnow();
          
        end
        function obj = set.Range(obj, Range)
            obj.Range = Range;
            obj = replot(obj);
        end
    end
    methods (Access = private)
        function obj = replot(obj)
            if isempty(obj.Bar)
                obj.Bar = bar(obj.ax, obj.Value);
            else
                obj.Bar.YData = obj.Value;
                indx = round(64/range(obj.Range) * (obj.Value - obj.Range(1)));
                if indx < 1; indx = 1;end
                if indx > 64; indx = 64; end
                cols = colormap;
                obj.Bar.FaceColor = cols(indx,:);
            end
            obj.ax.YLim = obj.Range;
            drawnow();
        end
    end
end
