function [ output_args ] = ipRunAnalysis( cellList )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    global ipTableNum ipTableTxt ipTableRaw ipTableSize

    if nargin<1 || isempty(cellList)
        cellList=1:ipTableSize(2)-1
    end

        
    prepath='/Volumes/BS Office/Dropbox (HMS)/BernardoGilShare/(1)PFcircuitPaper/fig1analysisCellCharic/';
    
    % column order assumptions
    % 'Date' 'Animal' 'CellN' 'Epoch' 'EpochEnd' 'SweepStart' 'SweepEnd' 'ML' 'DV' 'Injection ' 'Notes'

    for cellCounter=cellList % the first row has headers
        rowCounter=cellCounter+1
        fullpath=[prepath num2str(ipTableRaw{rowCounter,1}) '/WW_Gil'];
        animalID=[ipTableRaw{rowCounter,2} '_' num2str(ipTableRaw{rowCounter,3})];
        sStart=extractNum(ipTableRaw{rowCounter,6});
        sEnd=extractNum(ipTableRaw{rowCounter,7});
        for sCounter=sStart:sEnd
            sFile=fullfile(fullpath, ['AD0_' num2str(sCounter) '.mat'])
            a=load(sFile);
            a.(['AD0_' num2str(sCounter)]).UserData.headerString
        end
        
    end
    
    
    
    
function ns=extractNum(s)
    si=strfind(s, '_');
    if isempty(si)
        ns=str2num(s);
    else
       ns=str2num(s(si+1:end));
    end
    