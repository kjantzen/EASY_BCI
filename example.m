
clear


f = figure(1);
clf
objs.ax = axes(f);

p = serialportlist("all");
p = p{7};
try
d = BNS_HBSpiker(p, .2);
d.SetTrialLimits(50,50);
d.PacketReceivedCallback = @handleit;
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
function pStruct = handleit(src, pStruct, packet)
    if ~isfield(pStruct, "packetCount")
        pStruct.packetCount = 1;
    else
        pStruct.packetCount = pStruct.packetCount + 1;
    end
    plot(pStruct.ax, packet.EEG)  
    pStruct.ax.YLim = [0, 1200];
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
