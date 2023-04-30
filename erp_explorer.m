function erp_explorer(eegFile)

fprintf('Opening EEG plotting and analysis tool...\n');

if nargin == 0
    [fn,fp] = uigetfile('*.set');
    if fn == 0
        fprintf('User selected cancel\n');
        return;
    end
    eegFile = fullfile(fp, fn);

end
try
    w = waitbar(0, 'loading the EEG data');
    %p = plot_params;
    guiScheme = load('Scheme.mat');
    p.guiScheme = guiScheme;
    
    p.EEG = loadEEGFile(eegFile);
    if isempty(p.EEG)
        error('Something went wrong loading the file');
    end
    
    %build the figure
    waitbar(.25, w, 'Creating the user interface.');
    p.ts_colors = lineColors;
    handles = buildGUI(p);
    
    waitbar(.75, w, 'Populating controls.');
    %initialize the cursor
    addDefaultCursors(handles, p);
    handles.figure.UserData = p;
    initializeDisplay(handles);
      
    
    %initialize the displays and plot the data
    waitbar(1, w, 'Drawing your ERP time series and maps.');
    callback_toggleallchannel([],handles.check_allchans,handles);
    
    handles.figure.Visible = 'on';
    close(w);
    fprintf('...done\n');
catch me
    close(w);
    rethrow(me)
end
% ************************************************************************
function callback_loadNewData(hObject, event, h)
    p = h.figure.UserData;   

     try
        h.figure.Visible = 'off';
        [fName,fPath] = uigetfile('*.set','Select an epoched eeglab set file');
        h.figure.Visible = 'on';
    catch me
        h.figure.Visible = 'on';
        rethrow(me)
    end
    if fName == 0
        fprintf('User selected Cancel');
        return;
    end
    pd = uiprogressdlg(h.figure, "Cancelable",'off', 'Indeterminate','on',...
        'Icon','info','Message','Loading EEG data and calculating FFT','Title','Loading data');
   
        newFile = fullfile(fPath, fName);
    
    EEG = loadEEGFile(newFile);
    pd.Message = 'Reinitializing the display properties and plots.';
    if ~isempty(EEG)
        p.EEG = EEG;
        h.figure.UserData = p;
        initializeDisplay(h);
        callback_ploterp(hObject,event,h);
    end
    close(pd)

%***************************************************************************
function EEG = loadEEGFile(fileName)
EEG = [];
if ~isfile(fileName)
    error('The files %s could not be found.', fileName)
end
EEG = load(fileName, '-mat');

%check to see if this is a structure or just its fields
if isfield(EEG, 'EEG')
    EEG = EEG.EEG;
end
if EEG.trials == 1
    error('This data is not epoched and will not work with this viewer');
end
if ~isfield(EEG, 'EVENTLIST')
    error('This set file does not have the required bin information.  Try running BINLIST on it first.');
end

EEG = calculateSummaryStatistics(EEG);
%***************************************************************************
function EEG = calculateSummaryStatistics(EEG)

%initialize some variables to hold intermediate steps
erp = zeros(EEG.nbchan, EEG.pnts, EEG.EVENTLIST.nbin);
stderr = erp;
nfft = 2^nextpow2(EEG.pnts);
freqs = 0:EEG.srate/nfft:EEG.srate/2;
Y = zeros(EEG.nbchan, nfft, EEG.trials);
fftAmp = zeros(EEG.nbchan, nfft/2+1, EEG.trials);
fftMean = zeros(EEG.nbchan, nfft/2+1,EEG.EVENTLIST.nbin);
fftStdErr = fftMean;

%do the fft
for ch = 1:EEG.nbchan
   Y(ch,:,:) = fft(squeeze(EEG.data(ch,:,:)), nfft)./nfft;
   fftAmp(ch,:,:) = abs(Y(ch,1:nfft/2+1,:));
   fftAmp(ch,2:end,:) = fftAmp(ch,2:end,:) * 2;
end

%calculate the mean of each condition
binVect = [EEG.EVENTLIST.eventinfo.bini];
for cc = 1:EEG.EVENTLIST.nbin
    trialVect = find(binVect==cc);
    epochList = [EEG.EVENTLIST.eventinfo(trialVect).bepoch];
    erp(:,:,cc) = mean(squeeze(EEG.data(:,:,epochList)),3);
    stderr(:,:,cc) = std(squeeze(EEG.data(:,:,epochList)),1,3)./sqrt(length(epochList)); 
    fftMean(:,:,cc) = mean(squeeze(fftAmp(:,:,epochList)),3);
    fftStdErr(:,:,cc) = std(squeeze(fftAmp(:,:,epochList)),1,3)./sqrt(length(epochList));
end

EEG.erp = erp;
EEG.stderr = stderr;
EEG.fft = Y;
EEG.fftAmp = fftAmp;
EEG.fftMean = fftMean;
EEG.fftStderr = fftStdErr;
EEG.freqs = freqs;

%***************************************************************************    
function initializeDisplay(h)

h.figure.Pointer = 'watch';
drawnow;


h.menu_fft.Checked = false;

%get the current information from the figure userdata
p = h.figure.UserData;
addDefaultCursors(h, p)

cname = {p.EEG.EVENTLIST.bdf.description};
h.list_condition.Items = cname;
h.list_condition.ItemsData = 1:length(cname);
h.list_condition.Value = 1;

chans = {p.EEG.chanlocs.labels};
ch_data = zeros(length(chans),2);
ch_data(:,1) = 1:length(chans);
ch_data = mat2cell(ch_data, ones(1,length(ch_data)));

h.list_channels.Items = chans;
h.list_channels.ItemsData = ch_data;
h.list_channels.Value = ch_data(1,:);

h.spinner_mintime.Value = max(p.EEG.times(1),h.spinner_mintime.Value);
h.spinner_mintime.UserData = p.EEG.freqs(1);
h.spinner_mintime.Limits = [p.EEG.times(1), p.EEG.times(end)];
h.spinner_mintime.Value = p.EEG.times(1);

h.spinner_maxtime.Value = min(p.EEG.times(end),h.spinner_maxtime.Value);
h.spinner_maxtime.UserData = p.EEG.freqs(end);
h.spinner_maxtime.Limits = [p.EEG.times(1), p.EEG.times(end)];
h.spinner_maxtime.Value = p.EEG.times(end);

h.spinner_maxamp.UserData = 10;
h.spinner_minamp.UserData = 0;

