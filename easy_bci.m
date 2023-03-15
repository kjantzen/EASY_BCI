%The description will be here.
%
% KJ Jantzen
%January 2023

function easy_bci()
%main function that loads the parameters
%and builds the UI

    addPaths
    p.handles = buildUI;
    set(p.handles.fig, 'UserData', p);

end
%
function p = initializeParameters(p)
    %call this function whenever some key parameters list below changes

    %hard code these for now, but give the option to select them from a
    %user interface later
        
    p.serialPortName = p.handles.dropdown_port.Value;
    p.bufferDuration = p.handles.dropdown_buffdur.Value;
    p.sampleRate = 500;
    p.handlerName = p.handles.dropdown_handler.Value;
    p.DataHandler = str2func(p.handlerName);

    %create the spiker box object here
    %first delete any existing one that may exist
    if isfield(p, 'Device')
        delete(p.Device);
    end
    
    %select a device based on user input
    try
        p.Device = BNS_HBSpiker(p.serialPortName, p.bufferDuration);
        p.Device.PacketReceivedCallback = p.DataHandler;
    
        %call the initialization version of the data handler, i.e. call it
        %without passing any data.
        p.Device.ProcessObjects = p.DataHandler(p);
        p.ErrorInit = false;
    catch ME
        errorMsg(ME)
        p.ErrorInit = true;
    end
end
%% function to create the simple user interface
function h = buildUI()
    
    load Scheme.mat guiScheme;

    sz = get(0, 'ScreenSize');
    buff_durations = [.01, .025, .1, .25, .5, 1, 1.5, 2,4];
    buff_dur_labels = {'10 ms','25 ms', '100 ms', '250 ms', '500 ms', '1 sec', '1.5 sec', '2 sec', '4 sec'};

    %see if the figure already exists
    %if it does not create it and if it does clear it and start over
    existingFigureHandle = findall(0,'Tag', 'easyBCIController');
     
    if ~isempty(existingFigureHandle) 
        close(existingFigureHandle(1));
    end
    
    h.fig = uifigure;
    h.fig.WindowStyle = 'alwaysontop';
    h.fig.Resize = false;
    h.fig.Position = [0,50,200,sz(4)-70];
    drawnow;
    h.fig.Tag = 'easyBCIController';
    h.fig.Color = guiScheme.BackColor;

    panelHeight = 160;
    ip = h.fig.InnerPosition;
    btm_pos = ip(4) - panelHeight;
    wdth = ip(3);

    h.panel_config = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','CONFIGURE DEVICE', 'FontSize',12,...
        'FontWeight','bold',...
        'BackgroundColor',guiScheme.BackColor,...
        'ForegroundColor',guiScheme.CaptionColor,...
        'BorderType','none');
    
    btm_pos = panelHeight-40;
    uilabel('Parent', h.panel_config,...
        'Position', [10, btm_pos, wdth-20, 20],...
        'Text', 'communications port',...
        'FontSize', 12,...
        'HorizontalAlignment','right');

    btm_pos = btm_pos - 23;
    h.dropdown_port = uidropdown('Parent',h.panel_config,...
        'Position', [5, btm_pos,  wdth-15, 25],...
        'BackgroundColor',guiScheme.ddownbackcolor,...
        'FontColor',guiScheme.TextColor,...
        'Placeholder','serial port',...
        'Items',serialportlist,...
         'DropDownOpeningFcn',@callback_fillPortMenu);
     
    btm_pos = btm_pos - 25;
    uilabel('Parent', h.panel_config,...
        'Position', [10, btm_pos, wdth-20, 20],...
        'Text', 'buffer duration',...
        'FontSize', 12,...
        'HorizontalAlignment','right');

    btm_pos = btm_pos - 23;
    h.dropdown_buffdur = uidropdown('Parent',h.panel_config,...
        'Position', [5, btm_pos,  wdth-15, 25],...
        'BackgroundColor',guiScheme.ddownbackcolor,...
        'FontColor',guiScheme.TextColor,...
        'Placeholder','serial port',...
        'Items',buff_dur_labels,...
        'ItemsData', buff_durations);

    btm_pos = btm_pos - 25;
    uilabel('Parent', h.panel_config,...
        'Position', [10, btm_pos, wdth-20, 20],...
        'Text', 'collection mode',...
        'FontSize', 12,...
        'HorizontalAlignment','right');

    btm_pos = btm_pos - 23;
    h.dropdown_mode = uidropdown('Parent',h.panel_config,...
        'Position', [5, btm_pos,  wdth-15, 25],...
        'BackgroundColor',guiScheme.ddownbackcolor,...
        'FontColor',guiScheme.TextColor,...
        'Placeholder','serial port',...
        'Items',{'continuous', 'single trial'},...
        'ItemsData',[0,1]);
  

      % the handler panel
    panelHeight = 60;
    btm_pos = ip(4) - 240;

    h.panel_handler = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','DATA HANDLER', 'FontSize',12,...
        'FontWeight','bold',...
        'BackgroundColor',guiScheme.BackColor,...
        'ForegroundColor',guiScheme.CaptionColor,...
        'BorderType','none')   ; 
  
    btm_pos = 5;
    h.dropdown_handler = uidropdown('Parent',h.panel_handler,...
        'Position', [5, btm_pos,  wdth-15, 25],...
        'BackgroundColor',guiScheme.ddownbackcolor,...
        'FontColor',guiScheme.TextColor,...
        'Placeholder','serial port',...
        'Items',getHandlerNames);
  
    %the control panel
    panelHeight = 150;
    btm_pos = ip(4) - 420;

    h.panel_control = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','CONTROL', 'FontSize',12,...
        'FontWeight','bold',...
        'BackgroundColor',guiScheme.BackColor,...
        'ForegroundColor',guiScheme.CaptionColor,...
        'BorderType','none');
    
  
    btm_pos = 10;
    h.button_init = uibutton('Parent', h.panel_control,...
        'Position', [10,85,wdth-25,35],...
        'BackgroundColor',guiScheme.BtnColor,...
        'FontColor', guiScheme.TextColor, ...
        'Text','Initialize',...
        'FontSize', guiScheme.BtnFontSize,...
        'ButtonPushedFcn',@callback_initButton);

    h.button_start = uibutton('Parent', h.panel_control,...
        'Position', [10,45,wdth-25,35],...
        'BackgroundColor',guiScheme.BtnColor,...
        'FontColor', guiScheme.TextColor,...
        'Text','Start',...
        'FontSize', guiScheme.BtnFontSize,...
        'Enable', 'off',...
        'ButtonPushedFcn',@callback_startButton);
    
     h.button_stop = uibutton('Parent', h.panel_control,...
        'Position', [10,5,wdth-25,35],...
        'BackgroundColor',guiScheme.BtnColor,...
        'FontColor', guiScheme.TextColor,...
        'Text','Stop',...
        'FontSize', guiScheme.BtnFontSize,...
        'Enable', 'off',...
        'ButtonPushedFcn',@callback_stopButton);

      %the status panel
    panelHeight = 60;
    btm_pos = ip(4) - 510;

    h.panel_status = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','STATUS', 'FontSize',12,...
        'FontWeight','bold',...
        'BackgroundColor',guiScheme.BackColor,...
        'ForegroundColor',guiScheme.CaptionColor,...
        'BorderType','none');
    
    h.collect_status = uilabel('Parent', h.panel_status,...
        'Text', 'No Device Initialized',...
        'FontColor', guiScheme.StatusTxtColor,...
        'FontSize', 14,...
        'Position', [10,0,wdth-25,20],...
        'HorizontalAlignment', 'center',...
        'VerticalAlignment', 'center');

