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
        
    for ii = 1:length(p.handles.port_option)
        if p.handles.port_option(ii).Checked
            p.serialPortName = p.handles.port_option(ii).Text;
            break
        end
    end

     for ii = 1:length(p.handles.chunk_option)
        if p.handles.chunk_option(ii).Checked
            p.bufferDuration = str2double(p.handles.chunk_option(ii).Text);
            break
        end
    end

    p.sampleRate = 500;

    %also hard code the two functions for initializing the data processing
    %and for handling the data stream.  These also could be selectable
    %using the interface
    if ~isfield(p, 'handlerName') || isempty(p.handlerName)
        p.handlerName = loadHandler(p);
    end
    if isempty(p.handlerName)
        msgbox('No valid handler file was identified');
        return;
    end
    p.DataHandler = str2func(p.handlerName);

    %create the spiker box object here
    %first delete any existing one that may exist
    if isfield(p, 'Device')
        delete(p.Device);
    end
    
    %select a device based on user input
    p.Device = BNS_HBSpiker(p.serialPortName, p.bufferDuration);
    p.Device.PacketReceivedCallback = p.DataHandler;
    %p.Device = HBSpiker_ERP(p.serialPortName, p.DataHandler);
    
    %call the initialization version of the data handler, i.e. call it
    %without passing any data.
    p.Device.ProcessObjects = p.DataHandler(p);
     


