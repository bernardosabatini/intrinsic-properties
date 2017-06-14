function [ output_args ] = ipRunAnalysis_v2( cellList )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

	[~, savePath]=uiputfile('output.mat', 'Select output path');

	evalin('base', 'global newCell ipAllCells ipAllCellsLabels');
	global ipTableRaw ipTableSize newCell ipAllCells ipAllCellsLabels


	if nargin<1 || isempty(cellList)
		cellList=1:ipTableSize(2)-1;
	end

	ipAllCellsLabels={'CellID', 'ML', 'DV', 'Injection', 'Vrest', 'Cm', ...
		'Rm', 'Tau', 'F100', 'F200', 'V100', 'V200', 'sag', 'rebound', 'noise', 'pulseI', 'pulseV', 'pulseAP', ...
		'pulseAHP', 'reboundAP', 'reboundV'};
	ipAllCells=cell(max(cellList), length(ipAllCellsLabels));
	
	if ~isnumeric(savePath) && ~isempty(savePath)
		save(fullfile(savePath, 'rawData.mat'), 'ipTableRaw', 'ipTableSize');
	else
		savePath=[];
	end
	
%% set up the variables to process data

	pulseList.p1=[-100 -75 -50 -25 10 20 30 40 50 60 70 80 90 100 150 200 250];
	pulseList.p2=[-100 0 20 40 60 80 100 150 200 250 300];

	pulseStart=1500;
	pulseEnd=2500;
	checkPulseSize=-50;
	checkPulseStart=200;
	checkPulseEnd=500;
%	prepath='/Users/Bernardo/Dropbox (HMS)/BernardoGilShare/(1)PFcircuitPaper/fig1analysisCellCharic/';
%	prepath='/Volumes/BS Office/Dropbox (HMS)/BernardoGilShare/(1)PFcircuitPaper/fig1analysisCellCharic/';
	prepath='/Volumes/BS Office/Dropbox (HMS)/BernardoGilShare/(1)PFcircuitPaper/fig2analysisCellCharic/';

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
	
%% nested function to return a value from the headerstring
%
	function ww=within(x, lo, hi)
		ww=(x>=lo) & (x<=hi);
		return
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
	newCell.acqRate=0;
	newCell.ML=ipTableRaw{rowCounter,8};
	newCell.DV=ipTableRaw{rowCounter,9};
	newCell.injection=ipTableRaw{rowCounter,10};
	newCell.notes=ipTableRaw{rowCounter,11};
	
	newCell.acq=cell(1,nAcq); % store the full object for that acq sweep
    
    newCell.acqNum=nan(1, nAcq);
    newCell.cycleName=cell(1, nAcq);
    newCell.cyclePosition=nan(1, nAcq);
    newCell.pulsePattern=nan(1, nAcq);
    newCell.extraGain=nan(1, nAcq);

    newCell.storedVm=nan(1, nAcq);
    newCell.storedIm=nan(1, nAcq);
    newCell.storedRm=nan(1, nAcq);
    
   	newCell.traceQC=ones(1, nAcq);

	newCell.VrestMode=nan(1, nAcq);
    newCell.VrestMean=nan(1, nAcq);
	newCell.noise=nan(1, nAcq);

	newCell.stepCm=nan(1, nAcq);
    newCell.stepTau=nan(1, nAcq);
    newCell.stepRmE=nan(1, nAcq);
    newCell.stepRmF=nan(1, nAcq);
 
	newCell.pulseI=nan(1, nAcq);
    newCell.pulseRm=nan(1, nAcq);
    newCell.pulseV=nan(1, nAcq);
    newCell.pulseAP=nan(1, nAcq);   
	newCell.pulseSagV=nan(1, nAcq);
	
	newCell.reboundV=nan(1, nAcq);
	newCell.reboundAP=nan(1,nAcq);
		
