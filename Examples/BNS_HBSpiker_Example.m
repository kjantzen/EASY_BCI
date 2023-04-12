%simple example for how to use the BNS_HBSpiker Object


%create a figure and axis
f = figure(1);
clf
objs.ax = axes(f);

%get a list of serial ports available and select the one that is connected
%to the SpikerBox.  When creating the example, it was port 7, but it may be
%different on your computer
p = serialportlist("all");
p = p{7};

%set up and start the spikerbox object
try
    %create the object on port p using a .2 second collection window.
    d = BNS_HBSpiker(p, .2);
    %set the trial limits for ERP mode
    d.SetTrialLimits(50,50);
    %setup the callbacks for continuous and single trial mode
    d.PacketReceivedCallback = @handlePacket;
    d.TrialReceivedCallback = @handleERP;

    d.ProcessObjects = objs;
    pause(1)
    d.SetMode("Trial");
    d.Start
catch me
    msgbox(me.message)
    close(f)
    return;
end
function pStruct = handlePacket(src, pStruct, packet)
    if ~isfield(pStruct, "packetCount")
        pStruct.packetCount = 1;
    else
        pStruct.packetCount = pStruct.packetCount + 1;
    end
    plot(pStruct.ax, packet.EEG)  
    pStruct.ax.YLim = [-700, 700];
    drawnow;

end
function pStruct = handleERP(src, pStruct, trial)
    if ~isfield(pStruct, "trialCount")
        pStruct.trialCount = 1;
    else
        pStruct.trialCount = pStruct.trialCount + 1;
    end
    plot(pStruct.ax, trial.timePnts, trial.EEG);
    drawnow;
    %pStruct.ax.YLim = [0, 1200];

    
   % fprintf("got trial #%i\n", pStruct.trialCount);
end
