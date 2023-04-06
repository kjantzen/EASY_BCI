% Example of a basic easy bci data handler 
function outStruct = flicker(inStruct, varargin)
	if nargin == 1
		outStruct = initialize(inStruct);
	else
		outStruct = analyze(inStruct, varargin{1}, varargin{2});
	end
end
% **************************************************************************
% this function gets called when data is passed to the handler
function p = analyze(obj, p, data)
% obj is the calling object which shuld be the device driver
% p is a structure containing all the objects and variables created in the
%   initialize funciton
% data is a data packet
%

%global variables are bad, but this is the only way I have found to save
%changes in state and have them take effect immediately
global stim_state

%close the psychtoolbox window if a key is pressed.
[keyIsDown, ~, keyCode] = KbCheck;
keyCode = find(keyCode, 1);

if keyIsDown && keyCode==p.EscapeKey
    shut_it_down(p)
end

switch stim_state
    case 0
        % play the stimulus
        % note that execution is blocked for p.TrialDuration seconds
        stim_state = 1;
        p.flicker.Play(p.TrialDuration);
    case 1
        %add data to the buffer
        %note that although this only gets executed after the stimulus has
        %completed, it is really processing a backlog of calls to this
        %function that occured during blocking so the data is from during
        %the stimulus.
        p.buffer.AddPacket(data);
        if p.buffer.HasCompleteTrial
            p.lastTrial = p.buffer.ReadTrial;
            p.cca.XData = p.lastTrial(1,:);
            p.timerStart = tic;           
            stim_state = 2;
        end
    case 2
        %provide feedback about which frequency the CCA thinks teh
        %participant viewed.  This may require a mapping between stimulus
        %position and frequency number.
        stim_state = 3;
        p.flicker.PlayFeedback(p.cca.FrequencyCategory, .5);      
    case 3
        %once the data has been analyzed, wait for 2 seconds before the
        %next stimulus
        if toc(p.timerStart) > 2
            stim_state = 0;
        end
end
end
% **************************************************************************
% this function gets called when the analyse process is initialized
function p = initialize(p)
global stim_state;

stim_state = 0;

%2 seconds of data can produced categorization accruacy of around 80%
p.TrialDuration = 2;
port = '/dev/tty.blahblah';
waitfortrigger = false;

% create a flicker object
%will need to specify the trigger port in future
sz = get(groot, 'ScreenSize');
p.flicker = BCI_Flicker(WindowPosition=sz, TargetSize=[150,150],ScreenNumber=0);
%p.flicker = BCI_Flicker(WindowPosition=[200,0,500,500], TargetSize=[50,50],ScreenNumber=0);
%p.flicker = BCI_Flicker(WindowPosition=[200,0,500,500], TargetSize=[50,50],ScreenNumber=0,TriggerPort=port);

%create the trial buffer object
p.buffer = BCI_TrialBuffer(Duration=p.TrialDuration, WaitForTrigger=waitfortrigger,TriggerValue=1);

%create the canonical correlation analysis object with most of the defaults
%except the trial duration
p.cca = BCI_CCA("SampleDuration",p.TrialDuration);

%get the number of the escape key
p.EscapeKey = KbName('ESCAPE');

%some flags to keep track of stuff
p.timerStart = uint64(0);

p = start_it_up(p);

end
% *************************************************************************
function p = start_it_up(p)
 %get the handle to the figure
    
    p.handles.button_init.Enable = 'off';
    p.handles.button_start.Enable = 'off';
   
    %enable the stop button
    p.handles.button_stop.Enable = 'on';
    p.handles.collect_status.Text = 'Collecting...';
    p.handles.collect_status.FontColor = [0,.5,0];

    %update the display
    drawnow;
    %turn on acquisition in the Device object
    try
        p.Device.Start();
    catch ME
        p.handles.button_init.Enable = 'on';
        p = shut_it_down(p);
        error('Something went wrong');
    end

   p.ErrorInit = true;
   

end
% *************************************************************************
function p = shut_it_down(p)
    p.handles.button_init.Enable = 'on';
    p.handles.button_start.Enable = 'on';
      p.handles.button_stop.Enable = 'off';
   

    %turn on acquisition in the Device object
    try
        p.Device.Stop();
        p.flicker.Close;

    catch ME
        error('Something went wrong');
    end
    drawnow;
   
end    