%% run through the acquisitions and calculate passive parameters
% use to do a first pass QC 
% examine resting potential, RC
    		
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
		newCell.pulseI(sCounter)=deltaI;
       
        newCell.storedVm(sCounter)=headerValue('state.phys.cellParams.vm0', 1);
        newCell.storedIm(sCounter)=headerValue('state.phys.cellParams.im0', 1);
        newCell.storedRm(sCounter)=headerValue('state.phys.cellParams.rm0', 1);
        
        acqData=a.(['AD0_' num2str(acqNum)]).data;
        if sCounter==1 % assume that the DAC sample rate doesn't change.
			acqRate=headerValue('state.phys.settings.inputRate', 1)/1000; % points per ms
			newCell.acqRate=acqRate;
			acqEndPt=length(acqData)-1;
			acqLen=length(acqData)/acqRate;
		end
		
        newCell.VrestMode(sCounter)=mode(round(SR(checkPulseEnd+100, pulseStart-10)));
        newCell.VrestMean(sCounter)=mean(SR(checkPulseEnd+100, pulseStart-10));
		
		notPulse=[SR(1, checkPulseStart-1) SR(checkPulseEnd+20, pulseStart-10) SR(pulseEnd+100, 2999)];
		newCell.noise(sCounter)=std(notPulse);
		
		[newCell.stepTau(sCounter), ...
			newCell.stepRmE(sCounter), ...
			newCell.stepRmF(sCounter), ...
			newCell.stepCm(sCounter)] = ...
			ipAnalyzeRC(SR(checkPulseStart,checkPulseEnd)-newCell.VrestMean(sCounter), ...
			checkPulseSize, acqRate);
	end
		
	avgVm=median(newCell.VrestMean);
	avgStepRmE=median(newCell.stepRmE);
	avgStepRmF=median(newCell.stepRmF);
	avgStepCm=median(newCell.stepCm);
	
	hiV_cutoff=-55; 
	loV=avgVm-5;
	hiV=min(avgVm+5, hiV_cutoff);
	
	loR=avgStepRmE*0.9;
	hiR=avgStepRmE*1.1;

	newCell.traceQC=...
		within(newCell.VrestMean, loV, hiV) & ...
		within(newCell.stepRmE, loR, hiR)...
		;
	
%% plot of the traces that survive QC
    fFig=figure('name', [newCell.mouseID ' ' newCell.cellID]);
	hold on
	
	a1=subplot(3, 2, [1 2]);
	title(a1, ['Good acquisitions ML ' num2str(newCell.ML) ...
		' DV ' num2str(newCell.DV) ' Inj ' newCell.injection]);
	xlabel('time (ms)') 
	ylabel('V (mV)')
	hold on
	
	goodTraces=find(newCell.traceQC);
	nGood=length(goodTraces);

	avgData=[];
	if nGood>nAcq/2
		newCell.QC=1;
	else
		newCell.QC=0;
	end
	
	for sCounter=goodTraces
		acqData=newCell.acq{sCounter}.data;
		plot([0:acqEndPt]/acqRate, acqData);

		if isempty(avgData)
			avgData=acqData/nGood;
		else
			avgData=avgData+acqData/nGood;
		end
	end

	if ~isempty(avgData)
		newCell.avgData=avgData;
		newCell.avgVrestMean=mean(newCell.avgData([checkPulseEnd+100:pulseStart-10]*acqRate));

		[newCell.avgStepTau, ...
			newCell.avgStepRmE, ...
			newCell.avgStepRmF, ...
			newCell.avgStepCm] = ...
			ipAnalyzeRC(newCell.avgData([checkPulseStart:checkPulseEnd]*acqRate)-newCell.avgVrestMean, ...
			checkPulseSize, acqRate);
	else
		newCell.avgVrestMean=nan;
		newCell.avgStepTau=nan;
		newCell.avgStepRmE=nan;
		newCell.avgStepRmF=nan;
		newCell.avgStepCm=nan;
		newCell.QC=0;
	end
	
%% plot the rejected traces
	notGoodTraces=find(~newCell.traceQC);
	a1n=subplot(3, 2, [3 4]);
	title(a1n, 'Bad acquisitions');
	xlabel('time (ms)') 
	ylabel('V (mV)')
	hold on	
	for sCounter=notGoodTraces
		acqData=newCell.acq{sCounter}.data;
		plot([0:acqEndPt]/acqRate, acqData);
	end
	