h.figure.Pointer = 'arrow';

%***************************************************************************
function callback_togglemapoption(hObject, event, h)
%toggle mean cursor status
hObject.Checked = ~hObject.Checked;
plot_topos(h)
%***************************************************************************
function callback_toggleautoscale(hObject, event, h)

hObject.Checked = ~hObject.Checked;
h.spinner_maxamp.Enable = ~hObject.Checked;
h.spinner_minamp.Enable = ~hObject.Checked;

callback_ploterp(hObject, event, h)
%************************************************************************
function callback_toggletopomenustate(hObject, event, h)

for ii = 1:2
    h.menu_mapscale(ii).Checked = false;
end
hObject.Checked = true;
plot_topos(h)

%**************************************************************
function callback_toggleplotoption(hObject, event, h)

hObject.Checked = ~hObject.Checked;

callback_ploterp(hObject, event, h);

%**************************************************************
function callback_togglefftoption(hObject, event, h)

EEG = h.figure.UserData.EEG;
hObject.Checked = ~hObject.Checked;
c = h.axis_erp.UserData;
tmp = c.active;
if hObject.Checked
    c.active = c.freq;
    c.time = tmp;
    mnt = EEG.freqs(1);mxt = EEG.freqs(end);stp = diff(EEG.freqs(1:2));
else
    c.active = c.time;
    c.freq = tmp;
    mnt = EEG.times(1);mxt = EEG.times(end);stp = diff(EEG.times(1:2));
end

h.axis_erp.UserData = c;

temp = h.spinner_maxamp.Value;
h.spinner_maxamp.Value = h.spinner_maxamp.UserData;
h.spinner_maxamp.UserData = temp;

temp = h.spinner_minamp.Value;
h.spinner_minamp.Value = h.spinner_minamp.UserData;
h.spinner_minamp.UserData = temp;

temp = h.spinner_mintime.Value;
h.spinner_mintime.Limits = [mnt, mxt];
h.spinner_mintime.Value = h.spinner_mintime.UserData;
h.spinner_mintime.UserData = temp;
h.spinner_mintime.Step = stp;

temp = h.spinner_maxtime.Value;
h.spinner_maxtime.Limits = [mnt, mxt];
h.spinner_maxtime.Value = h.spinner_maxtime.UserData;
h.spinner_maxtime.UserData = temp;
h.spinner_maxtime.Step = stp;

callback_ploterp(hObject, event, h);


%**************************************************************
function callback_changePlotRange(hObject, event, h)

tag = hObject.Tag;

%check to make sure the min and max are not opposite
mnt = h.spinner_mintime.Value;
mxt = h.spinner_maxtime.Value;
mna = h.spinner_minamp.Value;
mxa = h.spinner_maxamp.Value;

if mnt >= mxt
    p = h.figure.UserData;
    if mxt == p.EEG.times(end) || strcmp(tag, 'maxtime')
        mnt = mxt - h.spinner_mintime.Step;
        h.spinner_mintime.Value = mnt;
    elseif mnt == p.EEG.times(1) || strcmp(tag, 'mintime')
        mxt = mnt + h.spinner_maxtime.Step;
        h.spinner_maxtime.Value = mxt;
    end
end

if mna >=mxa
    mna = mxa - 1;
    h.spinner_minamp.value = mna;
end

callback_ploterp(hObject,event,h);

%*************************************************************************
function callback_editconditions(~,~,h)
p = h.figure.UserData;
waitfor(wwu_EditEEGConditions(p.EEG));
callback_reloadfiles([],[],h, true);
%*************************************************************************
%function to handle when user changes the status of the "All Channel" option
function callback_toggleallchannel(hObject, event, h)

manual_select = ~event.Value;

h.list_channels.Enable = manual_select;
cur_selected = h.list_channels.Value;

