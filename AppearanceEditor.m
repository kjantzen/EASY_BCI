% APPEARANCEEDITOR - provides an interface for editing the scheme of the
% plotter interface
function AppearanceEditor(options)

arguments
    options.DefaultScheme (1,1) {mustBeNumericOrLogical} = false
end

p = loadScheme(options.DefaultScheme);
h = buildGUI(p);
setParameters(h,p);
saveUserData(h.fig, h, p);

end
%% Callback functions
% ************************************************************************
function callback_ChangeColor(src, evt, fig)

    [h,p] = readUserData(fig);
    fields = src.UserData;
    currColor = p.(fields{1}).(fields{2}).Value;
    txt = sprintf('Select a new %s color for %s', fields{2}, fields{1});
    newColor = uisetcolor(currColor,txt);

    src.BackgroundColor = newColor;
    p.(fields{1}).(fields{2}).Value = newColor;
    setParameters(h,p);
    saveUserData(fig, h, p);
  
end
% ************************************************************************
function callback_ChangeFontOrSize(src, evt, fig)

    [h,p] = readUserData(fig);
    fields = src.UserData;
    var = src.Value;
    p.(fields{1}).(fields{2}).Value = var;
    setParameters(h,p);
    saveUserData(fig, h, p);
  
end
% ************************************************************************
function callback_Cancel(~,~,f)
    close(f);
end
% ************************************************************************
function callback_Defaults(~,~,f)
    [h,p] = readUserData(f);
    p = InitializeParameters;
    setParameters(h,p);
    saveUserData(f,h,p);
    AppearanceEditor
end
% ************************************************************************
function callback_SaveScheme(~,~,f)
    [h,p] = readUserData(f);
    schemeFile = schemeFileName();
    save(schemeFile, '-struct','p', '-mat');
    close(f);
end
%% Helper functions
% ************************************************************************
function [h,p] = readUserData(f)
    v = f.UserData;
    h = v{1}; p = v{2};
end
% ************************************************************************
function saveUserData(f,h,p)
    f.UserData = {h,p};
end
% ************************************************************************
function p = loadScheme(useDefault)
    
    schemeFile = schemeFileName();
 
    if useDefault
        p = InitializeParameters;
    else
        if ~isfile(schemeFile)
            warning('Could not find teh scheme file in the editor folder.  Resorting to defaults!');
            p = InitializeParameters;
        else
            p = load(schemeFile);
        end
    end
end
% ************************************************************************
function f = schemeFileName()
    cp = mfilename('fullpath');
    [cp,~,~] = fileparts(cp);
    f = fullfile(cp, 'Scheme.mat');
end
%% GUI Function
% ************************************************************************
function setParameters(h,p)

    %the window bit
    h.dispWindow.BackgroundColor = p.Window.BackgroundColor.Value;

    %the axis
    h.dispAxis.FontSize = p.Axis.FontSize.Value;
    h.dispAxis.FontName = p.Axis.Font.Value;
    h.dispAxis.Color = p.Axis.BackgroundColor.Value;
    h.dispAxis.XColor = p.Axis.AxisColor.Value;
    h.dispAxis.YColor = p.Axis.AxisColor.Value;

    %the panel
    h.dispPanel.BackgroundColor = p.Panel.BackgroundColor.Value;
    h.dispPanel.HighlightColor = p.Panel.BorderColor.Value;
    h.dispPanel.FontName = p.Panel.Font.Value;
    h.dispPanel.FontSize = p.Panel.FontSize.Value;
    h.dispPanel.ForegroundColor = p.Panel.FontColor.Value;
    
    %the button
    h.dispButton.BackgroundColor = p.Button.BackgroundColor.Value;
    h.dispButton.FontName = p.Button.Font.Value;
    h.dispButton.FontSize = p.Button.FontSize.Value;
    h.dispButton.Position(4) = p.Button.Height.Value;
    h.dispButton.FontColor = p.Button.FontColor.Value;

    %the label
    h.dispLabel.FontColor = p.Label.FontColor.Value;
    h.dispLabel.FontName = p.Label.Font.Value;
    h.dispLabel.FontSize = p.Label.FontSize.Value;

    %the checkbox
    h.dispCheckbox.FontName = p.Checkbox.Font.Value;
    h.dispCheckbox.FontSize = p.Checkbox.FontSize.Value;
    h.dispCheckbox.FontColor = p.Checkbox.FontColor.Value;

    %the dropdown
    h.dispDropdown.BackgroundColor = p.Dropdown.BackgroundColor.Value;
    h.dispDropdown.FontName = p.Dropdown.Font.Value;
    h.dispDropdown.FontSize = p.Dropdown.FontSize.Value;
    h.dispDropdown.FontColor = p.Dropdown.FontColor.Value;
    h.dispDropdown.Position(4) = p.Dropdown.Height.Value;

    %the edit field
    h.dispEdit.BackgroundColor = p.Edit.BackgroundColor.Value;
    h.dispEdit.FontName = p.Edit.Font.Value;
    h.dispEdit.FontSize = p.Edit.FontSize.Value;
    h.dispEdit.FontColor = p.Edit.FontColor.Value;
    h.dispEdit.Position(4) = p.Edit.Height.Value;

    

