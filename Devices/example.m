
clear


f = figure;
p.ax = axes(figure);

p = serialportlist('available');
p = p{4};
d = BNS_HBSpiker(p, .2);
d.PacketReceivedCallback = @handleit;
d.TrialReceivedCallback = @handleERP;
pause(1)
d.SetMode("Trial");
d.Start

function pStruct = handleit(src, pStruct, packet)
    if ~isfield(pStruct, "packetCount")
        pStruct.packetCount = 1;
    else
        pStruct.packetCount = pStruct.packetCount + 1;
    end

    fprintf("got packet #%i\n", pStruct.packetCount);
    if pStruct.packetCount == 20        
        src.SetMode(1)
        src.Start;
    end
end
function pStruct = handleERP(src, pStruct, trial)
    if ~isfield(pStruct, "trialCount")
        pStruct.trialCount = 1;
    else
        pStruct.trialCount = pStruct.trialCount + 1;
    end
    trial

    fprintf("got trial #%i\n", pStruct.trialCount);
end
