function [ results ] = ipAnalyzeAP(dData, acqRate)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
    
    [gUp, gDown]=ipFindXings(dData, 0, 1); % find the zero crossings
    gUp=floor(gUp);
    gDown=ceil(gDown);
    
	if nargin<2
		acqRate=10;
	end
	
    if isempty(gUp)
        results=[];
%        disp([   'No action potentials found']);
        return
    end
    
    xNum=min(length(gUp), length(gDown));
%    disp([   num2str(xNum) ' action potentials found']);

    results.nAP=xNum;
    
    results.AP_peak=zeros(1, xNum);
    results.AP_AHP=zeros(1,xNum);
    results.AP_time=zeros(1, xNum);
    results.AP_thresh=zeros(1, xNum);   
    results.AP_HW=zeros(1, xNum);
    results.AP_HW_thresh=zeros(1, xNum);
 
    g2=gradient(dData);
    g3=gradient(g2);
    
	if length(gDown)>length(gUp)
		if gDown(1)<gUp(1)
			gDown=gDown(2:(length(gUp)+1));
		else
			disp('problem with gDown');
		end
	end
    gDown(end+1)=length(dData);
    gUp(end+1)=length(dData);
    

    lastMin=1;
    for counter=1:xNum
        [results.AP_peak(counter), Imax]=max(dData(gUp(counter):gDown(counter)));
        Imax=Imax+gUp(counter)-1;
        [results.AP_AHP(counter), Imin]=min(dData(gDown(counter):gUp(counter+1)));
        Imin=Imin+gDown(counter)-1;
        thresh=(results.AP_peak(counter)-results.AP_AHP(counter))/2+results.AP_AHP(counter);
        [ggUp, ggDown]=ipFindXings(dData(lastMin:Imin), 0, 1);
		if length(ggDown)>length(ggUp)
			if ggDown(1)<ggUp(1)
				ggDown=ggDown(2:(length(ggUp)+1));
			else
				disp('problem with ggDown');
			end
		end
        results.AP_HW(counter)=ggDown-ggUp;
        results.AP_HW_thresh(counter)=thresh;
        results.AP_maxRiseRate(counter)=max(g2(lastMin:Imax));
        [~, I]=max(g3(lastMin:Imax));
        results.AP_thresh(counter)=dData(lastMin+I-1);
        results.AP_time(counter)=lastMin+I-1;
        lastMin=Imin;
	end
    results.AP_time=results.AP_time/acqRate;
    results.AP_HW=results.AP_HW/acqRate;
	
end

