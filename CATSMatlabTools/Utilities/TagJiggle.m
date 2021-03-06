function JiggleRMS = TagJiggle(A,Afs,fs,freq,bin,Atime,DN)
% Distributed with Cade et al. 2018, Determining forward speed from
% accelerometer jiggle in aquatic environments, Journal of Experimental
% Biology, http://jeb.biologists.org/lookup/doi/10.1242/jeb.170449

% Calculates the root mean square amplitude of accelerometer jiggle 
%
% Inputs required are:
% A = calibrated high sample rate acc data (>100 Hz best for speed).  If
%     size(A,2) > 1, the magnitude of the accelerometer is calculated
%     before finding the amplitude of tag jiggle
% Afs = Sample rate of A
% fs = downsampled rate of output file (usually would match downsampled rate of
%     pitch, roll etc.)

% optional inputs:
% freq = bandpass filtering to do on acceleration file (enter [] to use defaults from Cade et al.)
%        default: [10 90].  If freq(2)>Afs/2, only a highpass fiter is used
%        at freq(1)
% bin = bin size over which to average data (in seconds);
%       default: 0.5
% Atime = matlab datenumbers with time points for each value in A (With
%       DN, useful for ensuring exact time correlations between hf and lf
%       data).  Default: Create variable using a random start time and Afs.
% DN = matlab datenumbers of time points at which an RMS value is desired. 
%       DN usually matches the time stamps of every point in a decimated 
%       prh file for which speed will be calculated.  Default: Create 
%       variable using a random start time and fs.

% Output "JiggleRMS" will be the same size as DN (the size of the data at fs)
% 
% Based on DTAG toolbox file d3rms, by Stacy DeRuiter and 
% Alison Stimpert, and utilizes fir_nodelay, by Mark Johnson, available at
% https://www.soundtags.org/dtags/dtag-toolbox/ 

if nargin < 7
    DN = (0:1/fs:(size(A,1)-1)/Afs)'/24/60/60;
end
if nargin < 6 || isempty (Atime)
    Atime = (0:size(A,1)-1)'/24/60/60/Afs;
end

if nargin <5 || isempty(bin)
    bin = 0.5;
end
if nargin < 4 || isempty(freq)
    freq = [10 90];
end

if nargin < 3; help TagJiggle; error('Must have 3 inputs'); end

if freq(2) >= Afs/2; highpass = true; else highpass = false; end

magA = sqrt(sum(A.^2,2));

if highpass
    Afilt = fir_nodelay(magA,128,freq(1)/(Afs/2),'high'); % filter the accelerometer signal between freq(1) and freq(2)
else
    Afilt = fir_nodelay(magA,128,[freq(1)/(Afs/2),freq(2)/(Afs/2)]); % filter the accelerometer signal between freq(1) and freq(2)
end

n = round(Afs*bin); %analyze bin secs of acclerometer data at a time 
nov = round(n-(1/fs*Afs)); %allow for 1/fs samples of overlap...so the one analysis window slides forward by 1/fs sec per time (i.e. 10 Hz data returns 10 Hz data)

if nov - (n-(1/fs*Afs)) > .01 % if your bin size isn't an integer, you have a problem
    error('Non integer bin size.  Trying to slide by 1/fs*Afs, but 1/fs*Afs is not an integer');
end

[X,~,~]= buffer(Afilt,n,nov,'nodelay') ; % n is the number of samples per chunk; nov is the amount of overlap in samples, goes until the last complete bin can be put in a chunk 
Xtime = Atime(round(Afs*bin/2):round(Afs/fs):end); %start half bin seconds in (so that the jiggle bins are centered and are bin seconds long each) and go every 1/fs second, that should get in the middle of the buffer
Xtime = Xtime(1:size(X,2));
RMS = 20*log10(std(X));

JiggleRMS = nan(size(DN));
k = 1; [~,j] = min(abs(DN-(Xtime(1)-1/fs/2/24/60/60))); JiggleRMS(j) = RMS(k);
for k = 1:length(Xtime);
    j2 = find(DN(j:min(j+fs,length(DN)))<=Xtime(k)+1/fs/2/24/60/60,1,'last')+j-1;% find the times that are within 1/fs/2 seconds of Xtime(k)
    if isempty(j2); [~,j] = min(abs(DN-(Xtime(k)-1/fs/2/24/60/60)));[~,j2] = min(abs(DN-(Xtime(k)+1/fs/2/24/60/60))); end
    JiggleRMS(j:j2) = RMS(k);
    j = j2+1;
end
end

% subfunctions
% fir_nodelay
% (c) Mark Johnson, 2013
% https://www.soundtags.org/dtags/dtag-toolbox/

function    [y,h] = fir_nodelay(x,n,fp,qual)
%
%    [y,h] =fir_nodelay(x,n,fp,qual)
%     n is the length of symmetric FIR filter to use.
%     fp is the filter cut-off frequency relative to fs/2=1
%     qual is an optional qualifier to pass to fir1.
%     The filter is generated by a call to fir1:
%        h = fir1(n,fp,qual);
%     Optional 2nd output argument returns the filter used.
%
%     24/12/13 mj: fixed bugs on lines 23 and 24.

if nargin==4,
    h = fir1(n,fp,qual);
else
    h = fir1(n,fp);
end

noffs = floor(n/2) ;
if size(x,1)==1,
    x = x(:) ;
end
y = filter(h,1,[x(n:-1:2,:);x;x(end+(-1:-1:-n),:)]) ;
y = y(n+noffs-1+(1:size(x,1)),:);
end

