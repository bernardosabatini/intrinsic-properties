function [ tau, rmE, rmF, cm ] = ipAnalyzeRC(dData, pulseSize, acqRate)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

	nPnts=length(dData);
	xx=1/acqRate*[0:(nPnts-1)];
	tt=floor(2*nPnts/3);
	bl=mean(dData(tt:end)); % assume last 1/3 is in steady state
	ff=fit(xx', dData'-bl, 'exp1', 'StartPoint', [-bl, -.1] );
%	figure; plot(ff, xx, dData-bl)
	tau=-1/ff.b;
	rmF=-ff.a/pulseSize*1000;
	rmE=bl/pulseSize*1000;
	cm=1000*tau/rmE;
	
	failed=0;
	if  (abs((rmE-rmF)/rmF)>0.3)
		disp(' *** failed from big difference in rm ')
		failed=1;
	end
	
	if (tau<0) || (rmF<0) || (cm<0) 
		disp(' *** failed from neg parameters ');
		failed=1;
	end

	if failed
		[bl, bli]=min(dData);
		bli=max(bli,10);
		ff=fit(xx(1:bli)', dData(1:bli)'-bl, 'exp1', 'StartPoint', [-bl, -(bli/3)/acqRate] );
	%	figure; plot(ff, xx, dData-bl)
		tau=-1/ff.b;
		rmF=-ff.a/pulseSize*1000;
		rmE=bl/pulseSize*1000;
		cm=1000*tau/rmE;		
	end
	
end

