function [ tau, rmE, rmF, cm ] = ipAnalyzeRC(dData, pulseSize, acqRate)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

	nPnts=length(dData);
	xx=1/acqRate*[0:(nPnts-1)];
	tt=floor(2*nPnts/3);
	bl=mean(dData(tt:end)); % assume last 1/3 is in steady state
	ff=fit(xx', dData'-bl, 'exp1', 'StartPoint', [10, -.1] );
%	figure; plot(ff, xx, dData-bl)
	tau=1/ff.b;
	rmF=-ff.a/pulseSize*1000;
	rmE=bl/pulseSize*1000;
	cm=-1000*tau/rmE;
end

