function [ output_args ] = ipRunAnalysis( cellList )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

global ipTableNum ipTableTxt ipTableRaw ipTableSize

if nargin<1 || isempty(cellList)
    cellList=1:ipTableSize(2)-1;
end
%% set up the variables to process data

pulseSize=[-100, -50, -20, 0, 100, 200, 300, 400, 500, 600];
pulseStart=1500;
pulseEnd=2500;
checkPulseSize=-50;
checkPulseStart=200;
checkPulseEnd=500;
prepath='/Volumes/BS Office/Dropbox (HMS)/BernardoGilShare/(1)PFcircuitPaper/fig1analysisCellCharic/';

% column order assumptions
% 'Date' 'Animal' 'CellN' 'Epoch' 'EpochEnd' 'SweepStart' 'SweepEnd' 'ML' 'DV' 'Injection ' 'Notes'

%% nested function to return a subrange of the data 
    function rang=SR(startS, endS)
        rang=acqData(floor(startS*acqRate):floor(endS*acqRate));
    end
%% nested function to extract a number from string
    function ns=extractNum(s)
        si=strfind(s, '_');
        if isempty(si)
            ns=str2double(s);
        else
            ns=str2double(s(si+1:end));
        end
    end
%% nested function to return a value from the headerstring
    function hv=headerValue(sString, conv)
        if nargin<2
            conv=0;
        end
        hv=ipHeaderValue(a.(['AD0_' num2str(acqNum)]).UserData.headerString, ...
            sString, conv);
    end
%% run through the cells in the list

for cellCounter=cellList 
    rowCounter=cellCounter+1; % the first row has headers
    fullpath=[prepath num2str(ipTableRaw{rowCounter,1}) '/WW_Gil'];
    cellID=[ipTableRaw{rowCounter,2} '_' num2str(ipTableRaw{rowCounter,3})];
    sStart=extractNum(ipTableRaw{rowCounter,6});
    sEnd=extractNum(ipTableRaw{rowCounter,7});
    
    nAcq=sEnd-sStart+1;
    
    %% initialize the data object
    newCell.allAvgData=[];
    newCell.acq=cell(1,nAcq); % store the full object for that acq sweep
    
    newCell.acqNum=nan(1, nAcq);
    newCell.cycleName=cell(1, nAcq);
    newCell.cyclePosition=nan(1, nAcq);
    newCell.pulsePattern=nan(1, nAcq);
    newCell.extraGain=nan(1, nAcq);
    newCell.pulseSize=nan(1, nAcq);
    
    newCell.storedVm=nan(1, nAcq);
    newCell.storedIm=nan(1, nAcq);
    newCell.storedRm=nan(1, nAcq);
    
    newCell.VrestMode=nan(1, nAcq);
    newCell.VrestMean=nan(1, nAcq);
    newCell.Cm=nan(1, nAcq);
    newCell.Rm=nan(1, nAcq);
    newCell.Vstep=nan(1, nAcq);
    newCell.nAP=nan(1, nAcq);
    %% run through the acquisitions
    
    for sCounter=1:nAcq
        acqNum=sCounter+sStart-1;
        sFile=fullfile(fullpath, ['AD0_' num2str(acqNum) '.mat']);
        a=load(sFile);
        
        newCell.acq{sCounter}=a.(['AD0_' num2str(acqNum)]);
        
        newCell.acqNum(sCounter)=acqNum;
        newCell.cycleName{sCounter}=headerValue('state.cycle.cycleName');
        
        newCell.cyclePosition(sCounter)=headerValue('state.cycle.currentCyclePosition', 1);
        newCell.pulsePattern(sCounter)=headerValue('state.cycle.pulseToUse0', 1);
        newCell.extraGain(sCounter)=headerValue('state.phys.settings.extraGain0', 1);
        
        newCell.storedVm(sCounter)=headerValue('state.phys.cellParams.vm0', 1);
        newCell.storedIm(sCounter)=headerValue('state.phys.cellParams.im0', 1);
        newCell.storedRm(sCounter)=headerValue('state.phys.cellParams.rm0', 1);
        
        acqData=a.(['AD0_' num2str(acqNum)]).data;
        acqDataInt=round(acqData);
        
        acqRate=headerValue('state.phys.settings.inputRate', 1)/1000; % points per ms
        
        newCell.VrestMode(sCounter)=mode(round(SR(checkPulseEnd+100, pulseStart-10)));
        newCell.VrestMean(sCounter)=mean(SR(checkPulseEnd+100, pulseStart-10));
        newCell.Vstep(sCounter)=mode(round(SR(pulseStart, pulseEnd)));
        
        checkPulseV=mode(round(SR(checkPulseStart, checkPulseEnd)));
        newCell.Rm(sCounter)=1000*...       % Rm in MOhm
            (checkPulseV-newCell.VrestMean(sCounter))/checkPulseSize;
        
        ipFindZeroXings(acqData)
        %
        %        %     mode((['AD0_' num2str(sCounter)]).data)
        % %             figure;
        % %             plot(['AD0_' num2str(sCounter)])
        % %             if isempty(allAvgData)
        % %                 allAvgData=['AD0_' num2str(sCounter)]).data/nAcq;
        % %             else
        % %                 allAvgData=allAvgData+a.(['AD0_' num2str(sCounter)]).data/nAcq;
        % %             end
        %
        
    end
    %         figure; plot(allAvgData);
end



end




