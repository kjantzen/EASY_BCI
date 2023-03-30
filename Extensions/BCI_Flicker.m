classdef BCI_Flicker < handle
    properties
        Frequencies = [8.57, 10, 12, 15];
        ActualFreqs;
        WindowPosition
        TargetSize
        ScreenNumber
    end
    properties (Access = private)
        Frames = [7, 6, 5, 4];
        FramePattern
        FlickerTimeSeries
        ScreenTextures
        WinHandle
        MaxFrames
    end
    methods
        function obj = BCI_Flicker(options)
            % BCI_FICKER constructs a flicker stimulus object for use as the
            % front end of a brain computer interface.

            arguments
                options.WindowPosition (1,4) {mustBeNumeric} = get(0, 'ScreenSize');
                options.TargetSize (1,2) {mustBeNumeric} = [100,100];
                options.ScreenNumber (1,1) {mustBeNumeric, mustBeInteger} = 0;
            end

            obj.WindowPosition = options.WindowPosition;
            obj.TargetSize = options.TargetSize;
            obj.ScreenNumber = options.ScreenNumber;

            obj.FramePattern{1} = [1,1,1,0,0,0,0];
            obj.FramePattern{2} = [1,1,1,0,0,0];
            obj.FramePattern{3} = [1,1,0,0,0];
            obj.FramePattern{4} = [1,1,0,0];

            obj.MaxFrames = obj.myLCM;
            obj.FlickerTimeSeries = zeros(4,obj.MaxFrames );
            for ii = 1:4
                obj.FlickerTimeSeries(ii,:) = repmat(obj.FramePattern{ii},1,obj.MaxFrames /obj.Frames(ii));
            end

            %create the window and initialize the texures
            try
                obj.WinHandle = Screen(obj.ScreenNumber, 'OpenWindow', [], obj.WindowPosition);
                Screen('FillRect',obj.WinHandle,[0 127 0]);

                %define the textures
                for ii = 1:16
                    obj.ScreenTextures(ii) = Screen('MakeTexture', obj.WinHandle, ...
                        obj.buildTextureLayout(ii, obj.WindowPosition(3), ...
                        obj.WindowPosition(4), obj.TargetSize(1), obj.TargetSize(2)));
                end
                
                %get the frame rate and compute a corrected stim frequency
                ifi = Screen('GetFlipInterval', obj.WinHandle);
                obj.ActualFreqs = 1./ (obj.Frames.*ifi);

                  Screen('DrawTexture', obj.WinHandle, obj.ScreenTextures(1));
                Screen('DrawingFinished', obj.WinHandle);
                Screen('Flip', obj.WinHandle);
            catch
                Screen('CloseAll');
                Screen('Close');
                psychrethrow(psychlasterror);
            
            end
  
        end
        % *****************************************************************
        function Play(obj, duration)
            arguments
                obj
                duration (1,1) {mustBeNumeric, mustBePositive};
            end

            try
                flipIndex = 1;
                Priority(1)
                offTime = GetSecs + duration;
    
                while GetSecs < offTime
                    textureValue = obj.bits2dec(obj.FlickerTimeSeries(:, flipIndex)) + 1;
                    Screen('DrawTexture', obj.WinHandle, obj.ScreenTextures(textureValue));
                    %Tell PTB no more drawing commands will be issued until the next flip
                    Screen('DrawingFinished', obj.WinHandle);
                    
                    % Flipping
                    Screen('Flip', obj.WinHandle);
                    flipIndex = flipIndex+1;
    
                    %Reset index at the end of freq matrix
                    if flipIndex > obj.MaxFrames 
                        flipIndex = 1;
                    end
                end
                
                %put the screen back to black
                Screen('DrawTexture', obj.WinHandle, obj.ScreenTextures(1));
                Screen('DrawingFinished', obj.WinHandle);
                Screen('Flip', obj.WinHandle);
            catch
                Screen('CloseAll')
                psychrethrow(psychlasterror);
            end
        end
        % *****************************************************************
        function Close(obj)
            Screen('CloseAll')
            delete(obj)
        end
    end
    %%
    methods (Access = private)
        % *****************************************************************
        function dec = bits2dec(~,x)
            dec = bin2dec(fliplr(dec2bin(x)'));
        end
        % *****************************************************************
        function layout = buildTextureLayout(~,textureNumber, width, height, targetwidth, targetheight)

            drawFlags = dec2bin(textureNumber-1, 4);

            left = [1, (width-targetwidth)/2, width-targetwidth, (width-targetwidth)/2];
            bottom = [(height - targetheight)/2, height-targetheight,(height - targetheight)/2,1];

            layout = uint8(zeros(width, height));

            for jj = 1:4
                if strcmp(drawFlags(5-jj), '1')
                    %for cc = left(jj): left(jj)+ targetwidth -1
                    layout(left(jj): left(jj)+ targetwidth -1, bottom(jj) : bottom(jj)+targetheight-1) = 255;
                    %end
                end
            end

        end
        % *****************************************************************
        function output = myLCM(obj)

            numberArray = reshape(obj.Frames, 1, []);

            % prime factorization array
            for i = 1:size(numberArray,2)
                temp = factor(numberArray(i));

                for j = 1:size(temp,2)
                    output(i,j) = temp(1,j);
                end
            end

            % generate prime number list
            p = primes(max(max(output)));
            % prepare list of occurences of each prime number
            q = zeros(size(p));

            % generate the list of the maximum occurences of each prime number
            for i = 1:size(p,2)
                for j = 1:size(output,1)
                    temp = length(find(output(j,:) == p(i)));
                    if(temp > q(1,i))
                        q(1,i) = temp;
                    end
                end
            end

            %% the algorithm
            z = p.^q;

            output = 1;

            for i = 1:size(z,2)
                output = output*z(1,i);
            end
        end



    end

end