end
% ************************************************************************
function h = buildGUI(p)
fonts = listfonts;

eh = findall(groot, 'Type', 'figure');
for ii = 1:length(eh)
    if strcmp(eh(ii).Tag, 'Appearance Editor')
        delete(eh(ii))
        break;
    end
end

h.fig = uifigure('Position', [100,100,700,550]);
h.fig.Tag = 'Appearance Editor';

grid = uigridlayout('Parent', h.fig);
grid.RowHeight = {'1x', 25};
grid.ColumnWidth = {240,'1x', 80,80,80};

ePanel = uipanel('Parent', grid,'Title','Edit Properites');
ePanel.Scrollable = 'on';

drawnow;
pause(1)

%% draw the controls for changing parameters
controls = fieldnames(p);
bottom = 10;
left = ePanel.InnerPosition(3)-100;
for cc = length(controls):-1:1

    props = fieldnames(p.(controls{cc}));
    for pp = length(props):-1:1
        uilabel('Parent', ePanel,'Text', props{pp},...
            'Position', [30,bottom,100,25]);

        sprintf('control: %s, property: $s\n', controls{cc}, props{pp});
        switch p.(controls{cc}).(props{pp}).Type
            case 'Color'
                uibutton('Parent', ePanel, 'BackgroundColor',p.(controls{cc}).(props{pp}).Value,...
                    'Position', [left, bottom, 80,20], 'Text','',...
                    'UserData', {controls{cc}, props{pp}}, ...
                    'ButtonPushedFcn', {@callback_ChangeColor, h.fig});
            case 'Font'
                uidropdown('Parent', ePanel, 'Items',fonts,'Value',...
                    p.(controls{cc}).(props{pp}).Value,...
                    'Position',[left-20, bottom, 100,20],...
                    'UserData', {controls{cc}, props{pp}}, ...
                    'ValueChangedFcn',{@callback_ChangeFontOrSize, h.fig});
            case 'Integer'
                uispinner('Parent',ePanel, 'Step',1,'Limits',[8,100],...
                    'Value',p.(controls{cc}).(props{pp}).Value,...
                    'Position',[left, bottom, 80,20],...
                    'RoundFractionalValues','on',...
                    'UserData', {controls{cc}, props{pp}}, ...
                    'ValueChangedFcn',{@callback_ChangeFontOrSize, h.fig});
        end

        bottom = bottom + 30;

    end

    uilabel('Parent', ePanel, ...
        'Text', upper(controls{cc}),...
        'Position', [10, bottom, 100, 25]);
    bottom = bottom + 30;
end
%% draw the controls for displaying the current parameters
    h.dispWindow = uipanel('Parent',grid,'Title','WiNDOW');
    h.dispWindow.Layout.Column = [2,5];
    h.dispWindow.Layout.Row = 1;
    drawnow;
    pause(1);
    pos = h.dispWindow.InnerPosition;
    h.dispAxis = uiaxes('Parent', h.dispWindow,'Position', [0, pos(4)-230, pos(3), 220]);
    h.dispPanel = uipanel('Parent',h.dispWindow,'Title','PANEL',...
        'Position',[10,10,pos(3)-20,200]);
    h.dispLabel = uilabel('Parent', h.dispPanel, 'Position',[30,120, 100, 20], ...
        'Text', 'Label Text');
    h.dispDropdown = uidropdown('Parent', h.dispPanel, 'Position', [180, 120, 120, 20],...
        'Items',{'Dropdown Option 1', 'Dropdown Option 2'});
    h.dispCheckbox = uicheckbox('Parent', h.dispPanel, 'Position',[30,60, 150, 20], ...
          'Text','Checkbox Control');
    h.dispButton = uibutton('Parent', h.dispPanel, 'Position',[180,60, 120, 30], ...
          'Text','Button Control');
    h.dispEdit = uieditfield('Parent', h.dispPanel, 'Position', [50, 10, 200, 30],...
        'Value', 'Sample edit field text.');
    
   %add the controls
   h.buttonCancel = uibutton('Parent', grid, 'Text', 'Cancel', ...
       'ButtonPushedFcn',{@callback_Cancel, h.fig});
   h.buttonCancel.Layout.Row = 2;
   h.buttonCancel.Layout.Column = 3;

   h.buttonAccept = uibutton('Parent', grid, 'Text', 'Defaults',...
       'ButtonPushedFcn',{@callback_Defaults, h.fig});
   h.buttonAccept.Layout.Row = 2;
   h.buttonAccept.Layout.Column = 4;
   
   h.buttonAccept = uibutton('Parent', grid, 'Text', 'Accept',...
       'ButtonPushedFcn',{@callback_SaveScheme, h.fig});
   h.buttonAccept.Layout.Row = 2;
   h.buttonAccept.Layout.Column = 5;
   


