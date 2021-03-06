function varargout = extract(W,varargin)

%EXTRACT extract matches to the master waveform
% [MATCH] = EXTRACT(W) reads waveform W and produces a structure MATCH
% which contains relevant information for each successful match with the
% master waveform snippet. This function is intended to be used after
% MASTERCORR.SCAN. In order to function properly, the properties
% MASTERCORR_TRIG, MASTERCORR_CORR and MASTERCORR_SNIPPET must exist in W.
% See MASTERCORR.SCAN for description of these fields. MATCH is a structure
% containing fields:
%   trig (double)           : trigger times in Matlab data format
%   corrValue (double)      : peak correlation values (<=1.0) 
%   corrValueAdj (double)   : max. correlations of an adjacent peak**
%   network (cell)          : network codes
%   station (cell)          : station codes   
%   channel (cell)          : channel codes
%   location (cell)         : network codes
%
%   ** corrValueAdj is the only non-inuitive field in the MATCH structure. It
%   exists to help the user sift potential problems if/when cycle skipping
%   allows the event to be detected multiple times. This problem should be
%   obvious in the event spacing plot (middle panel) when running
%   MASTERCORR.PLOT_STATS. It is up to the user to figure out which
%   detections to keep.
%
%
% [MATCH,C] = EXTRACT(W) produces a correlation object containing
% segmented waveforms extracted from waveform W. 
%
% [MATCH,C] = EXTRACT(W,PRETRIG,POSTRIG) same as above except that the
% length of the traces in the correlation object are defined based on the
% before and after times relative to the trigegr time, specified in seconds
% by PRETRIG and POSTTRIG. These values are given in seconds relative to
% the trigger times in MASTERCORR_TRIG. If not specified, these values are
% inferred from the time fields in TRIGGER, START and END contained in
% MASTERCORR_SNIPPET.
%
% [MATCH,C] = EXTRACT(W,..,THRESHOLD) allows a minimum correlation
% threshold to be included. This is useful if only the highest quality
% waveforms need to be extracted from a more permissive scan of the data.
%
% *** NOTE ABOUT MULTIPLE WAVEFORMS ***
% This function is designed to accept a NxM waveform matrices as input. The
% output is a single correlation object containing the segmented waveforms
% from each element of W. This is useful, for example, when W is a 24x1
% matrix of hourly waveforms. However, unexpected (or clever!) results may
% be produced when W is complicated by elements with different channels or
% master waveform snippets. For some uses it may prove wise to pass only
% selected elements of W to EXTRACT. For example:
% C = EXTRACT(W(1:5)) Note that it is also possible to unwittingly produce
% *massive* correlation objects. Correlation objects exceeding 10,000
% waveforms have been successfully manipulated. As a rule however, be aware
% that downstream processing time goes up considerably as correlation
% objects grow to thousands of events.
%
% See also mastercorr.scan, mastercorr.plot_stats, correlation/correlation,
% waveform/addfield

% Author: Michael West, Geophysical Institute, Univ. of Alaska Fairbanks
% $Date$
% $Revision$



% CHECK INPUTS
if nargin>4
    error('Incorrect number of inputs');
end
if ~isa(W,'waveform')
    error('First argument must be a waveform object');
end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GET ARGUMENTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% SET THRESHOLD
if nargin==2 || nargin==4
    threshold = varargin{end};
else
    threshold = -1;
end
if threshold<-1 || threshold>1
    error('Correlation threshold must be between -1 and 1');
end


% SET TIME WINDOWS
if nargin==3 || nargin==4
    preTrig = varargin{1};
    postTrig = varargin{2};
    useTrigArgs = 1;
else
    preTrig = 0;
    postTrig = 0;
    useTrigArgs = 0;
end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EXTRACT WAVEFORMS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% READ MASTERCORR FIELDS
T.trig = [];
T.corrValue = [];
T.corrValueAdj = [];
T.network = [];
T.station = [];
T.channel = [];
T.location = [];
if numel(W)>1
    for n=1:numel(W)
        T.trig = [T.trig ; get(W(n),'MASTERCORR_TRIG')];
        T.corrValue = [T.corrValue ; get(W(n),'MASTERCORR_CORR')];
        T.corrValueAdj = [T.corrValueAdj ; get(W(n),'MASTERCORR_ADJACENT_CORR')];
        trigLength = numel(get(W(n),'MASTERCORR_TRIG'));
        tmp = {get(W(n),'NETWORK')};   T.network = [T.network ; repmat(tmp,trigLength,1)];
        tmp = {get(W(n),'STATION')};   T.station = [T.station ; repmat(tmp,trigLength,1)];
        tmp = {get(W(n),'CHANNEL')};   T.channel = [T.channel ; repmat(tmp,trigLength,1)];
        tmp = {get(W(n),'LOCATION')};  T.location = [T.location ; repmat(tmp,trigLength,1)];
    end
else
    T.trig = get(W,'MASTERCORR_TRIG');
    T.corrValue = get(W,'MASTERCORR_CORR');
    T.corrValueAdj = get(W,'MASTERCORR_ADJACENT_CORR');
    tmp = {get(W,'NETWORK')};   T.network = tmp;
    tmp = {get(W,'STATION')};   T.station = tmp;
    tmp = {get(W,'CHANNEL')};   T.channel = tmp;
    tmp = {get(W,'LOCATION')};  T.location = tmp;
end


% TRIM BELOW THRESHOLD
f = find(T.corrValue>=threshold);
T.trig = T.trig(f);
T.corrValue = T.corrValue(f);
T.corrValueAdj = T.corrValueAdj(f);

varargout{1} = T;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EXTRACT WAVEFORMS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



if nargout==2
    
    disp('Extracting waveforms from:');
    allWaveforms = repmat(waveform,numel(W),1);
    for n = 1:numel(W)
        
        % SET TIME WINDOWS
        Wsnippet = get(W(n),'MASTERCORR_SNIPPET');
        if ~useTrigArgs
            preTrig =  86400 * (get(Wsnippet,'START') - get(Wsnippet,'TRIGGER'));
            postTrig =  86400 * (get(Wsnippet,'END') - get(Wsnippet,'TRIGGER'));
        end
        disp([ '   ' get(W(n),'NETWORK') '_' get(W(n),'STATION') '_' get(W(n),'CHANNEL') '_' get(W(n),'LOCATION') '   ' get(W(n),'START_STR') ' through ' get(W(n),'END_STR') '   (pre/post trigger: ' num2str(preTrig) ', ' num2str(postTrig) 's)'])
        
        % GET SEGMENTED WAVEFORMS
        trig = get(W(n),'MASTERCORR_TRIG');
        if ~isempty(trig)
            corrValue = get(W(n),'MASTERCORR_CORR');
            f = find(corrValue>=threshold);
            trigList = trig(f);
            wList = extract(W(n),'TIME',trigList+preTrig/86400,trigList+postTrig/86400)';
            wList = delfield(wList,'MASTERCORR_CORR');
            wList = delfield(wList,'MASTERCORR_ADJACENT_CORR');
            wList = delfield(wList,'MASTERCORR_TRIG');
            wList = delfield(wList,'MASTERCORR_SNIPPET');
            if n==1
                allTriggers = trigList;
                allWaveforms = wList;
            else
                allTriggers = [allTriggers ; trigList];
                allWaveforms = [allWaveforms ; wList];
            end
        end
    end
    if numel(allWaveforms)==0
        varargout{2} = correlation;
    else
        varargout{2} = correlation(allWaveforms,allTriggers);
    end
end

