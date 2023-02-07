%generic data handler for the BNS BCI.
%the main function just determines whether the call to the handler is for 
%initializing or analysing
%the appropriate sub function is then called
%this allows for the creation of any number of single file handlers that
%can be selected as a single file from a user menu or other interface
function outStruct = multipleChartAndFFT(inStruct, varargin)

%the initializer is called with only one input variable
    if nargin == 1
        outStruct = initialize(inStruct);
    else
        outStruct = analyze(inStruct, varargin{1}, varargin{2});
    end

end

%this function gets called when data is passed to the handler
function p = analyze(p,data, event)

    data = data - mean(data);
    p.chartPlot1 = p.chartPlot1.UpdateChart(data);  
    p.fftPlot1 = p.fftPlot1.updateChart(data, [0,100]);

    data = p.filter.filter(data);
    p.chartPlot2 = p.chartPlot2.UpdateChart(data);
    p.fftPlot2 = p.fftPlot2.updateChart(data, [0,100]);
    

    data = data.^2;
    data = p.lpfilt.filter(data);
    p.chartPlot3 = p.chartPlot3.UpdateChart(data);
    p.barplot.Value = (mean(data)); 


end

%% this is the funciton that initializes the display and the analysis stream
% this is where you would add new objects that you want to use to plot or
% analyze your data chunks as they are being collected
    function o = initialize(o)
%p = initializeProcessesing(p) 
%initializes the BCI analysis and plotting stream prior to the onset of
%data collection.  It accepts a structure containing the programs
%parameters and returns an updated and saved version of the parameters.
%Use this function to initialize any analysis functions you want to add to
%your BCI
%

    %THIS SECTION INITIALIZES THE DISPLAY
    %check to see if the figure already exists
    %the figure is recognized by its name but there are other ways to
    %recognize the figure
    existingFigure = findobj('Name', 'BYB BCI Data Display');
    if ~isempty(existingFigure)
        o.handles.outputFigure = existingFigure(1);
        clf(o.handles.outputFigure);
    else
       %create a new figure to hold all the plots etc
        o.handles.outputFigure = figure;
        %name it so we can recognize it later if the software is rerun
        o.handles.outputFigure.Name  = 'BYB BCI Data Display';
    end
    
    %THIS IS LIKELY WHERE YOU WILL WANT TO START EDITING
    
    %create a plotting object to plot the raw time signal
    %*****************************************************
    %use subplot to create a plotting axis on the figure.  Subplot will
    %return a handle to a single plotting axis placed according to the row
    %column scheme provided.
    sp = subplot(3,3,[1,2]);
    %add a title to the axis
    sp.Title.String = 'Unfiltered raw data';
    sp.XLabel.String  = 'Time (seconds)';
    sp.YLabel.String = 'amplitude (ADC units)';
    %create a new chart object and pass in the data sample rate, the length
    %of the chart and the axis to plot to.
    o.chartPlot1 = BYB_Chart(o.sampleRate, 3, sp);
  
    %create an fft plotting object to plot the power spectrum of the
    %unfitlered data
    sp = subplot(3,3,3);
    sp.Title.String = 'Unfiltered power spectrum'; 
    %the filter object takes as parameters, the sample rate of the data
    %collection, the length of the window to transform (in seconds), and
    %the axis to plot the data in.
    FFT_length = 1;
    o.fftPlot1 = BYB_FFTPlot(o.sampleRate, FFT_length,sp);
   
    %create a second plotting object for the filtered time data
    %**********************************************************
    sp = subplot(3,3,[4,5]);
    sp.Title.String = 'Band passed data';
    sp.XLabel.String  = 'Time (seconds)';
    sp.YLabel.String = 'amplitude (ADC units)'
    %because it is an object, we can create a second chart object that is
    %independent of the one we created above.
    o.chartPlot2 = BYB_Chart(o.sampleRate, 3,sp);
  
    %create a filter object to filter each chunk as it comes in
    %i am unecessarily using alot of variables to hold the filter
    %parameters because it is more illustrative than just passing values to
    %the object
    low_edge = 1;
    high_edge = 50;
    filter_range = [low_edge  high_edge];
    filter_type = 'bandpass'; %this must be one of 'low', 'high', 'bandpass' or 'stop'
    o.filter = BYB_Filter(o.sampleRate, filter_range, filter_type);
    
    %create an fft plotting object to plot the power spectrum of the
    %filtered data
    sp = subplot(3,3,6);
    sp.Title.String = 'Unfiltered power spectrum'; 
    %the filter object takes as parameters, the sample rate of the data
    %collection, the length of the window to transform (in seconds), and
    %the axis to plot the data in.
    FFT_length = 1;
    o.fftPlot2 = BYB_FFTPlot(o.sampleRate, FFT_length,sp); 
   
    
     %create a third plotting object for the rectified time data
    %**********************************************************
    o.lpfilt = BYB_Filter(o.sampleRate, [0,40], 'low');
    
    sp = subplot(3,3,[7,8]);
    sp.Title.String = 'Rectified ECG';
    sp.XLabel.String  = 'Time (seconds)';
    sp.YLabel.String = 'amplitude (ADC units ^2)'
    %because it is an object, we can create a second chart object that is
    %independent of the one we created above.
    o.chartPlot3 = BYB_Chart(o.sampleRate, 3,sp);
    
    sp = subplot(3,3,9);
    sp.Title.String = 'mean EMG';
    o.barplot = BYB_BarPlot(sp);
    o.barplot.Range = [0, 5*10e3];
   
    
end