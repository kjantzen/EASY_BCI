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
global state


if state == 0
    state = 1;
    p.flicker.Play(p.TrialDuration);
    %parfeval(@p.flicker.Play, 0, p.TrialDuration);
%    p.StimIsOn = true;
%    p.DataIsCollecting = true;
elseif state == 1
    p.buffer.AddPacket(data);
    if p.buffer.HasCompleteTrial
        p.lastTrial = p.buffer.ReadTrial;
        fprintf('Got a trial\n');
        state = 2;
        plot(p.lastTrial(1,:));
        p.timerStart = tic;
%        p.AnalyzingData = true;
        %analye the data here.
        %change mode based on outcome
        
    end
elseif state == 2
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
% create a flicker object
%will need to specify the trigger port in future
p.flicker = BCI_Flicker(WindowPosition=[200,0,500,500], TargetSize=[50,50],ScreenNumber=0);

%create the trial buffer object
p.buffer = BCI_TrialBuffer(Duration=p.TrialDuration, WaitForTrigger=false,TriggerValue= 1);

%some flags to keep track of stuff
p.timerStart = 0;

end
