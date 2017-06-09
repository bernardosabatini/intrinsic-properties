function [ xings, goingUp ] = ipFindZeroXings( dData )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    
    flipSgn=(dData(1:end-1).*dData(2:end))<0;
    notZero=dData(1:end-1)~=0;
    pZero=(dData(1:end-1).*dData(2:end))==0;
    
    xing=find(flipSgn | (pZero & notZero));
    if ~isempty(xing)
        figure; plot(dData)
    end
    goingUp=dData(xing)<0;
    
end