%% Run through the good ones and extract data

	F100=nan;
	F200=nan;
	V100=nan;
	V200=nan;
	
    for sCounter=goodTraces
        acqData=newCell.acq{sCounter}.data;
		
        newCell.pulseV(sCounter)=mode(round(SR(pulseStart, pulseEnd)));
        deltaI=newCell.pulseI(sCounter);
		
		if deltaI~=0
	        newCell.pulseRm(sCounter)=1000*...       % Rm in MOhm
	            (newCell.pulseV(sCounter)-newCell.VrestMean(sCounter))/deltaI;
			if deltaI<0
				minHyp=min(SR(pulseStart, pulseEnd));
				endHyp=mean(SR(pulseEnd-20,pulseEnd-1));
				newCell.sagV(sCounter)=endHyp-minHyp;
				newCell.reboundV(sCounter)=mean(SR(pulseEnd+20,pulseEnd+70)) ...
					-newCell.VrestMean(sCounter);
			end
		end

		newCell.pulseAPData{sCounter}=ipAnalyzeAP(SR(pulseStart, pulseEnd));
		if isempty(newCell.pulseAPData{sCounter})
			newCell.pulseAP(sCounter)=0;
		else
			newCell.pulseAP(sCounter)=newCell.pulseAPData{sCounter}.nAP;
			if deltaI==100 && isnan(F100)
				F100=newCell.pulseAP(sCounter);
				V100=newCell.pulseV(sCounter);
			elseif deltaI==200 && isnan(F200);
				F200=newCell.pulseAP(sCounter);
				V200=newCell.pulseV(sCounter);
			end
		end
		
        newCell.reboundAPData{sCounter}=ipAnalyzeAP(SR(pulseEnd+1, acqLen));
 		if isempty(newCell.reboundAPData{sCounter})
			newCell.reboundAP(sCounter)=0;
		else
			newCell.reboundAP(sCounter)=newCell.reboundAPData{sCounter}.nAP;
		end
		
		newCell.pulseAHP(sCounter)=min(SR(pulseEnd+1, acqLen))- ...
			newCell.VrestMean(sCounter);
	end
	

	newName=[newCell.mouseID '_' newCell.cellID];
	
	a2=subplot(3, 2, 5);
	yyaxis left
	scatter(newCell.pulseI(goodTraces), newCell.pulseV(goodTraces))
	ylabel('V (mV)')
	yyaxis right
	scatter(newCell.pulseI(goodTraces), newCell.pulseAP(goodTraces))
	title(a2, 'vs CURRENT')
	ylabel('# AP')
	xlabel('step (pA)') 

	a3=subplot(3, 2, 6);
	scatter(newCell.pulseV(goodTraces), newCell.pulseAP(goodTraces));
	title(a3, 'vs VOLTAGE')
	xlabel('V (mV)') 
	ylabel('# AP')

	ipAllCells{cellCounter,1}=newName;
	ipAllCells{cellCounter,2}=newCell.ML;
	ipAllCells{cellCounter,3}=newCell.DV;
	ipAllCells{cellCounter,4}=newCell.injection;
	ipAllCells{cellCounter,5}=newCell.avgVrestMean;
	ipAllCells{cellCounter,6}=newCell.avgStepCm;
	ipAllCells{cellCounter,7}=newCell.avgStepRmF;
	ipAllCells{cellCounter,8}=newCell.avgStepTau;
	ipAllCells{cellCounter,9}=F100;
	ipAllCells{cellCounter,10}=F200;
	ipAllCells{cellCounter,11}=V100;
	ipAllCells{cellCounter,12}=V200;
	if newCell.QC
		ipAllCells{cellCounter,13}=newCell.sagV;
		ipAllCells{cellCounter,14}=newCell.reboundV;
		ipAllCells{cellCounter,15}=newCell.noise;
		ipAllCells{cellCounter,16}=newCell.pulseI;
		ipAllCells{cellCounter,17}=newCell.pulseV;
		ipAllCells{cellCounter,18}=newCell.pulseAP;
		ipAllCells{cellCounter,19}=newCell.pulseAHP;
		ipAllCells{cellCounter,20}=newCell.reboundAP;
		ipAllCells{cellCounter,21}=newCell.reboundV;
	end
	
	if ~isempty(savePath)
%		saveas(fFig, fullfile(savePath, [newName 'Fig.fig']));
		print(fullfile(savePath, [newName 'FigPDF']),'-dpdf','-fillpage')
		save(fullfile(savePath, [newName '.mat']), 'newCell');	
	end
end

if ~isempty(savePath)
	save(fullfile(savePath, 'ipAllCells.mat'), 'ipAllCells', 'ipAllCellsLabels');	
end


end




