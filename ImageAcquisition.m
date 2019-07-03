% - Asynchronous plane wave transmit acquisition into multiple
% RcvBuffer frames with reconstruction and image processing.
function ImageAcquisition(varargin)
evalin('base','clear');
p = inputParser;
addOptional(p, 'target_position', [-1 -1]);
parse(p, varargin{:})

Resource.parameters.target_position = p.Results.target_position;
startDepth = 5;
endDepth = 200;

Trans.name = 'L11-4v';%'L12-5 38mm'; % 'L12-5 50mm';
Trans.units = 'mm';
Trans.frequency = 6.25; % not needed if using default center frequency
Trans = computeTrans(Trans);
% Trans.name = 'custom';
% Trans.Connector = (1:Trans.numelements)';
% Trans = rmfield(Trans, 'HVMux');
transmit_channels = 128;% Trans.numelements;
receive_channels = 128;%Trans.numelements;

% Specify system parameters
Resource.Parameters.numTransmit = transmit_channels; % no. of transmit channels.
Resource.Parameters.numRcvChannels = receive_channels; % no. of receive channels.
Resource.Parameters.connector = 0;
Resource.Parameters.speedOfSound = 1540; % speed of sound in m/sec
Resource.Parameters.fakeScanhead = 1; % optional (if no L11-4v)
Resource.Parameters.simulateMode = 1; % runs script with hardware
% Specify media points
pt1; % use predefined collection of media points
% Specify Trans structure array.


% Specify PData structure array.
PData.PDelta = [Trans.spacing,0,0.5]; % x, y and z pixel deltas
PData.Size(1) = ceil((endDepth-startDepth)/PData.PDelta(3));
PData.Size(2) = ceil(receive_channels*Trans.spacing/PData.PDelta(1));
PData.Size(3) = 1; % 2D image plane
% PData.Origin is the location [x,y,z] of the upper lft corner of the array.
PData.Origin = [-63.5*Trans.spacing,0,startDepth];
PData.Region = computeRegions(PData);
% Specify Resource buffers.
% Specify Resource buffers.
Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = 4096; % this allows for 1/4 maximum range
Resource.RcvBuffer(1).colsPerFrame = receive_channels;
Resource.RcvBuffer(1).numFrames = 10; % minimum size is 1 frame.
Resource.InterBuffer(1).numFrames = 1; % InterBuffer needed for V64=1
Resource.ImageBuffer(1).numFrames = 10;
Resource.DisplayWindow(1).Title = 'Plane Wave Transmit';
Resource.DisplayWindow(1).pdelta = 0.3;
Resource.DisplayWindow(1).Position = [250,150, ... % lower lft corner pos.
ceil(PData.Size(2)*PData.PDelta(1)/Resource.DisplayWindow(1).pdelta), ...
ceil(PData.Size(1)*PData.PDelta(3)/Resource.DisplayWindow(1).pdelta)];
Resource.DisplayWindow(1).ReferencePt = [PData.Origin(1),0,PData.Origin(3)];
Resource.DisplayWindow(1).AxesUnits = 'mm';
Resource.DisplayWindow(1).Colormap = gray(256);
Resource.DisplayWindow(1).numFrames = 20;

% Specify Transmit waveform structure.
TW(1).type = 'parametric';
TW(1).Parameters = [6.25,0.67,2,1]; % A, B, C, D
% Specify TX structure array.
TX(1).waveform = 1; % use 1st TW structure.
TX(1).focus = 0;
TX(1).Apod = ones(1,transmit_channels);
%TX(1).aperture = 1;
assignin('base','Trans',Trans);
assignin('base','Resource',Resource);

TX(1).Delay = computeTXDelays(TX(1));

% Specify TGC Waveform structure.
TGC(1).CntrlPts = [300,450,575,675,750,800,850,900];
TGC(1).rangeMax = 200;
TGC(1).Waveform = computeTGCWaveform(TGC);
% Specify Receive structure array -
Receive = repmat(struct(...
'Apod', zeros(1, receive_channels), ...
'startDepth', 0, ...
'endDepth', 200, ...
'TGC', 1, ...
'mode', 0, ...
'bufnum', 1, ...
'framenum', 1, ...
'acqNum', 1, ...
'sampleMode', 'NS200BW', ...
'LowPassCoef',[],...
'InputFilter',[]),...
1,Resource.RcvBuffer(1).numFrames);
% - Set event specific Receive attributes.

for i = 1:Resource.RcvBuffer(1).numFrames
    Receive(i).Apod = ones(1, receive_channels);
    Receive(i).framenum = i;
    %Receive(i).aperture = 1;
end

% Specify Recon structure array for 2 board system.
Recon = struct('senscutoff', 0.6, ...
'pdatanum', 1, ...
'rcvBufFrame', -1, ... % use most recently transferred frame
'IntBufDest', [1,1], ... % needed if V64 = 1
'ImgBufDest', [1,-1], ... % auto-increment ImageBuffer each recon
'RINums', 1);
% Define ReconInfo structure for a 128 channel system.
ReconInfo(1) = struct('mode','replaceIntensity', ...
'txnum', 1, ...
'rcvnum', 1, ...
'regionnum',1);

