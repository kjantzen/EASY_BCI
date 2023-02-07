clear; close all force;

ERPmini.port = "/dev/cu.usbmodem1401";
port = setupSerial(ERPmini.port);


%while true

%if port.NumBytesAvailable >= payloadLength + headLength
%    bytes = read(port, payloadLength + headLength, 'uint8');
%    fprintf("\nevent marker %i\n", bytes(12));
%    count = 1;
%    for jj = 1:2:payloadLength
%        erpTrial(count) = bitor(bitshift(uint16(bytes(jj+headLength)), 8), uint16(bytes(jj+headLength+1)));
%        %this is to convert from twos complement, which i am not sure is
%        %necessary, but I will check
%        erpTrial(count) = bin2dec(['0b', dec2bin(erpTrial(count)), 's16']);
%        erpTrial(count) = (erpTrial(count) * (1.8/4096)/2000 ) * 1000000; % convert to uV
%        count = count + 1;
%    end
%    plot(t, erpTrial); drawnow;
%    flush(port);
%end
%end

function obj = setupSerial(comPort)

% Initialize Serial object
obj = serialport(comPort, 57600);

%initiate single trial mode
write(obj, "cm1", "char");

configureTerminator(obj, "CR/LF");
configureCallback(obj,"terminator",@serialReadTrial);

end

%%
function serialReadTrial(src, evt)

    b = read(src, src.NumBytesAvailable, "uint8");
    trial = unpackSingleTrial(b);
    fprintf('Trial with event %i, srate %i, prestim %i and posttime %i\n', trial.evt, trial.sampleRate, trial.preBytes, trial.postBytes)
    plot(trial.timePnts, trial.EEG);
    drawnow;

end

%%
function trial = unpackSingleTrial(bytes)

trial = [];
headerBytes = 18;
if ~strcmp(char(bytes(1:11)), "trial onset")
    fprintf('Not a valid trial\n')
    return;
end
trial.evt = bytes(12);
trial.sampleRate = bitor(bitshift(uint16(bytes(13)), 8), uint16(bytes(14)));
trial.preBytes = bitor(bitshift(uint16(bytes(15)), 8), uint16(bytes(16)));
trial.postBytes = bitor(bitshift(uint16(bytes(17)), 8), uint16(bytes(18)));
trial.numBytes = trial.preBytes + trial.postBytes;
trial.preTime = double(trial.preBytes)/2000;
trial.posTime = double(trial.postBytes)/2000;

trial.timePnts = double(1:trial.numBytes/2)./ double(trial.sampleRate) - double(trial.preTime);


sampleCount = 1;
for jj = 1:2:trial.numBytes
        temp = bitor(bitshift(uint16(bytes(jj+headerBytes)), 8), uint16(bytes(jj+headerBytes+1)));
        %this is to convert from twos complement
        temp = bin2dec(['0b', dec2bin(temp), 's16']);
        trial.EEG(sampleCount) = (temp * (1.8/4096)/2000 ) * 1000000; % convert to uV
        sampleCount = sampleCount + 1;
end
end