%select all the regular channels
if ~manual_select
    d = h.list_channels.ItemsData;
    s = cell2mat(d');
    h.list_channels.Value = d((s(:,1)>0));
    h.list_channels.UserData = cur_selected;
else
    %restore previous selection
    cs = h.list_channels.UserData;
    if ~isempty(cs)
        h.list_channels.Value = cs;
    end

end

callback_ploterp([],[],h);

%**************************************************************************
function callback_handlekeyevents(hObject, event, h)

switch event.Key
    case {'rightarrow', 'leftarrow'}
        c = getActiveCursor(h);
        
        if contains(event.Key, 'right')
            new_t = c.cursor(c.currentcursor).time + c.mincursorstep;
        else
            new_t = c.cursor(c.currentcursor).time - c.mincursorstep;
        end
        if new_t >= c.minpos && new_t <= c.maxpos
            c.cursor(c.currentcursor) = update_cursor_position(c.cursor(c.currentcursor), new_t, c.mincursorstep);
            saveActiveCursor(h,c)
            plot_topos(h);
        end
end

%**************************************************************************
%main function for handling mouse events that select and control the cursors
function callback_handlemouseevents(hObject, event,h)

persistent lastCursorSelected
if isempty(lastCursorSelected)
    lastCursorSelected = 0;
end
%button types are:
%   normal  -   left mouseclick
%   alt     -   right mouse button OR control & left button
%   extend  -   shift & either button
btype = h.figure.SelectionType;

%get the current data from the figure
c = getActiveCursor(h);

%leave if there are no cursors and if any other mouse button combos occur
%the latter will change as functionality is added
if isempty(c.cursor) || ~contains(btype, 'normal'); return; end


%get the current cursor informatino from the plot
cp = h.axis_erp.CurrentPoint;
%get the axis limits
xl = h.axis_erp.XLim;
yl = h.axis_erp.YLim;

%check to see if the mouse points is in the plot area
if cp(1,1) < xl(1) || cp(1,1) > xl(2) || cp(1,2) < yl(1) || cp(1,2) > yl(2)
    return
end

switch event.EventName
    case 'WindowMousePress'
        c.dragging = true;
        saveActiveCursor(h,c); %save the cursor before making more calls to functinos that load cursor data.
        new_cursor = has_clicked_on_cursor(cp, c.cursor);
        if new_cursor > 0
            c = switch_cursors(c, new_cursor);
        end
        c.cursor(c.currentcursor) = update_cursor_position(c.cursor(c.currentcursor), cp(1), c.mincursorstep);
        saveActiveCursor(h,c); %save it again to update the cursor

    case 'WindowMouseRelease'
        c.dragging = false;
        saveActiveCursor(h,c);
        plot_topos(h);

    case 'WindowMouseMotion'
        if c.dragging
            xl = h.axis_erp.XLim;
            if cp(1) >= xl(1) && cp(2) <= xl(2) %out of range
                c.cursor(c.currentcursor) = update_cursor_position(c.cursor(c.currentcursor), cp(1), c.mincursorstep);
                saveActiveCursor(h,c);
            end
        else
            sel_cursor = has_clicked_on_cursor(cp, c.cursor);
            if sel_cursor > 0
                c.cursor(sel_cursor).polygon.FaceAlpha = 1;
                c.cursor(sel_cursor).polygon.LineWidth = 1;
                lastCursorSelected = sel_cursor;
            else
                if lastCursorSelected > 0
                    c.cursor(lastCursorSelected).polygon.FaceAlpha = .5;
                    c.cursor(lastCursorSelected).polygon.LineWidth = .5;
                    lastCursorSelected = 0;
                end
            end
            
        end
end
%**************************************************************************
function c = getActiveCursor(h)
   cinfo = h.axis_erp.UserData;
   c = cinfo.active; 
%**************************************************************************
function saveActiveCursor(h, c)
    cinfo = h.axis_erp.UserData;
    cinfo.active = c;
    h.axis_erp.UserData = cinfo;
%**************************************************************************
%check to see if the location clicked in the plot window is on an existing
%cursor
function cursor_num = has_clicked_on_cursor(mouse_location, cursor)

for ii = 1:length(cursor)
    if (isinterior(cursor(ii).polygon.Shape, mouse_location(1,1), mouse_location(1,2)))>0
        cursor_num = ii;
        return
    end
end
cursor_num = 0;
%**************************************************************************
%move the cursor to a new position defined by the current x and y locaiton
%of the mouse pointer in the plot window
function cursor = update_cursor_position(cursor, new_time, samp_interval)


%a sample interval has been included so make sure the cursor is a
%multiple of that interval
if nargin > 2
    new_time = samp_interval * floor(new_time/samp_interval);
end
cursor.time = new_time;
curr_loc = cursor.polygon.Shape.Vertices(1,1);
delta_loc = new_time - curr_loc - samp_interval/2;
cursor.polygon.Shape.Vertices(:,1) = cursor.polygon.Shape.Vertices(:,1) + delta_loc;
%*************************************************************************
function addDefaultCursors(h, p)

c.time.cursor(1).time = p.EEG.times(end)/2;
c.time.cursor(1).width = 10;
c.time.cursor(1).open = false;
%c.time.cursor(1).polygon = build_cursor(c.time.cursor(1), h);
c.time.width = 10;
c.time.mincursorstep = 1/p.EEG.srate * 1000;
c.time.maxpos = p.EEG.times(end);
c.time.minpos = p.EEG.times(1);
c.time.currentcursor = 1;
c.time.dragging = false;

c.freq.cursor(1).time = p.EEG.freqs(end)/2;
c.freq.width = 2;
c.freq.cursor(1).open = false;
%c.freq.cursor(1).polygon = build_cursor(c.freq.cursor(1), h);
c.freq.mincursorstep = p.EEG.freqs(2);
c.freq.maxpos = p.EEG.freqs(end);
c.freq.minpos = p.EEG.freqs(1);
c.freq.currentcursor = 1;
c.freq.dragging = false;

c.active = c.time;
h.axis_erp.UserData = c;

%*************************************************************************
%manage events from the cursor menus.  Includes adding and remvoving
%cursors
function callback_managecursors(hObject, event, h)

%determine wether to update te time or fft cursors
isFFT = h.menu_fft.Checked;


c = getActiveCursor(h);
p = h.figure.UserData;


switch(event.Source.Tag)
    case 'add'
        if isempty(c.cursor)
            enum = 1;
        else
            enum = length(c.cursor) + 1;
        end

        if isFFT
            %this is a frequency cursor
            c.mincursorstep = p.EEG.freqs(2);
            c.maxpos = p.EEG.freqs(end);
            c.minpos = p.EEG.freqs(1);
        else
            %this is a time cursor
            c.mincursorstep = 1/p.EEG.srate * 1000;
            c.maxpos = p.EEG.times(end);
            c.minpos = p.EEG.times(1);
        end
      
        c.cursor(enum).time = h.axis_erp.XLim(2)/2;
        c.cursor(enum).width = 10;
        c.cursor(enum).open = false;
        c.cursor(enum).polygon = build_cursor(c.cursor(enum), c.mincursorstep, c.width, h);
        
        c = switch_cursors(c, enum);

    case 'subtract' %remove the current cursor
        if isempty(c.cursor) %nothing to delete
            return
        end

        delete(c.cursor(c.currentcursor).polygon);
        c.cursor(c.currentcursor) = [];
        c.currentcursor = []; %set thh current cursor to nothing so the switch cursor routine ignores teh deleted cursor
        c = switch_cursors(c, 1);
end

saveActiveCursor(h,c)
plot_topos(h)

%**************************************************************************
%rebuild all existing cursors when the plot changes
function rebuild_cursors(h)

c = getActiveCursor(h);
cnum = length(c.cursor);
if cnum < 1
    return
end

for ii = 1:cnum
    c.cursor(ii).polygon = build_cursor(c.cursor(ii), c.mincursorstep, c.width,h);
end
saveActiveCursor(h,c)


%**************************************************************************
%build a cursor based on the size of the current plotting window
function pg = build_cursor(cursor,w, bw, h)


w = w/2;
yl = h.axis_erp.YLim;

% %draw the cursor
rect_x = [cursor.time-w, cursor.time+w,cursor.time+w,...
    cursor.time-w, cursor.time-w];
rect_y = [yl(2),yl(2),yl(1), yl(1), yl(2)];

ps = polyshape(rect_x, rect_y);
hold(h.axis_erp, 'on');
pg = plot(h.axis_erp, ps);
pg.Annotation.LegendInformation.IconDisplayStyle = 'off';
pg.FaceColor = 'w';
pg.EdgeColor = 'w';
h.axis_erp.YLim = yl;
hold(h.axis_erp, 'off');

%**************************************************************************
function r = range(x)

r = max(x) - min(x);
%*************************************************************************
%switch between current cursors
function cinfo = switch_cursors(cinfo, new_cnum)

if ~isempty(cinfo.currentcursor)
    cinfo.cursor(cinfo.currentcursor).polygon.LineWidth = .35;
end
if ~isempty(new_cnum) && ~isempty(cinfo.cursor)
    cinfo.cursor(new_cnum).polygon.LineWidth = 1;
    cinfo.currentcursor = new_cnum;
end

%**************************************************************************
function [d,se, fVal, s,labels_or_times, ch_out, cond_sel] = getdatatoplot(EEG, h, o)

arguments
    EEG;
    h;
    o.MapMode = false;
    o.GetFFT = false;
    o.Cursor = [];
    o.aveBetween = false;
    o.doStats = false;
    o.doFDR  = false
end

d = []; se = [];
labels_or_times = [];
ch_out = [];
cond_sel = [];
s = [];
fVal = [];

%if cursor information is passed we will send back only the information
%specific to the time of each cursor, otherwise the entire time series will
%be returned.
if o.MapMode && isempty(o.Cursor)
    return
end

%get the conditions, channels and subject to plot from the listboxes
cond_sel = h.list_condition.Value;
ch = cell2mat(h.list_channels.Value');

if o.GetFFT
    XValues = EEG.freqs;
else
    XValues = EEG.times;
end

%get the time points to plot or map
if o.MapMode
    t = sort([o.Cursor.time]); %sort so that maps always increase in time
    pt = zeros(size(t));
   
    for ii = 1:length(t)
        [~,pt(ii)] = min(abs(t(ii) - XValues));  %get the exact time of the cursor
    end
else
    pt =1:length(XValues); %get all the points
end

%get the channels from the selected conditions
ch_sel = ch(find(ch(:,1)),1);
ch_out = ch_sel;    %send this back to the calling function
if o.MapMode
    ch_sel = 1:length(EEG.chanlocs); %overwrite channel selection if we are mapping
end

if o.aveBetween
    if o.GetFFT
        d = mean(EEG.fftMean(ch_sel, pt(1):pt(2), cond_sel),2);
        se = std(EEG.fftMean(ch_sel, pt(1):pt(2), cond_sel),1,2)./sqrt(pt(2)-pt(1));
    else
        d = mean(EEG.erp(ch_sel, pt(1):pt(2),cond_sel),2);
        se = std(EEG.erp(ch_sel, pt(1):pt(2), cond_sel),1,2)./sqrt(pt(2)-pt(1));
    end
else
    if o.GetFFT
        d = EEG.fftMean(ch_sel, pt, cond_sel);
        se = EEG.fftStderr(ch_sel, pt, cond_sel);
    else    
        d = EEG.erp(ch_sel, pt, cond_sel);
        se = EEG.stderr(ch_sel, pt, cond_sel);
    end
end

ncond = size(d,3);
if o.doStats
    % if there is only one condition, compute the single sample ttest
    if ncond == 1
        tVal = d./se;
        df = EEG.EVENTLIST.trialsperbin(cond_sel)-1;
        p = tcdf(abs(tVal),df, 'upper');
        fVal = tVal.^2;  %convert to an F score so it is on the same scale as the calculations below and so I dont have to change labels
    else 
        %otherwise do a generalized 1-way comparison across conditions
        [fVal, p] = oneWayFromSummaryData(d, se, EEG.EVENTLIST.trialsperbin(cond_sel));
    %    if o.MapMode
    %        fVal = fVal';
    %        p = p';
    %    end
    end
    
    if o.doFDR
        [~, pm] = fdr(p,.05);
        s = pm;
    else
        s = zeros(size(p));
        s(p<.05) = 1;
    end
end

%no stats information for individual subject data
%   end
labels_or_times = {EEG.chanlocs(ch_sel).labels};

%if this is for the mapping routine, return the times of the maps instead
%of the labels of the channels
if o.MapMode
    labels_or_times = t;
end

%************************************************************************
function [F,p] = oneWayFromSummaryData(means, se, nT)

    %data is a channel X point X condition array
    sz = size(means);
    nChans = sz(1);
    nPnts = sz(2);
    nConds = sz(3);

    %get rid of singletone dimensions that result from having only a single
    %cursor
    means = squeeze(means);
    se = squeeze(se);
    
    s  = size(means);
    dims1 = s(1:end-1);
    dims1(end+1) = 1;
    dims2 = s;
    dims2(1:end-1) = 1;
    
    if nPnts > 1 && nChans > 1
        nTrials(1,1,:) = nT;
        dfB = ones(dims1).*(nConds-1);
   %     dfB(1,1,:) = nConds-1;
   %     dfB = repmat(dfB, dims1,1);
    
    else
        nTrials = nT;
        dfB = repmat(nConds-1, dims1);
    
    end   
    N = repmat(nTrials, dims1);
    dfE = repmat(sum(nT) - length(nT), dims1);

    GM = repmat(mean(means,length(s)), dims2);
    MSB = sum((means-GM).^2 .* N, length(s))./dfB;

    VAR = (se .* sqrt(N)).^2;
    MSE = sum(VAR.*(N-1),length(s))./dfE;

    F = MSB./MSE;
    p = fcdf(F, dfB, dfE, 'upper');
    if nChans == 1
        F = F'; p = p';
    end


%************************************************************************
% plot the topographic maps indicated by the active cursors
function plot_topos(h)

if h.menu_mapquality.Checked
    gridscale =  300;
else
    gridscale = 64;
end
averageBetweenCursors = h.menu_cursormean.Checked;
plotFFT = h.menu_fft.Checked;
doStats = h.menu_dostat.Checked;
doFDR = h.menu_dofdr.Checked;

%get the currently seleced  map scaling option
for ii = 1:2
    if h.menu_mapscale(ii).Checked
        break
    end
end
scale_option = ii;
has_stat = false;  %assume there are no stats
c = getActiveCursor(h); %get the cursor information so we know times to plot

p = h.figure.UserData;
my_h = h.panel_topo.UserData; %get handles to the subplots

n_maps = length(c.cursor);
if averageBetweenCursors
    if n_maps ~= 2
        warning('Averaging between cursors only works when 2 cursors are available. You have %i.  Disabling this option', n_maps)
        h.menu_cursormean.Checked = 'off';
        averageBetweenCursors = false;
    else
        n_maps = 1; %reduce the number of maps
    end
end
[d, ~,s, pv,map_time, ch_out, cond_num] = getdatatoplot(p.EEG, h, ...
    'MapMode', true', 'GetFFT', plotFFT, 'Cursor', c.cursor, ...
    'aveBetween', averageBetweenCursors, 'doStats', doStats, 'doFDR', doFDR);
if scale_option ==1; map_scale = max(max(max(abs(d)))); end

if ~isempty(s)
    d(:,:,end+1) = s;
    has_stat = true;
end

if n_maps < 1
    ch = h.panel_topo.Children;
    delete(ch);
    return
end

%there are three possible states here
%the first is when there is only one condition being display
comp_conds = true; %flag indicating a comparison of conditions
n_conds = size(d,3); %the number of conditions
total_maps = n_conds * n_maps;  %total maps to display

if n_conds==1 || (n_conds>1 && n_maps==1)
    max_cols = 5 ;

    nrows = ceil(total_maps/max_cols);
    ncols = ceil(total_maps/nrows);
    if size(d,3)==1; comp_conds = false; end
else

    max_cols = size(d,3);% n_maps;
    ncols = max_cols;
    nrows = n_maps;%size(d,3);

end

pcount = 0;
%delete any unused axes
for ii = length(my_h):-1:total_maps+1
    delete(my_h(ii));
    my_h(ii) = [];
end

%delete the colorbars
cb_h = findobj(h.panel_topo, 'Type', 'Colorbar');
if ~isempty(cb_h)
    delete(cb_h);
end

msize = 5; %markersize for displaying the channels

for ii = 1:n_maps
    for jj = 1:n_conds %this will be for comparing conditions
        pcount = pcount + 1;
        v = d(:,ii,jj);
        if scale_option ==2; map_scale = max(abs(v)); end

        if pcount <= length(my_h)
            my_h(pcount) = subplot(nrows, ncols, pcount, 'Parent', h.panel_topo);
        else
            if isempty(my_h)
                my_h = subplot(nrows, ncols, pcount,'Parent', h.panel_topo);
                my_h.Toolbar.Visible = 'off';
            else
                my_h(pcount) = subplot(nrows, ncols, pcount,'Parent', h.panel_topo);
                my_h(pcount).Toolbar.Visible = 'off';
            end
        end
        cla(my_h(pcount));
        
        eval_string = [];
        if jj==n_conds && has_stat %this is the statistical map
            ms = [0,max(max(d(:,:,n_conds))) * .8];
            %ms = [0,max(abs(v))];
            if ms(2)==0; ms(2) = 1; end %just in case there are no stat sig results
            title_string = 'F score';
            cmap = autumn;
            eval_string = '''conv'', ''off''';
            extraChans = find(pv(:,ii));
        else
            ms = [-map_scale; map_scale];
            title_string =  h.list_condition.Items{cond_num(jj)};
            cmap = jet;
            extraChans = ch_out;
        end

        %build the command string for the topoplot'
        mapstring = 'wwu_topoplot(v, p.EEG.chanlocs, ''axishandle'', my_h(pcount),''colormap'', cmap, ''maplimits'', ms,  ''style'', ''map'', ''numcontour'', 0, ''gridscale'', gridscale';

        %change it based on the different options
      %   if jj==n_conds && has_stat
            mapstring = [mapstring, ',  ''emarker2'', {extraChans, ''o'', ''k'', msize, 1}'];
      %  end
        if ~isempty(eval_string)
            mapstring = [mapstring, ', ', eval_string, ');'];
        else
            mapstring = [mapstring, ');'];
        end

        %evaluate the command string
        eval(mapstring)
        if scale_option == 2
            cb = colorbar(my_h(pcount));
            cb.Label.Color = 'w';
            cb.Color = 'w';
        elseif jj==n_conds && has_stat
            cb = colorbar(my_h(pcount));
            cb.Units = 'normalized';
            cb.Position(1) = my_h(pcount).Position(1) + my_h(pcount).Position(3);
            cb.Label.String = 'F-score';
            cb.Label.Color = 'w';
            cb.Color = 'w';
        end

        if ii==1  && comp_conds
            my_h(pcount).Title.String = title_string;
            my_h(pcount).Title.Interpreter = 'none';
            my_h(pcount).Title.Color = 'w';
        end
        if plotFFT
            units = 'Hz';
        else
            units = 'ms';
        end
        if averageBetweenCursors
            my_h(pcount).XLabel.String = sprintf('%5.1f-%5.1f %s', map_time(1),map_time(2), units);
        else
            my_h(pcount).XLabel.String = sprintf('%5.1f %s', map_time(ii), units );
        end
        my_h(pcount).XLabel.Color = 'w';
        my_h(pcount).XLabel.Position = [0, -.52, 0];
        my_h(pcount).XLabel.Visible = true;


    end
end

if scale_option ==1
    ht = h.panel_topo.Position(4);

    cb = colorbar(my_h(1));
    cb.Units = 'pixels';
    cb.Position = [40, 20, 16, ht-40];
    cb.Label.String = '\muV';
    cb.Label.Color = 'w';
    cb.Color = 'w';

end


h.panel_topo.UserData = my_h;
drawnow nocallbacks
%***************************************************************************
%main erp drawing function
function callback_ploterp(hObject, event, h)

stacked = h.menu_stack.Checked;
userScale = ~h.menu_autoscale.Checked;
SEoverlay = h.menu_stderr.Checked;
separation = h.spinner_distance.Value/100;
mnTime = h.spinner_mintime.Value;
mxTime = h.spinner_maxtime.Value;
mnAmp = h.spinner_minamp.Value;
mxAmp = h.spinner_maxamp.Value;
plotFFT = h.menu_fft.Checked;
doStats = h.menu_dostat.Checked;
doFDR = h.menu_dofdr.Checked;

p = h.figure.UserData;
[d, se,~, stat,labels,~,cond_sel] = getdatatoplot(p.EEG, h,'GetFFT', plotFFT, 'doStats', doStats, 'doFDR', doFDR);

%can't plot it if it is not there!
if isempty(d)
    return
end

%preallocate for the legend names
%I am not preallocating for the line structures because I am lazy
legend_names = cell(1,size(d,3));
legend_handles = [];

if plotFFT
    XValues = p.EEG.freqs;
    XString = 'Frequency (Hz)';
else
    XValues = p.EEG.times;
    XString = 'Time (ms)';
end

% if the user has selected the butter fly plot option where
% are stacked on the same origin.
if ~stacked
    if userScale
        spread_amnt = max(abs([mnAmp, mxAmp])) * separation;   %get the plotting scale
    else
        spread_amnt = max(max(max(abs(d)))) * separation;   %get the plotting scale
    end
    %v = 1:1:size(d,1);
    v = size(d,1):-1:1;
    spread_matrix = repmat(v' * spread_amnt, 1, size(d,2), size(d,3));
    d = d + spread_matrix;
end

%main plotting loop - plot the time series for each condition
cla(h.axis_erp);

for ii = 1:size(d,3)
    hold(h.axis_erp, 'on');
    dd = squeeze(d(:,:,ii));

    if ~isempty(se) && SEoverlay
        for jj = 1:size(d,1)
            e = squeeze(se(jj,:,ii));
            xe = [XValues, fliplr(XValues)];
            ye = [dd(jj,:) + e, fliplr(dd(jj,:)-e)];
            er = patch(h.axis_erp,xe, ye,p.ts_colors(ii, :));
            er.FaceColor = p.ts_colors(ii, :);
            er.EdgeColor = 'None';
            er.FaceAlpha = .3;
        end

    end

    ph = plot(h.axis_erp, XValues, dd', 'Color', p.ts_colors(ii, :), 'LineWidth', 2);
    hold(h.axis_erp, 'on');

    
    for phi = 2:length(ph)
        ph(phi).Annotation.LegendInformation.IconDisplayStyle = 'off';
    end

    legend_handles(ii) = ph(1);
    legend_names(ii) = h.list_condition.Items(cond_sel(ii));

    if ~isempty(stat)
        tt = repmat(XValues, size(stat,1),1);
        splot = scatter(h.axis_erp, tt(stat>0)', dd(stat>0)',100,'filled');
        splot.CData =  p.ts_colors(ii, :);%clust_colors(s(s>0),:);
        splot.MarkerFaceAlpha = .5;
    end
 

end
hold(h.axis_erp, 'off');

%handle axes and scaling differently depending on whether the plot is
%stacked or not
if stacked
    if userScale
        h.axis_erp.YLim = [mnAmp, mxAmp];
    else
        h.axis_erp.YLim = [min(min(min(d))) * 1.1, max(max(max(d))) * 1.1];
    end
    l = line(h.axis_erp, h.axis_erp.XLim, [0,0],...
        'Color', [.5,.5,.5], 'LineWidth', 1.5);
    l.Annotation.LegendInformation.IconDisplayStyle = 'off';
    h.axis_erp.YTickMode = 'auto';
    h.axis_erp.YTickLabel = h.axis_erp.YTick;
    h.axis_erp.YLabel.String = 'microvolts';
else
    h.axis_erp.YLim = [min(min(min(d))) - (spread_amnt * .1), max(max(max(d))) + (spread_amnt * .1)];
    h.axis_erp.YTick = sort(spread_matrix(:,1));
    h.axis_erp.YTickLabel = labels(v);
    h.axis_erp.YLabel.String = 'microvolts x channel';
end

h.axis_erp.XGrid = 'on'; h.axis_erp.YGrid = 'on';
h.axis_erp.XLim = [mnTime, mxTime];
h.axis_erp.XLabel.String = XString;
h.axis_erp.YDir = 'normal';
h.axis_erp.FontSize = 14;

%draw a vertical line at 0 ms;
time_lock_ms = min(abs(p.EEG.times));
l = line(h.axis_erp, [time_lock_ms, time_lock_ms], h.axis_erp.YLim,...
    'Color', [.5,.5,.5], 'LineWidth', 1.5);
l.Annotation.LegendInformation.IconDisplayStyle = 'off';

if length(legend_names) > 6
    legend_columns = 6;
else
    legend_columns = length(legend_names);
end
lg = legend(h.axis_erp, legend_handles, legend_names, 'box', 'off', 'Location', 'NorthOutside', 'NumColumns', legend_columns,'Interpreter', 'none');
lg.Color = p.guiScheme.Axis.BackgroundColor.Value;
lg.TextColor = p.guiScheme.Axis.AxisColor.Value;
lg.LineWidth = 2;
lg.FontSize = 14;

%rebuild and plot existing cursors to fit the currently scaled data
rebuild_cursors(h)
plot_topos(h)

% *************************************************************************
function handles = buildGUI(p)

sz = get(0, 'ScreenSize');
W = round(sz(3) * .6);
if sz(4) < 1080
    H = sz(4);
else
    H = 1080;
end
figpos = [(sz(3)-W)/2, sz(4) - H, W, H];

% [~,fname,~] = fileparts(erpFile{:});
% figureTitle = sprintf('EEG Tool: %s', fname);
g = p.guiScheme;
handles.figure = uifigure(...
    'Color', g.Window.BackgroundColor.Value,...
    'Position', figpos,...
    'NumberTitle', 'off',...
    'Menubar', 'none',...
    'Name', 'none');

handles.figure.Visible = 'off';


%handles.figure.Visible = false;
handles.gl = uigridlayout('Parent', handles.figure,...
    'ColumnWidth',{160, '1x'},...
    'RowHeight', {35, '1x','1x', '1x'},...
    'BackgroundColor', g.Window.BackgroundColor.Value);

%panel for holding the topo plot
handles.panel_topo = uipanel(...
    'Parent', handles.gl,...
    'AutoResizeChildren', false,...
    'HighlightColor', g.Panel.BorderColor.Value,...
    'FontName', g.Panel.Font.Value,...
    'ForegroundColor', g.Panel.FontColor.Value,...
    'FontSize', g.Panel.FontSize.Value,...
    'BackgroundColor', g.Panel.BackgroundColor.Value);
handles.panel_topo.Layout.Column = 2;
handles.panel_topo.Layout.Row = 4;

handles.axis_erp = uiaxes(...
    'Parent', handles.gl,...
    'Units', 'normalized',...
    'OuterPosition', [0,0,1,1],...
    'Interactions',[],...
    'XColor', g.Axis.AxisColor.Value,...
    'YColor', g.Axis.AxisColor.Value,...
    'Color', g.Axis.BackgroundColor.Value,...
    'FontName', g.Axis.Font.Value,...
    'FontSize', g.Axis.FontSize.Value);

handles.axis_erp.Layout.Column = 2;
handles.axis_erp.Layout.Row = [2 3];
handles.axis_erp.Toolbar.Visible = 'off';

%**************************************************************************
%Create a panel to hold the  line plot options
handles.panel_plotopts = uipanel(...
    'Parent', handles.gl,...
    'BorderType', 'none',...
    'AutoResizeChildren', 'off',...
    'HighlightColor', g.Panel.BackgroundColor.Value,...
    'FontName', g.Panel.Font.Value,...
    'ForegroundColor', g.Panel.FontColor.Value,...
    'FontSize', g.Panel.FontSize.Value,...
    'BackgroundColor', g.Panel.BackgroundColor.Value);
handles.panel_plotopts.Layout.Column = 2;
handles.panel_plotopts.Layout.Row = 1;


uilabel('Parent', handles.panel_plotopts,...
    'Position', [10, 7, 60, 20],...
    'Text', 'X-axis range',...
    'HorizontalAlignment','left',...
    'FontName', g.Label.Font.Value,...
    'FontSize', g.Label.FontSize.Value,...
    'FontColor', g.Label.FontColor.Value);

handles.spinner_mintime = uispinner(...
    'Parent', handles.panel_plotopts,...
    'Position', [75,7,100,20],...
    'Value', p.EEG.times(1), ...
    'Limits', [p.EEG.times(1), p.EEG.times(end)],...
    'Step',diff(p.EEG.times(1:2)),...
    'RoundFractionalValues', 'off',...
    'ValueDisplayFormat', '%6.2f ms',...
    'Tag', 'mintime',...
    'BackgroundColor', g.Axis.BackgroundColor.Value,...
    'FontName', g.Checkbox.Font.Value,...
    'FontSize', g.Checkbox.FontSize.Value,...
    'FontColor', g.Checkbox.FontColor.Value);

uilabel('Parent', handles.panel_plotopts,...
    'Position', [175, 7, 20, 20],...
    'Text', 'to',...
    'HorizontalAlignment','center',...
     'FontName', g.Label.Font.Value,...
    'FontSize', g.Label.FontSize.Value,...
    'FontColor', g.Label.FontColor.Value);

handles.spinner_maxtime = uispinner(...
    'Parent', handles.panel_plotopts,...
    'Position', [200,7,100,20],...
    'Value', p.EEG.times(end), ...
    'Limits', [p.EEG.times(1), p.EEG.times(end)],...
    'Step',diff(p.EEG.times(1:2)),...
    'RoundFractionalValues', 'off',...
    'ValueDisplayFormat', '%6.2f ms',...
    'Tag', 'maxtime',...
    'BackgroundColor', g.Axis.BackgroundColor.Value,...
    'FontName', g.Checkbox.Font.Value,...
    'FontSize', g.Checkbox.FontSize.Value,...
    'FontColor', g.Checkbox.FontColor.Value);

uilabel('Parent', handles.panel_plotopts,...
    'Position', [320, 7, 60, 20],...
    'Text', 'Amp range',...
    'HorizontalAlignment','left',...
    'FontName', g.Label.Font.Value,...
    'FontSize', g.Label.FontSize.Value,...
    'FontColor', g.Label.FontColor.Value);


handles.spinner_minamp = uispinner(...
    'Parent', handles.panel_plotopts,...
    'Position', [380,7,80,20],...
    'Value', -5, ...
    'Limits', [-inf, 0],...
    'Step',.1,...
    'RoundFractionalValues', 'off',...
    'ValueDisplayFormat', '%3.1f uV',...
    'Tag', 'mintime', ...
    'Enable', false,...
    'BackgroundColor', g.Axis.BackgroundColor.Value,...
    'FontName', g.Checkbox.Font.Value,...
    'FontSize', g.Checkbox.FontSize.Value,...
    'FontColor', g.Checkbox.FontColor.Value);


uilabel('Parent', handles.panel_plotopts,...
    'Position', [460, 7, 20, 20],...
    'Text', 'to',...
    'HorizontalAlignment','center',...
    'FontName', g.Label.Font.Value,...
    'FontSize', g.Label.FontSize.Value,...
    'FontColor', g.Label.FontColor.Value);


handles.spinner_maxamp = uispinner(...
    'Parent', handles.panel_plotopts,...
    'Position', [480,7,80,20],...
    'Value', 5, ...
    'Limits', [0, inf],...
    'Step',.1,...
    'RoundFractionalValues', 'off',...
    'ValueDisplayFormat', '%3.1f uV',...
    'Tag', 'maxtime', ...
    'Enable', false,...
    'BackgroundColor', g.Axis.BackgroundColor.Value,...
    'FontName', g.Checkbox.Font.Value,...
    'FontSize', g.Checkbox.FontSize.Value,...
    'FontColor', g.Checkbox.FontColor.Value);


uilabel('Parent', handles.panel_plotopts,...
    'Position', [580, 7, 80, 20],...
    'Text', 'Stack Dist.',...
    'HorizontalAlignment','Left',...
    'FontName', g.Label.Font.Value,...
    'FontSize', g.Label.FontSize.Value,...
    'FontColor', g.Label.FontColor.Value);


handles.spinner_distance = uispinner(...
    'Parent', handles.panel_plotopts,...
    'Position', [660,7,80,20],...
    'Value', 100, ...
    'Limits', [1, inf],...
    'RoundFractionalValues', 'on',...
    'ValueDisplayFormat', '%i %%',...
    'BackgroundColor', g.Axis.BackgroundColor.Value,...
    'FontName', g.Checkbox.Font.Value,...
    'FontSize', g.Checkbox.FontSize.Value,...
    'FontColor', g.Checkbox.FontColor.Value);


%**************************************************************************
%Create a panel to hold the  plotting options of condition, channel and
%subject
handles.panel_po = uipanel('Parent', handles.gl,...
    'Title', 'Select Content to Plot',...
    'HighlightColor', g.Panel.BorderColor.Value,...
    'FontName', g.Panel.Font.Value,...
    'ForegroundColor', g.Panel.FontColor.Value,...
    'FontSize', g.Panel.FontSize.Value,...
    'BackgroundColor', g.Panel.BackgroundColor.Value);

handles.panel_po.Layout.Column = 1;
handles.panel_po.Layout.Row = [1 4];
drawnow;
pause(1);

psh = handles.panel_po.InnerPosition(4);

uilabel('Parent', handles.panel_po,...
    'Position', [10,psh-30,100,20],...
    'Text', 'Conditions to plot',...
    'FontName', g.Label.Font.Value,...
    'FontSize', g.Label.FontSize.Value,...
    'FontColor', g.Label.FontColor.Value);


uilabel('Parent', handles.panel_po,...
    'Position', [10,psh-220,100,20],...
    'Text', 'Channels to plot',...
    'FontName', g.Label.Font.Value,...
    'FontSize', g.Label.FontSize.Value,...
    'FontColor', g.Label.FontColor.Value);


handles.list_condition = uilistbox(...
    'Parent', handles.panel_po, ...
    'Position', [10, psh-180, 140, 150 ],...
    'MultiSelect', 'on',...
    'BackgroundColor', g.Dropdown.BackgroundColor.Value,...
    'FontColor', g.Dropdown.FontColor.Value,...,...
    'FontSize', g.Dropdown.FontSize.Value,...
    'FontName', g.Dropdown.Font.Value);

handles.check_allchans = uicheckbox(...
    'Parent', handles.panel_po,...
    'Position', [10,psh-250,125,20],...
    'Text', 'All Channels',...
    'Value', 1,...
    'FontName', g.Checkbox.Font.Value,...
    'FontSize', g.Checkbox.FontSize.Value,...
    'FontColor', g.Checkbox.FontColor.Value);


handles.list_channels = uilistbox(...
    'Parent', handles.panel_po,...
    'Position', [10,10,125,psh-270],...
    'Enable', 'off',...
    'MultiSelect', 'on',...
    'BackgroundColor', g.Dropdown.BackgroundColor.Value,...
    'FontColor', g.Dropdown.FontColor.Value,...,...
    'FontSize', g.Dropdown.FontSize.Value,...
    'FontName', g.Dropdown.Font.Value);

drawnow;

%************************************************************************
% create menus
%*************************************************************************
handles.menu_file = uimenu('Parent', handles.figure, 'Label', 'File');
handles.menu_loadfile = uimenu('Parent', handles.menu_file, 'Label', 'Load EEG file');

handles.menu_plot = uimenu('Parent', handles.figure, 'Label', 'EEG View');
handles.menu_autoscale = uimenu('Parent', handles.menu_plot, 'Label', 'Auto scale amplitude', 'Checked', true);
handles.menu_stderr = uimenu('Parent', handles.menu_plot, 'Label', 'Show Std Err');
handles.menu_stack = uimenu('Parent', handles.menu_plot, 'Label', 'Stack Channels', 'Checked', true);
handles.menu_fft = uimenu('Parent', handles.menu_plot, 'Label', 'Plot Frequency', 'Checked', false);


handles.menu_cursor = uimenu('Parent', handles.figure,'Label', 'Cursor');
handles.menu_cursoradd = uimenu('Parent', handles.menu_cursor,'Label', 'Add Cursor', 'Tag', 'add', 'Accelerator', 'A');
handles.menu_cursorsub = uimenu('Parent', handles.menu_cursor,'Label', 'Remove Cursor', 'Tag', 'subtract', 'Accelerator', 'X');
handles.menu_cursormean = uimenu('Parent', handles.menu_cursor, 'Label', 'Average between cursors', 'Checked', 'off');

handles.menu_map = uimenu('Parent', handles.figure, 'Label', 'Scalp maps');
handles.menu_mapquality = uimenu('Parent', handles.menu_map, 'Label', 'Print Quality', 'Checked', 'off');
handles.menu_scale = uimenu('Parent', handles.menu_map, 'Label', 'Map Scale Limits');
handles.menu_mapscale(1) = uimenu('Parent', handles.menu_scale, 'Label', 'All maps on the same scale', 'Checked', 'on', 'Tag', 'Auto');
handles.menu_mapscale(2) = uimenu('Parent', handles.menu_scale, 'Label', 'Scale individually', 'Checked', 'off', 'Tag', 'Always');

handles.menu_stats = uimenu('Parent', handles.figure, 'Label', 'Statistics');
handles.menu_dostat = uimenu('Parent', handles.menu_stats, 'Label', 'Show Stats', 'Checked', 'on');
handles.menu_dofdr = uimenu('Parent', handles.menu_stats, 'Label', 'Correct for multiple comparisons', 'Checked', 'on');

%**************************************************************************
%assign callbacks to the uicontrols and menu items
handles.figure.WindowButtonDownFcn = {@callback_handlemouseevents, handles};
handles.figure.WindowButtonUpFcn = {@callback_handlemouseevents, handles};
handles.figure.WindowButtonMotionFcn = {@callback_handlemouseevents, handles};
handles.figure.WindowKeyPressFcn = {@callback_handlekeyevents, handles};

handles.spinner_distance.ValueChangedFcn = {@callback_ploterp, handles};
handles.spinner_mintime.ValueChangedFcn = {@callback_changePlotRange, handles};
handles.spinner_maxtime.ValueChangedFcn = {@callback_changePlotRange, handles};
handles.spinner_minamp.ValueChangedFcn = {@callback_changePlotRange, handles};
handles.spinner_maxamp.ValueChangedFcn = {@callback_changePlotRange, handles};

handles.list_condition.ValueChangedFcn = {@callback_ploterp, handles};
handles.check_allchans.ValueChangedFcn = {@callback_toggleallchannel, handles};
handles.list_channels.ValueChangedFcn = {@callback_ploterp, handles};

handles.menu_loadfile.MenuSelectedFcn  = {@callback_loadNewData, handles};

handles.menu_stderr.MenuSelectedFcn = {@callback_toggleplotoption, handles};
handles.menu_stack.MenuSelectedFcn = {@callback_toggleplotoption, handles};
handles.menu_fft.MenuSelectedFcn = {@callback_togglefftoption, handles};
handles.menu_autoscale.MenuSelectedFcn = {@callback_toggleautoscale, handles};

handles.menu_cursoradd.MenuSelectedFcn = {@callback_managecursors, handles};
handles.menu_cursorsub.MenuSelectedFcn = {@callback_managecursors, handles};
handles.menu_cursormean.MenuSelectedFcn = {@callback_togglemapoption, handles};

handles.menu_mapquality.MenuSelectedFcn = {@callback_togglemapoption, handles};
for ii = 1:2
    handles.menu_mapscale(ii).MenuSelectedFcn = {@callback_toggletopomenustate, handles};
end

handles.menu_dostat.MenuSelectedFcn = {@callback_toggleplotoption, handles};
handles.menu_dofdr.MenuSelectedFcn = {@callback_toggleplotoption, handles};

% ************************************************************************
function c = lineColors()

c = flipud(prism);


