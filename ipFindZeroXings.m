function [ goingUp, goingDown ] = ipFindZeroXings( dData, level)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    if nargin<2
        level=0;
    end
    
    isAbove=dData>level;
    goingUp=find(isAbove(2:end).*~isAbove(1:end-1));
    goingDown=find(isAbove(1:end-1).*~isAbove(2:end));
    if ~isempty(goingUp)
        figure; plot(dData);
    end
    
end