end
function hlist = getHandlerNames()

    [fpath, ~,~] = fileparts(mfilename);
    handlerPath = fullfile(fpath, 'Handlers','*.m');
    handlers = dir(handlerPath);
    if isempty(handlers)
        error('No handlers were found');
    end

    hlist{length(handlers)} = [];
    for ii = 1:length(handlers)
        hlist{ii} = handlers(ii).name(1:end-2);
    end
     
end
%rebuild the serial port menu each time to make sure it has a 
%current list of the available ports
function callback_fillPortMenu(src,~)

    src.Items = serialportlist;

end
%************************************************************************
function callback_initButton(src, ~)
    %get the handle to the figure
    fig = ancestor(src, 'figure', 'toplevel');

    %get the data structure from the figures user data
    p = fig.UserData;
    p = initializeParameters(p); 
    
    if ~p.ErrorInit

        
        p.handles.button_start.Enable = 'on';
    
        %enable the stop button
        p.handles.button_stop.Enable = 'off';
        p.handles.collect_status.Text = 'Ready to Collect';
        p.handles.collect_status.FontColor = [0,.5,0];
    
        %update the display
        drawnow;
    end
    
    %save the data back to the figures user data
    fig.UserData = p;


end
function callback_startButton(src,~)
 
    %get the handle to the figure
    fig = ancestor(src, 'figure', 'toplevel');

    %get the data structure from the figures user data
    p = fig.UserData;

    %disable this button since we are toggling states
    src.Enable = 'off';
    p.handles.button_init.Enable = 'off';


    %turn on acquisition in the Device object
    try
        p.Device.Start();
    catch ME
        errorMsg(ME)
        src.Enable = 'on';
        p.handles.button_init.Enable = 'on';

    end

    %enable the stop button
    p.handles.button_stop.Enable = 'on';
    p.handles.collect_status.Text = 'Collecting...';
    p.handles.collect_status.FontColor = [0,.5,0];

    %update the display
    drawnow;

    
    %save the data back to the figures user data
    fig.UserData = p;

    