end
%% function to create the simple user interface
function h = buildUI()
    
    colorScheme.BackColor = '#d5dbdb';
    colorScheme.BtnColor = '#b4c8c8' ;
    colorScheme.ddownbackcolor = colorScheme.BackColor;
    colorScheme.TextColor = '#222222';
    colorScheme.CaptionColor = '#333355';
    colorScheme.StatusTxtColor = '#506e6e';

    sz = get(0, 'ScreenSize');
    ports = serialportlist;
    buff_durations = [.01, .2, .25, .5, .75, 1, 1.5, 2];

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
    h.fig.Color = colorScheme.BackColor;

    panelHeight = 160;
    ip = h.fig.InnerPosition;
    btm_pos = ip(4) - panelHeight;
    wdth = ip(3);

    h.panel_config = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','CONFIGURE DEVICE', 'FontSize',12,...
        'FontWeight','bold',...
        'BackgroundColor',colorScheme.BackColor,...
        'ForegroundColor',colorScheme.CaptionColor,...
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
        'BackgroundColor',colorScheme.ddownbackcolor,...
        'FontColor',colorScheme.TextColor,...
        'Placeholder','serial port',...
        'Items',serialportlist);
     
    btm_pos = btm_pos - 25;
    uilabel('Parent', h.panel_config,...
        'Position', [10, btm_pos, wdth-20, 20],...
        'Text', 'buffer duration',...
        'FontSize', 12,...
        'HorizontalAlignment','right');

    btm_pos = btm_pos - 23;
    h.dropdown_buffdur = uidropdown('Parent',h.panel_config,...
        'Position', [5, btm_pos,  wdth-15, 25],...
        'BackgroundColor',colorScheme.ddownbackcolor,...
        'FontColor',colorScheme.TextColor,...
        'Placeholder','serial port',...
        'Items',{'10 ms','25 ms', '100 ms', '250 ms', '500 ms', '1 sec', '1.5 sec', '2 sec', '4 sec'});

    btm_pos = btm_pos - 25;
    uilabel('Parent', h.panel_config,...
        'Position', [10, btm_pos, wdth-20, 20],...
        'Text', 'collection mode',...
        'FontSize', 12,...
        'HorizontalAlignment','right');

    btm_pos = btm_pos - 23;
    h.dropdown_mode = uidropdown('Parent',h.panel_config,...
        'Position', [5, btm_pos,  wdth-15, 25],...
        'BackgroundColor',colorScheme.ddownbackcolor,...
        'FontColor',colorScheme.TextColor,...
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
        'BackgroundColor',colorScheme.BackColor,...
        'ForegroundColor',colorScheme.CaptionColor,...
        'BorderType','none')   ; 
  
    btm_pos = 5;
    h.dropdown_handler = uidropdown('Parent',h.panel_handler,...
        'Position', [5, btm_pos,  wdth-15, 25],...
        'BackgroundColor',colorScheme.ddownbackcolor,...
        'FontColor',colorScheme.TextColor,...
        'Placeholder','serial port',...
        'Items',getHandlerNames);
  
    %the control panel
    panelHeight = 150;
    btm_pos = ip(4) - 420;

    h.panel_control = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','CONTROL', 'FontSize',12,...
        'FontWeight','bold',...
        'BackgroundColor',colorScheme.BackColor,...
        'ForegroundColor',colorScheme.CaptionColor,...
        'BorderType','none');
    
  
    btm_pos = 10;
    h.button_init = uibutton('Parent', h.panel_control,...
        'Position', [10,85,wdth-25,35],...
        'BackgroundColor',colorScheme.BtnColor,...
        'FontColor', colorScheme.TextColor, ...
        'Text','Initialize',...
        'ButtonPushedFcn',@callback_initButton);

    h.button_start = uibutton('Parent', h.panel_control,...
        'Position', [10,45,wdth-25,35],...
        'BackgroundColor',colorScheme.BtnColor,...
        'FontColor', colorScheme.TextColor,...
        'Text','Start',...
        'Enable', 'off',...
        'ButtonPushedFcn',@callback_startButton);
    
     h.button_stop = uibutton('Parent', h.panel_control,...
        'Position', [10,5,wdth-25,35],...
        'BackgroundColor',colorScheme.BtnColor,...
        'FontColor', colorScheme.TextColor,...
        'Text','Stop',...
        'Enable', 'off',...
        'ButtonPushedFcn',@callback_stopButton);

      %the status panel
    panelHeight = 60;
    btm_pos = ip(4) - 510;

    h.panel_status = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','STATUS', 'FontSize',12,...
        'FontWeight','bold',...
        'BackgroundColor',colorScheme.BackColor,...
        'ForegroundColor',colorScheme.CaptionColor,...
        'BorderType','none');
    
    h.collect_status = uilabel('Parent', h.panel_status,...
        'Text', 'No Device Initialized',...
        'FontColor', colorScheme.StatusTxtColor,...
        'FontSize', 14,...
        'Position', [10,0,wdth-25,20],...
        'HorizontalAlignment', 'center',...
        'VerticalAlignment', 'center');

    return

    h.menu_config = uimenu('Parent',h.fig,'Text','Configure');
    h.menu_port = uimenu('Parent', h.menu_config, 'Text', 'Port', 'Callback', @callback_fillPortMenu);
    for ii = 1:length(ports)
        h.port_option(ii) = uimenu('Parent', h.menu_port, ...
            'Text', ports(ii), ...
            'Callback', @callback_port_menu);
        if ii == 1
            h.port_option.Checked = 'on';
        end
    end

    h.menu_chunk = uimenu('Parent', h.menu_config, 'Text', 'Buffer Length');
    for ii = 1:length(buff_durations)
        h.chunk_option(ii) = uimenu('Parent', h.menu_chunk, ...
            'Text', num2str(buff_durations(ii)), ...
            'Callback', @callback_buffer_menu);
        if ii == 3
            h.chunk_option(ii).Checked = 'on';
        end
    end

  h.menu_handler = uimenu('Parent', h.fig, 'Text', 'Handler');
  h.menu_loadhandler = uimenu('Parent', h.menu_handler, 'Text', 'Load', 'Callback', @callback_loadHandler);
  h.menu_newhandler = uimenu('Parent', h.menu_handler, 'Text', 'New','Callback', @callback_newHandlerFile);
  
   
    %panel for the current acquisition status
    h.panel_status = uipanel('Parent', h.fig, ...
        'Title', 'Status',...
        'Units', 'pixels',...
        'Position', [135,70,150,40]);
    
    h.collect_status = uilabel('Parent', h.panel_status,...
        'Text', 'Collection Stopped',...
        'FontColor', 'r',...
        'Position', [0,0,150,20],...
        'HorizontalAlignment', 'center',...
        'VerticalAlignment', 'center');
  
   h.panel_handler = uipanel('Parent', h.fig, ...
        'Title', 'Handler',...
        'Units', 'pixels',...
        'Position', [135,10,150,40]);
    
    h.label_handler = uilabel('Parent', h.panel_handler,...
        'Text', 'No Handler loaded',...
        'FontColor', 'b',...
        'Position', [0,0,150,20],...
        'HorizontalAlignment', 'center',...
        'VerticalAlignment', 'center');


    h.button_init = uibutton('Parent', h.fig,...
        'Position', [10,80,120,30],...
        'BackgroundColor',[.1,.1,.8],...
        'FontColor', 'w', ...
        'Text','Initialize',...
        'ButtonPushedFcn',@callback_initButton);

    h.button_start = uibutton('Parent', h.fig,...
        'Position', [10,45,120,30],...
        'BackgroundColor',[.1,.8,.1],...
        'Text','Start',...
        'Enable', 'off',...
        'ButtonPushedFcn',@callback_startButton);
    
     h.button_stop = uibutton('Parent', h.fig,...
        'Position', [10,10,120,30],...
        'BackgroundColor',[.8,.1,.1],...
        'FontColor', 'w',...
        'Text','Stop',...
        'Enable', 'off',...
        'ButtonPushedFcn',@callback_stopButton);

   
  %  setaot(h.fig);


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

    %get all the stored data from the figures user data storage
    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;
    cp = 1;
    cport = "";
    %erase all existing menu items
    %p.handles.port_option = [];
    for ii = 1:length(p.handles.port_option)
        if p.handles.port_option(ii).Checked
            cport = p.handles.port_option(ii).Text;
            cp = ii;
        end
    end

    delete(p.handles.port_option);
    p.handles = rmfield(p.handles, 'port_option');

    ports = serialportlist;
    %get the index of the currentPort
    if (cp>0)
        cp = find(ismember(ports, cport));
        if (cp == 0)
            cp = 1;
        end
    end
  
    for ii = 1:length(ports)
        p.handles.port_option(ii) = uimenu('Parent', p.handles.menu_port, ...
            'Text', ports(ii), ...
            'Callback', @callback_port_menu);
        if ii == cp
            p.handles.port_option(ii).Checked = 'on';
        end
    end

    fig.UserData = p;

