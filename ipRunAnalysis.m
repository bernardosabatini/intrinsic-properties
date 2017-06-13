function [ output_args ] = ipRunAnalysis( cellList )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

% % things for global (x-cell) output
% Vrest
% Ihold
% Cm
% Tau
% V/I
% F/I
% F @ 100 pA
% F @ 200 pA
% 

[~, savePath]=uiputfile('output.mat', 'Select output path');

global ipTableRaw ipTableSize

if ~isnumeric(savePath) && ~isempty(savePath)
	save(fullfile(savePath, 'rawData.mat'), 'ipTableRaw', 'ipTableSize');
else
	savePath=[];
end

if nargin<1 || isempty(cellList)
    cellList=1:ipTableSize(2)-1;
end
%% set up the variables to process data

pulseList.p1=[-100 -75 -50 -25 10 20 30 40 50 60 70 80 90 100 150 200 250];
pulseList.p2=[-100 0 20 40 60 80 100 150 200 250 300];

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
        if isnumeric(s) 
            ns=s;
        elseif ischar(s)
        si=strfind(s, '_');
            if isempty(si)
                ns=str2double(s);
            else
                ns=str2double(s(si+1:end));
            end
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
    sStart=extractNum(ipTableRaw{rowCounter,6});
    sEnd=extractNum(ipTableRaw{rowCounter,7});
    
    nAcq=sEnd-sStart+1;
	if isnan(nAcq)
		nAcq=0;
	end
    
    %% initialize the data object
    newCell.allAvgData=[];
	newCell.mouseID=ipTableRaw{rowCounter,2};
	newCell.cellID=num2str(ipTableRaw{rowCounter,3});
	newCell.pulseID=ipTableRaw{rowCounter,13};
	newCell.pulseList=pulseList.(['p' num2str(newCell.pulseID)]);
	newCell.QC=1; % assume passes QC
	
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
    newCell.stepCm=nan(1, nAcq);
    newCell.stepTau=nan(1, nAcq);
    newCell.stepRmE=nan(1, nAcq);
    newCell.stepRmF=nan(1, nAcq);
    newCell.pulseRm=nan(1, nAcq);
    newCell.Vstep=nan(1, nAcq);
    newCell.nAP=nan(1, nAcq);
    newCell.traceQC=ones(1, nAcq);
	newCell.sagV=nan(1, nAcq);
	newCell.reboundV=nan(1, nAcq);
	newCell.reboundAP=nan(1,nAcq);
	
	avgData=[];
	
    %% run through the acquisitions
    
    fFig=figure('name', [newCell.mouseID ' ' newCell.cellID]);
	hold on
	
	a1=subplot(2, 2, [1 2]);
	title(a1, 'Acquisitions');
	xlabel('time (ms)') 
	ylabel('V (mV)')
	hold on

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
		
		deltaI=newCell.pulseList(newCell.cyclePosition(sCounter))...
			*newCell.extraGain(sCounter);
		newCell.pulseSize(sCounter)=deltaI;
       
        newCell.storedVm(sCounter)=headerValue('state.phys.cellParams.vm0', 1);
        newCell.storedIm(sCounter)=headerValue('state.phys.cellParams.im0', 1);
        newCell.storedRm(sCounter)=headerValue('state.phys.cellParams.rm0', 1);
        
        acqData=a.(['AD0_' num2str(acqNum)]).data;
        acqRate=headerValue('state.phys.settings.inputRate', 1)/1000; % points per ms
        plot((1/acqRate)*[0:(length(acqData)-1)], acqData);
		
        newCell.VrestMode(sCounter)=mode(round(SR(checkPulseEnd+100, pulseStart-10)));
        newCell.VrestMean(sCounter)=mean(SR(checkPulseEnd+100, pulseStart-10));
        newCell.Vstep(sCounter)=mode(round(SR(pulseStart, pulseEnd)));
        
		if deltaI~=0
	        newCell.pulseRm(sCounter)=1000*...       % Rm in MOhm
	            (newCell.Vstep(sCounter)-newCell.VrestMean(sCounter))/deltaI;
			if deltaI<0
				minHyp=min(SR(pulseStart, pulseEnd));
				endHyp=mean(SR(pulseEnd-20,pulseEnd-1));
				newCell.sagV(sCounter)=endHyp-minHyp;
				newCell.reboundV(sCounter)=mean(SR(pulseEnd+20,pulseEnd+70)) ...
					-newCell.VrestMean(sCounter);
			end
		end
		
		notPulse=[SR(1, checkPulseStart-1) SR(checkPulseEnd+20, pulseStart-10) SR(pulseEnd+100, 2999)];
		newCell.noise(sCounter)=std(notPulse);
		
        newCell.pulseAP{sCounter}=ipAnalyzeAP(SR(pulseStart, pulseEnd));
		if isempty(newCell.pulseAP{sCounter})
			newCell.nAP(sCounter)=0;
		else
			newCell.nAP(sCounter)=newCell.pulseAP{sCounter}.nAP;
		end
		
        newCell.postAP{sCounter}=ipAnalyzeAP(SR(pulseEnd+1, floor(length(acqData)/acqRate)));
 		if isempty(newCell.postAP{sCounter})
			newCell.reboundAP(sCounter)=0;
		else
			newCell.reboundAP(sCounter)=newCell.postAP{sCounter}.nAP;
		end
		newCell.pulseAHP(sCounter)=min(SR(pulseEnd+1, floor(length(acqData)/acqRate)))-...
			newCell.VrestMean(sCounter);
        
		[newCell.stepTau(sCounter), ...
			newCell.stepRmE(sCounter), ...
			newCell.stepRmF(sCounter), ...
			newCell.stepCm(sCounter)] = ...
			ipAnalyzeRC(SR(checkPulseStart,checkPulseEnd)-newCell.VrestMean(sCounter), ...
			checkPulseSize, acqRate);
		
		% decide here reasons to reject a trace
		if newCell.VrestMode(sCounter)>-55
			newCell.traceQC(sCounter)=0;
		else
			if isempty(avgData)
				avgData=acqData;
			else
				avgData=avgData+acqData;
			end
		end
	end
	
	
	
	
	goodT=find(newCell.traceQC);
	if isempty(avgData)
		newCell.avgVrestMean=nan;
		newCell.avgStepTau=nan;
		newCell.avgStepRmE=nan;
		newCell.avgStepRmF=nan;
		newCell.avgStepCm=nan;
	else
		newCell.avgData=avgData/length(goodT);
		newCell.avgVrestMean=mean(newCell.avgData(acqRate*[checkPulseEnd+100:pulseStart-10]));
		[newCell.avgStepTau, ...
			newCell.avgStepRmE, ...
			newCell.avgStepRmF, ...
			newCell.avgStepCm] = ...
			ipAnalyzeRC(newCell.avgData(acqRate*[checkPulseEnd+100:pulseStart-10])-newCell.avgVrestMean, ...
			checkPulseSize, acqRate);
	end	
	
	
	lowV=mean(newCell.VrestMean)-5;
	highV=mean(newCell.VrestMean)+5;
	
	
	
	newName=[newCell.mouseID '_' newCell.cellID];
	
	a2=subplot(2, 2, 3);
	yyaxis left
	scatter(newCell.pulseSize(goodT), newCell.Vstep(goodT))
	ylabel('V (mV)')
	yyaxis right
	scatter(newCell.pulseSize(goodT), newCell.nAP(goodT))
	title(a2, 'vs CURRENT')
	ylabel('# AP')
	xlabel('step (pA)') 

	a3=subplot(2, 2, 4);
	scatter(newCell.Vstep(goodT), newCell.nAP(goodT));
	title(a3, 'vs VOLTAGE')
	xlabel('V (mV)') 
	ylabel('# AP')
	if ~isempty(savePath)
		saveas(fFig, fullfile(savePath, [newName 'Fig.fig']));
		print(fullfile(savePath, [newName 'FigPDF']),'-dpdf','-fillpage')
		save(fullfile(savePath, [newName '.mat']), 'newCell');
	end
end



end