end
function callback_stopButton(src,~)
 
    %get a handle to the figure
    fig = ancestor(src, 'figure', 'toplevel');

    %get all the stored data from the figures user data storage
    p = fig.UserData;

    %toggle the state of this button to off
    src.Enable = 'off';

    %turn on the start button
    p.handles.button_start.Enable = 'on';
    p.handles.button_init.Enable = 'on';
    p.handles.collect_status.Text = 'Collection stopped';
    p.handles.collect_status.FontColor = 'r';

    %stop the data collection process
    p.Device.Stop();

    %update the display
    drawnow();
    
    %save the data again
    fig.UserData = p;
    
end
%**************************************************************************
function errorMsg(ME)
  
    opts.WindowStyle = 'modal';
    opts.Interpreter = 'tex';
    msg = ['\fontsize{14} ', ME.message];
    msg = strrep(msg, '_', "\_");
    errordlg(msg, ME.identifier, opts);

end
%%
function addPaths()

 thisPath = mfilename('fullpath');
 indx = strfind(thisPath, filesep);
 thisPath = thisPath(1:max(indx)-1);
 
 newFolder{1}  = fullfile(thisPath, 'Extensions');
 newFolder{2}  = fullfile(thisPath, 'Handlers');
 newFolder{3}  = fullfile(thisPath, "Devices");
 
 
 pathCell = strsplit(path, pathsep);
 for ii = 1:length(newFolder)
     if ispc  % Windows is not case-sensitive
      onPath = any(strcmpi(newFolder{ii}, pathCell));
    else
      onPath = any(strcmp(newFolder{ii}, pathCell));
     end
    if ~onPath
        addpath(newFolder{ii})
    end
 end
 

end
%%
function makeNewDataHandlerFromTemplate(scriptName)

scriptFileName = sprintf('%s.m', scriptName);

homePath = mfilename("fullpath");
[homePath,~,~] = fileparts(homePath);
newFile = fullfile(homePath, 'Handlers', scriptFileName);
if ~isempty(dir(newFile))
    msgbox(sprintf('The handler file %s already exists.\n Please choose a different name.', scriptName));
    return
end
fid = fopen(newFile, 'wt');
  

fprintf(fid, '%%Generic data handler template\n\n');
fprintf(fid, 'function outStruct = %s(inStruct, varargin)\n', scriptName);
fprintf(fid, '\tif nargin == 1\n');
fprintf(fid, '\t\toutStruct = initialize(inStruct);\n');
fprintf(fid, '\telse\n\t\toutStruct = analyze(inStruct, varargin{1}, varargin{2});\n\tend\nend\n');
fprintf(fid, '%%this function gets called when data is passed to the handler\n');
fprintf(fid, 'function p = analyze(p,data, event)\n\n\t%%your analysis code goes here\nend\n\n');
fprintf(fid, '%%this function gets called when the analyse process is initialized\n');
fprintf(fid, 'function p = initialize(p)\n\n%%your initialization code goes here\n\nend\n');

fclose(fid);
edit(newFile);

end
%%
function  callback_port_menu(src, evt)
    fig = ancestor(src, 'figure', 'toplevel');

    %get all the stored data from the figures user data storage
    p = fig.UserData;

    for ii = 1:length(p.handles.port_option)
        p.handles.port_option(ii).Checked = 'off';
    end
    src.Checked = 'on';

    if isfield(p, 'Device') && p.Device.Collecting
        callback_stopButton(src, evt);
        p.handles.button_start.Enable = 'off';
    end


end
%%
function  callback_buffer_menu(src, evt)
    fig = ancestor(src, 'figure', 'toplevel');

    %get all the stored data from the figures user data storage
    p = fig.UserData;

    for ii = 1:length(p.handles.chunk_option)
        p.handles.chunk_option(ii).Checked = 'off';
    end
    src.Checked = 'on';

    if isfield(p, 'Device') && p.Device.Collecting
        callback_stopButton(src, evt);
        p.handles.button_start.Enable = 'off';
    end


end
%%
function callback_newHandlerFile(~, ~)
    scriptName  = inputdlg('Provde a unique name for the new data handler', 'New Handler');
    if ~isempty(scriptName{1})
        makeNewDataHandlerFromTemplate(scriptName{1});
    end    
end
%%
function callback_loadHandler(src,~)

    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;
    hname = loadHandler(p);
    if ~isempty(hname)
        p.handlerName = hname;
    end
    fig.UserData = p;

end

%*********************************************************************
%used to keep keep the main window always on top
function setaot(figHandle)

    drawnow nocallbacks

    %suppres warnings related to java frames and exposing the hidden object
    %properties
    warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
    warning('off', 'MATLAB:structOnObject');      
    
    figProps = struct(figHandle);
    controller = figProps.Controller;      % Controller is a private hidden property of Figure
    controllerProps = struct(controller);
    container = struct(controllerProps.PlatformHost);  % Container is a private hidden property of FigureController
    win = container.CEF;   % CEF is a regular (public) hidden property of FigureContainer
    win.setAlwaysOnTop(true);
    
end

