%generic data handler for the BNS BCI.
%the main function just determines whether the call to the handler is for 
%initializing or analysing
%the appropriate sub function is then called
%this allows for the creation of any number of single file handlers that
%can be selected as a single file from a user menu or other interface
function outStruct = singleChartAndFFT(inStruct, varargin)

%the initializer is called with only one input variable
    if nargin == 1
        outStruct = initialize(inStruct);
    else
        outStruct = analyze(inStruct, varargin{1}, varargin{2});
    end

end

%this function gets called when data is passed to the handler
function p = analyze(obj,p, dStruct)

    data = dStruct.EEG;
    data = data - mean(data);
    p.chartPlot1 = p.chartPlot1.UpdateChart(data);  
    p.fftPlot1 = p.fftPlot1.updateChart(data, [0, 100]);



end

%% this is the funciton that initializes the display and the analysis stream
% this is where you would add new objects that you want to use to plot or
% analyze your data chunks as they are being collected
    function p = initialize(p)
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
        p.handles.outputFigure = existingFigure(1);
        clf(p.handles.outputFigure);
    else
       %create a new figure to hold all the plots etc
        p.handles.outputFigure = figure;
        %name it so we can recognize it later if the software is rerun
        p.handles.outputFigure.Name  = 'BYB BCI Data Display';
    end
    
    %THIS IS LIKELY WHERE YOU WILL WANT TO START EDITING
    
    %create a plotting object to plot the raw time signal
    %*****************************************************
    %use subplot to create a plotting axis on the figure.  Subplot will
    %return a handle to a single plotting axis placed according to the row
    %column scheme provided.
    sp = subplot(1,3,[1,2]);
    %add a title to the axis
    sp.Title.String = 'Unfiltered raw data';
    sp.XLabel.String  = 'Time (seconds)';
    sp.YLabel.String = 'amplitude (uV units)';
    %create a new chart object and pass in the data sample rate, the length
    %of the chart and the axis to plot to.
    p.chartPlot1 = BCI_Chart(p.sampleRate, 5, sp);
  
    %create an fft plotting object to plot the power spectrum of the
    %unfitlered data
    sp = subplot(1,3,3);
    sp.Title.String = 'Unfiltered power spectrum'; 
    %the filter object takes as parameters, the sample rate of the data
    %collection, the length of the window to transform (in seconds), and
    %the axis to plot the data in.
    FFT_length = 5;
    p.fftPlot1 = BCI_FFTPlot(p.sampleRate, FFT_length, sp);
   

end