end
%************************************************************************
function callback_initButton(src, ~)
    %get the handle to the figure
    fig = ancestor(src, 'figure', 'toplevel');

    %get the data structure from the figures user data
    p = fig.UserData;
    p = initializeParameters(p);  
    
    p.handles.button_start.Enable = 'on';

    %enable the stop button
    p.handles.button_stop.Enable = 'off';
    p.handles.collect_status.Text = 'Ready to Collect';
    p.handles.collect_status.FontColor = [0,.5,0];

    %update the display
    drawnow;

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

    %enable the stop button
    p.handles.button_stop.Enable = 'on';
    p.handles.collect_status.Text = 'Collecting...';
    p.handles.collect_status.FontColor = [0,.5,0];

    %update the display
    drawnow;

    %turn on acquisition in the Device object
    p.Device.Start();

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

%load a handler used to tell the device how to work with the data stream
function handlerName = loadHandler(p)


    thisPath = mfilename('fullpath');
    indx = strfind(thisPath, filesep);
    thisPath = thisPath(1:max(indx)-1); 
    handlerPath = fullfile(thisPath, 'Handlers');
    fileFilter = fullfile(handlerPath, '*.m');


    [handlerName, hpath,~] = uigetfile(fileFilter, 'Select a Handler file');
    
    if isequal(handlerName, 0) || isempty(dir(fullfile(hpath, handlerName)))
        p.handles.label_handler.Text = 'No Hander loaded';
        handlerName = [];
    else
        [~, f, ~] = fileparts(handlerName);
        handlerName = f;
      %  handlerName = fullfile(hpath, handlerName);
        p.handles.label_handler.Text = f;
    end
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