% Specify processing events.
pers = 30;
Process(1).classname = 'Image';
Process(1).method = 'imageDisplay';
Process(1).Parameters = {'imgbufnum',1,... % number of buffer to process.
                        'framenum',-1,... % (-1 => lastFrame)
                        'pdatanum',1,... % number of PData structure
                        'pgain',1.0,... % image processing gain
                        'reject',3,... % see text
                        'persistMethod','simple',... % ‘simple’ or ‘dynamic’
                        'persistLevel', pers,...
                        'grainRemoval', 'none',... % ‘low’,‘medium’,‘high’
                        'processMethod', 'none',... % see text
                        'averageMethod', 'none',... % see text
                        'compressMethod', 'power',... % ‘power’ or ‘log’
                        'compressFactor', 40,...
                        'mappingMethod', 'full',... % see text
                        'display',1,... % display image after processing
                        'displayWindow',1}; % number of displayWindow to use

Process(2).classname = 'External';
Process(2).method = 'myProcFunction';
Process(2).Parameters = {'srcbuffer','receive',... % name of buffer to process.
'srcbufnum',1,...
'srcframenum',-1,... % process the most recent frame.
'dstbuffer','none'};
% Specify sequence events.
SeqControl(1).command = 'timeToNextAcq';
SeqControl(1).argument = 10000;
SeqControl(2).command = 'jump';
SeqControl(2).argument = 1;
SeqControl(3).command = 'timeToNextAcq'; % time between syn. aper. acquisitions
SeqControl(3).argument = 500;
nsc = 4; % start index for new SeqControl
n = 1; % start index for Events
for i = 1:Resource.RcvBuffer(1).numFrames
    Event(n).info = 'Acquire RF Data.';
    Event(n).tx = 1; % use 1st TX structure.
    Event(n).rcv = i; % use 1st Rcv structure for frame.
    Event(n).recon = 0; % no reconstruction.
    Event(n).process = 0; % no processing
    Event(n).seqControl = [1,nsc]; % time between frames and transfer
    SeqControl(nsc).command = 'transferToHost';
    nsc = nsc + 1;
    n = n+1;
%     Event(n).info = 'Call external Processing function.';
%     Event(n).tx = 0; % no TX structure.
%     Event(n).rcv = 0; % no Rcv structure.
%     Event(n).recon = 0; % no reconstruction.
%     Event(n).process = 2; % call ext. processing function
%     Event(n).seqControl = 0;
%     n = n+1;
    Event(n).info = 'Perform reconstruction and image display processing.';
    Event(n).tx = 0; % no TX structure.
    Event(n).rcv = 0; % no Rcv structure.
    Event(n).recon = 1; % reconstruction.
    Event(n).process = 1; % call image processing function
    Event(n).seqControl = 0;
    n = n+1;
end
Event(n).info = 'Jump back to Event 1.';
Event(n).tx = 0; % no TX structure.
Event(n).rcv = 0; % no Rcv structure.
Event(n).recon = 0; % no reconstruction.
Event(n).process = 0; % no processing
Event(n).seqControl = 2; % jump back to Event 1.

% - Create UI controls for channel selection
nr = Resource.Parameters.numRcvChannels;
UI(1).Control = {'UserB1','Style','VsSlider',...
'Label','Plot Channel',...
'SliderMinMaxVal',[1,receive_channels,64],...
'SliderStep', [1/nr,8/nr],...
'ValueFormat', '%3.0f'};
UI(1).Callback = {'assignin(''base'',''myPlotChnl'',round(UIValue))'};

UI(2).Control = {'UserB7','Style','VsPushButton',...
'Label','Targeting GUI'};

UI(2).Callback = {'targeting_display_window'};

UI(3).Control = {'UserB6','Style','VsPushButton',...
'Label','Stimulate'};

UI(3).Callback = {'stimulate_callback'};


%EF(1).Function = text2cell('%EF#1');
% Save all the structures to a .mat file.

filename = 'C:\Users\Verasonics\Documents\MATLAB\Image-Guided-Stim\MatFiles\image_guided_stim';
ws = [filename, '.mat'];
save(filename);
evalin('base', 'load(''C:\Users\Verasonics\Documents\MATLAB\Image-Guided-Stim\MatFiles\image_guided_stim.mat'')');
evalin('base','VSX');
end

% %EF#1
% myProcFunction(RData)
% persistent myHandle
% % If ‘myPlotChnl’ exists, read it for the channel to plot.
% if evalin('base','exist(''myPlotChnl'',''var'')')
% channel = evalin('base','myPlotChnl');
% else
% channel = 32; % Channel no. to plot
% end
% % Create the figure if it doesn’t exist.
% if isempty(myHandle)||~ishandle(myHandle)
% figure;
% myHandle = axes('XLim',[0,1500],'YLim',[-4096 4096], ...
% 'NextPlot','replacechildren');
% end
% % Plot the RF data.
% plot(myHandle,RData(:,channel));
% drawnow
% %EF#1