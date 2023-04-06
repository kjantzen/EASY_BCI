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
global state

switch state
    case 0
        % play the stimulus
        % note that execution is blocked for p.TrialDuration seconds
        state = 1;
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
            fprintf('Got a trial\n');
            state = 2;
            p.acc.XData = p.lastTrial;
            fprintf(p.acc.FrequencyCondition);
            p.timerStart = tic;           
        end
    case 2
        %provide feedback about which frequency the CCA thinks teh
        %participant viewed.  This may require a mapping between stimulus
        %position and frequency number.
        state = 3;
        p.flicker.PlayFeedback(p.acc.FrequencyCondition, .5);      
    case 3
        %once the data has been analyzed, wait for 2 seconds before the
        %next stimulus
        if toc(p.timerStart) > 2
            state = 0;
        end
end
end
% **************************************************************************
% this function gets called when the analyse process is initialized
function p = initialize(p)
global state;

state = 0;
p.TrialDuration = 2;
port = '/dev/tty.blahblah';
% create a flicker object
%will need to specify the trigger port in future
p.flicker = BCI_Flicker(WindowPosition=[200,0,500,500], TargetSize=[50,50],ScreenNumber=0);
%p.flicker = BCI_Flicker(WindowPosition=[200,0,500,500], TargetSize=[50,50],ScreenNumber=0,TriggerPort=port);

%create the trial buffer object
p.buffer = BCI_TrialBuffer(Duration=p.TrialDuration, WaitForTrigger=false,TriggerValue=1);

%create the canonical correlation analysis object with most of the defaults
%except the trial duration
p.cca = BCI_CCA("SampleDuration",p.TrialDuration);

%some flags to keep track of stuff
p.timerStart = 0;

end