end
% ************************************************************************
function p = InitializeParameters()
% in case the file is not found on disk, this will provide some defaults

p.Axis.AxisColor.Value = [0,0,0]; p.Axis.AxisColor.Type = 'Color';
p.Axis.BackgroundColor.Value = [1,1,1]; p.Axis.BackgroundColor.Type = 'Color';
p.Axis.Font.Value = 'Helvetica'; p.Axis.Font.Type = 'Font';
p.Axis.FontSize.Value = 14; p.Axis.FontSize.Type = 'Integer';

p.Dropdown.BackgroundColor.Value = [1,1,1];p.Dropdown.BackgroundColor.Type = 'Color';
p.Dropdown.Font.Value = 'Helvetica';p.Dropdown.Font.Type = 'Font';
p.Dropdown.FontSize.Value  = 11;p.Dropdown.FontSize.Type  = 'Integer';
p.Dropdown.FontColor.Value = [0,0,0];p.Dropdown.FontColor.Type = 'Color';
p.Dropdown.Height.Value = 25;p.Dropdown.Height.Type = 'Integer';

p.Button.BackgroundColor.Value = [.8,.8,.8]; p.Button.BackgroundColor.Type = 'Color';
p.Button.Font.Value = 'Helvetica'; p.Button.Font.Type = 'Font';
p.Button.FontColor.Value = [0,0,0];p.Button.FontColor.Type = 'Color';
p.Button.FontSize.Value = 11; p.Button.FontSize.Type = 'Integer';
p.Button.Height.Value = 30; p.Button.Height.Type = 'Integer';

p.Panel.BackgroundColor.Value = [.95,.95,.95]; p.Panel.BackgroundColor.Type = 'Color';
p.Panel.BorderColor.Value = [0,0,0]; p.Panel.BorderColor.Type = 'Color';
p.Panel.Font.Value = 'Helvetica'; p.Panel.Font.Type = 'Font';
p.Panel.FontSize.Value = 11; p.Panel.FontSize.Type = 'Integer';
p.Panel.FontColor.Value = [1,1,1]; p.Panel.FontColor.Type = 'Color';

p.Edit.BackgroundColor.Value = [.95,.95,.95]; p.Edit.BackgroundColor.Type = 'Color';
p.Edit.Font.Value = 'Helvetica'; p.Edit.Font.Type = 'Font';
p.Edit.FontSize.Value = 11; p.Edit.FontSize.Type = 'Integer';
p.Edit.FontColor.Value = [0,0,0]; p.Edit.FontColor.Type = 'Color';
p.Edit.Height.Value = 30; p.Edit.Height.Type = 'Integer';

p.Checkbox.FontColor.Value = [0,0,0]; p.Checkbox.FontColor.Type = 'Color';
p.Checkbox.Font.Value = 'Helvetica'; p.Checkbox.Font.Type = 'Font';
p.Checkbox.FontSize.Value = 11; p.Checkbox.FontSize.Type = 'Integer';

p.Label.FontColor.Value = [0,0,0]; p.Label.FontColor.Type = 'Color';
p.Label.Font.Value = 'Helvetica'; p.Label.Font.Type = 'Font';
p.Label.FontSize.Value = 11; p.Label.FontSize.Type = 'Integer';

p.Window.BackgroundColor.Value = [.95,.95,.95]; p.Window.BackgroundColor.Type = 'Color';

end