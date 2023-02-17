clear all

port = '/dev/cu.usbmodem5';
triggerPort = serialport(port, 9600);
f = figure();
f.Position = [500, 500, 1000, 1000];
f.Color = [.5,.5,.5];
a = axes;
pause(1);


try
    for i = 1:100
        rectangle(a,"Position", [0,0,1,1], "FaceColor",'w', 'EdgeColor','w');
        drawnow;
        write(triggerPort, 1, "uint8");
        write(triggerPort, 0, "uint8");
        pause(.25)
       % write(triggerPort, 0, "uint8");
        rectangle(a,"Position", [0,0,1,1], "FaceColor",[.5,.5,.5], "EdgeColor",[.5,.5,.5]);
     
        pause(1);
    end
catch
    delete port;
end
delete port

