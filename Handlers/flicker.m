% Example of an SSVEP easy_bci data handler
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
% obj   -> the calling object which shuld be the device driver
% p     -> a structure containing all the objects and variables created in the
%           initialize function.  Also includes all the data handles and
%           information from the eay_bci interface
% data  ->  is a data packet, teh format of which depends on the collection
%           mode.
%
% this example requires that easy_bci be used in continuous mode

% global variables are bad, but this is the only way I have found to
% effectively communicate the state variable to overlapping calls to the
% callback function.  Returning state as a variable does not work because
% subsequent calls will already be made before the state variable is
% returned.
global stim_state

%close the psychtoolbox window if a key is pressed.
[keyIsDown, ~, keyCode] = KbCheck;
keyCode = find(keyCode, 1);

if keyIsDown && keyCode==p.EscapeKey
    stop_ssvep(p)
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
port = "/dev/tty.usbmodem1123401";
waitfortrigger = true;

%use Pyschotoolbox to get the window size
%because builtin MATLAB funcitons can be wildly innacurate
[w,h] = Screen('WindowSize', 0);
sz = [1,1,w,h];

%clear any existing Screen buffers
Screen('closeall');

% create a flicker object the entire size of the screen
%p.flicker = BCI_Flicker(WindowPosition=sz, TargetSize=[350,350],ScreenNumber=0);
p.flicker = BCI_Flicker('WindowPosition', [200,0,500,500], 'TargetSize', [50,50],'ScreenNumber',0,'TriggerPort',port, 'TriggerValue', 1);

%create the trial buffer object
p.buffer = BCI_TrialBuffer(Duration=p.TrialDuration, WaitForTrigger=waitfortrigger,TriggerValue=1);

%create the canonical correlation analysis object with most of the defaults
%except the trial duration
p.cca = BCI_CCA("SampleDuration",p.TrialDuration);

%get the number of the escape key
KbName('UnifyKeyNames');
p.EscapeKey = KbName('ESCAPE');

%initialize the variable for timing the interval between trials
p.timerStart = uint64(0);

%start the device ourselves because the user will not be able to access the
%easy_bci interface when the Psychtoolbox screen takes over
p = start_ssvep(p);

end
% *************************************************************************
function p = start_ssvep(p)
 %get the handle to the figure
    
    %change the state of the buttons on the interface
    p.handles.button_init.Enable = 'off';
    p.handles.button_start.Enable = 'off';
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
        p = stop_ssvep(p);
        error('Something went wrong');
    end

   %this is a clunky way of overriding the easy_bci updating of the button
   %state.  A more elegent solution will be forthcoming when I have time
   p.ErrorInit = true;
   
end
% *************************************************************************
function p = stop_ssvep(p)

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