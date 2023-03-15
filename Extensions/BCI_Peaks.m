classdef BCI_Peaks
    properties 
        AmpThreshold = 100;
        WidthThreshold = 10;    %default of +- 10 pnts
        SmoothPoints = 0;
        AdjustThreshold = false;
        SearchAcrossChunks = false;
        ChunkMemory = 3;
        Peaks = [];
        HasNew

    end
    properties(Access = private)
        Buffer = [];
        IndexCount = 0; %the cumulative count of indexes reviewed

    end
    methods
        function obj = BCI_Peaks(AmpThreshold, WidthThreshold, SmoothPoints, AdjustThreshold, SearchAcrossChunks)
            %BYB_Peaks - an object for performing peaks detection on real
            %time data collected with the BYB spiker box,
            %USAGE:
            %   obj = BCI_Peaks() - creates an object using default
            %   parameters
            %
            %   obj = BYB_Peaks(AmpThreshold, WidthThreshold, SmoothPoints,
            %   AdjustThreshold, SearchAcrossChunks)
            %
            %   Optional Inputs
            %
            %   AmpThreshold - when detecting positive peaks, only samples 
            %   that exceed this threshold will be evaluated. Default = 100
            %
            %   WidthThreshold - an integer value indicating the minimum width
            %   of peak in samples.  For WidthThreshold = n, a peak must be the maximum
            %   absolute value with +- n samples.  Thus the minimum peak width 
            %   is 2n + 1. Default = 10;
            %
            %   SmoothPoints - number of points to use in smoothing the data
            %   before search for peaks. Set this value to 0 if no smoothing
            %   is desired.  Default = 0.  For more information see the
            %   Matlab smoothdata function.
            %
            %   AdjustThreshold - perform a crude adjustment to  AmpThreshold 
            %   to account for signal amplitude loss due to smoothing.
            %   Smoothing will reduce the amplitude of sharp peaks in the
            %   data.  if AdjustThreshold = True, the threhsold will be
            %   adjusted down by multiplying it by 
            %   (max(abs(postSmooth))/max(abs(preSmooth)). Default = false.
            %
            %   SearchAcrossChunks - prepends the last (2 * WidthThreshold)
            %   points from the previous data segment to the current data
            %   segment to account for possible undetected peaks at the
            %   very end of the previous segment. Default = true;
            %
            %RETURNS
            %   
            %   Information about identified peaks will be in the structure 
            %   array obj.Peaks.  The array will have
            %   one element per peak identified.  If no peaks were
            %   identified, the array will be empty ([]).
            %   The strucure has the following fields
            %       index - the index or sample into the sample vector at
            %       which the peak was located. A negative index indicated
            %       the peak occured in the previous data segment.
            %       adjvalue - the baseline adjusted value of the sample at the peak.
            %
            % EXAMPLE
            %   %
            %   create a simulated eye blink
            %       Fs = 1000;
            %        Si = 1/Fs;
            %        Duration = 4;
            %        
            %        BlinkFreq = 3;
            %        BlinkTime = 1/BlinkFreq;
            %        
            %        t = 0:Si:Duration -Si;
            %       
            %       d = ones(1,length(t));
            %       
            %       b = sin([0:Si:BlinkTime-Si] * 2 * pi *BlinkFreq);
            %       
            %       insertIndex = round((length(d) - length(b))/2);
            %       range = insertIndex:insertIndex + length(b) -1;
            %       d(range) = d(range) + b;
            %       d(d<1) = (d(d<1)-1) * .2 + 1  ;
            %       plot(t,d);
            %   
            % creates a peak object with a threshold suited to detect only
            % the positive component
            %   p = BYB_Peak(1.3, 10,0, false,false)
            %
            % search for peaks and display the results
            %   p = p.Detect(d);
            %   p.Peaks
            %
            % adjust the threshold so it is suitable for also finding the
            % negative component
            %   p.AmpThreshold = 1.1;
            %   p = p.Detect(d);
            %
           
           if nargin > 4
               obj.SearchAcrossChunks = SearchAcrossChunks;
           end
           if nargin > 3
               obj.AdjustThreshold = AdjustThreshold;
           end
           if nargin > 2
               obj.SmoothPoints = SmoothPoints;
           end
           if nargin > 1
               obj.WidthThreshold = WidthThreshold;
           end
           if nargin > 0 
               obj.AmpThreshold = AmpThreshold;
           end
           
        end
    
        function obj = Detect(obj, data, baseline)
            %the peak detection method
            %INPUT:
            % data - a real valued vector in which to search for peaks
            %
            %OPTIONAL
            %   baseline - the value to remove from all samples in the
            %   vector before searching,  If baseline is excluded the
            %   median of the data will be used
            %

            if nargin < 3
                baseline = median(data);
            end



           %combine with the previous input chunk if the search across flag
           %is set and if this is not the first chunk
            if isempty(obj.Buffer) || ~obj.SearchAcrossChunks
                tempBuffer = data;
                indexCorrection = 0;
            else
                %combine the last part of the data that could not be
                %evaluated on the last run to make sure no peaks are missed
                indx = length(obj.Buffer) -  obj.WidthThreshold * 2;
                tempBuffer = horzcat(obj.Buffer(indx:end), data);
                indexCorrection = obj.WidthThreshold * 2;
            end
            %set the object buffer to store the current data in case it
            %needs to be combined with the next chunk
            obj.Buffer = data;
            
            %remove the baseline from the data
            tempBuffer = tempBuffer - baseline;

            %adjust the threshold by the same amount
            actualThreshold = obj.AmpThreshold - baseline;


            %smooth the data if  smoothpoints is not set to zero
            if obj.SmoothPoints > 0
                [origMax, mIndx] = max(abs(tempBuffer));
                tempBuffer = smoothdata(tempBuffer, 2, "movmean", obj.SmoothPoints);
                if obj.AdjustThreshold 
                    newMax = abs(tempBuffer(mIndx));
                    adjRatio = newMax/origMax;
                    actualThreshold = actualThreshold * adjRatio;
                end
            end

            %find any peaks
            obj.Peaks = obj.findPeaks(tempBuffer,actualThreshold, indexCorrection);
            obj.IndexCount = obj.IndexCount + length(data);

            
            %add the baseline back into adjusted value
            if ~isempty(obj.Peaks)
                for ii = 1:length(obj.Peaks)
                    obj.Peaks(ii).value = obj.Peaks(ii).adjvalue + baseline;
                end
            end

        end
 
    end
    methods (Access = private)
        function peaks = findPeaks(obj, input, ampThresh, indexCorrection)
        
            %to find the peaks we will loop over all values that exceed the
            %threshold and determine if there is a value within the width 
            % threshold distance that is greater. If not we have found a
            % peak
            

            absInput = abs(input);

            minPosition = obj.WidthThreshold;
            maxPosition = length(absInput) - obj.WidthThreshold;
       
            peaks = [];
            
            %initialize a counter for where to look in the possible peak
            %indexes array (ppi)
            ii = minPosition+1;

            while ii < maxPosition
                
                if absInput(ii) < ampThresh
                    ii = ii + 1;
                    continue;
                end

                %define a search window around the current point
                searchPoints = ii-obj.WidthThreshold:ii+obj.WidthThreshold;
                
                %look for the maximum value in that region
                [~, indx] = max(absInput(searchPoints));
                indx = indx + min(searchPoints) -1;
                %if the current point is the maximum then it is a peak
                if indx == ii
                    peak.absindex = obj.IndexCount + ii;  %adjust the index so it is the total offset across segments
                    peak.index = ii - indexCorrection;
                    peak.adjvalue = input(ii);
                    ii = ii + obj.WidthThreshold;
                    peaks = [peaks, peak];
                else
                    %if the current point is not the maximum, move the
                    %maximum point and try again
                    if indx > ii
                        ii = indx;
                    else 
                        ii = ii + 1;
                    end
                end
                
            end

        end
    end
end
