function [ output_args ] = ipRunAnalysis_v2( cellList, varargin )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

	% where is the data stored
	[~,prepath] = uiputfile('*.*','Select the path with the data folders', 'datapath.mat');
	if isnumeric(prepath)
		disp('Use must select an input path');
		return
	end
	
	% where do we write the output
	[~, savePath]=uiputfile('output.mat', 'Select output path');

	% some globals for posthoc analysis, if you want
	evalin('base', 'global newCell csAllCells csTableOut');
	global csTableRaw csTableSize newCell csTableOut csAllCells

	nameList={};
	nameListCounter=[];
	
    csTableOut={};
    csAllCells=[];
	newCell=[];
    	
	if nargin<1 || isempty(cellList)
		cellList=1:csTableSize(2)-1;
	end

	% save the input data
	if ~isnumeric(savePath) && ~isempty(savePath)
		save(fullfile(savePath, 'rawData.mat'), 'csTableRaw', 'csTableSize');
	else
		savePath=[];
	end
	
	% find the column names in the input and set up fields to hold them
	ind=[];
	for counter=1:length(csTableRaw(1,:))
		if ~isempty(csTableRaw{1,counter}) & ~isnan(csTableRaw{1,counter})
			ind.(matlab.lang.makeValidName(csTableRaw{1,counter}))=counter;
		end
	end
    
	% the fields that will go to the csv and xlsx tables at the end
    newCellFieldsToKeep={'acqNum', 'stepRs', 'stepRm', 'stepCm', 'restMean', ...
        'pscPeak', 'pscPeriAvgPeak', 'pscCharge', ...
        'pscFakePeak', 'pscPeriAvgFakePeak', 'pscFakeCharge'};

	ipAllCellsLabels={'CellID', 'ML', 'DV', 'Injection', 'Vrest', 'Cm', ...
		'Rm', 'Tau', 'F100', 'F200', 'V100', 'V200', 'firstAPwidth', 'firstAPthresh', 'firstAPdvdt',  'firstAPAHP', ...
		'sag', 'rebound', 'VrestSD', 'pulseI', 'pulseV', 'pulseAP', ...
		'pulseAHP', 'reboundAP', 'reboundV'};

	ipAllCells=cell(max(cellList), length(ipAllCellsLabels));
	
	if ~isnumeric(savePath) && ~isempty(savePath)
		save(fullfile(savePath, 'rawData.mat'), 'ipTableRaw', 'ipTableSize');
	else
		savePath=[];
	end
	
	keepOnlyFirst=1;
	
%% set up the variables to process data

	pulseList.p1=[-100 -75 -50 -25 10 20 30 40 50 60 70 80 90 100 150 200 250];
	pulseList.p2=[-100 0 20 40 60 80 100 150 200 250 300];

	pulseStart=1500;
	pulseEnd=2500;
	checkPulseSize=-50;
	checkPulseStart=200;
	checkPulseEnd=500;

	% column order assumptions
	% old % 'Date' 'Animal' 'CellN' 'Epoch' 'EpochEnd' 'SweepStart' 'SweepEnd' 'ML' 'DV' 'Injection ' 'Notes'
	% new % 'Date' 'Animal' 'CellN' 'Rin' 'Cm' 'Epoch' 'EpochEnd'
	%	'SweepStart' 'SweepEnd' 'ML' 'DV' 'amp' 'Injection ' 'Notes'
	%	'currentpulses' 'currentpulseID'
	
	goodTracesToKeep=10;
    blockLength=goodTracesToKeep+4;
    colOffset=30;
    rowCounter=1;
    outputRowCounter=1;
	
	for c=1:2:length(varargin)
		disp(['Override: ' varargin{c} '=' num2str(varargin{c+1})]);
		eval([varargin{c} '=' num2str(varargin{c+1}) ';']);
	end
	
    nCol=min(size(csTableRaw,2), colOffset);
    csTableOut(outputRowCounter, 1:nCol)=csTableRaw(rowCounter, 1:nCol);

	anaStart=pulseStart; % where will we analyze post-synaptic currents
	anaEnd=anaStart+anaWindow; 
	chargeAnaEnd=anaStart+chargeWindow;
	
    insertToCell('cycleName', size(csTableRaw,2)+1, 1)
    insertToCell('cyclePosition', size(csTableRaw,2)+2, 1)
    insertToCell('good_count', size(csTableRaw,2)+3, 1)
    insertToCell('bad_count', size(csTableRaw,2)+4, 1)
    insertToCell('keep_count', size(csTableRaw,2)+5, 1)

    for blockCounter=1:length(newCellFieldsToKeep)
        offset=colOffset+blockLength*(blockCounter-1);
        insertToCell(newCellFieldsToKeep{blockCounter},...
            offset, 1, goodTracesToKeep);
        insertToCell('Avg', offset+goodTracesToKeep, 1);
        insertToCell('Std', offset+goodTracesToKeep+1, 1);
    end

  
%% nested function to insert to cell
    function insertToCell(val, col, row, repeats)
        if nargin<3
            row=rowCounter;
        end
        if nargin<4
            repeats=1;
        end
        
        if length(val)==1 || ischar(val)
            if ~iscell(val)
                val={val};
            end
            if repeats==1
                csTableOut(row, col)=val;
            else
                csTableOut(row, col:col+repeats-1)=repmat(val, 1, repeats);
            end
        else
            if isnumeric(val)
                val=num2cell(val);
            end
            csTableOut(row, col:col+length(val)-1)=val;
        end
        
    end

%% nested function to insert into cell with avg and std
    function insertToCellWithStats(val, block, row)
        if nargin<3
            row=rowCounter;
        end
        
        offset=colOffset+blockLength*(block-1);
        if length(val)>goodTracesToKeep
            val=val(1:goodTracesToKeep);
        end
        
        insertToCell(val, offset, row);
        insertToCell(mean(val), offset+goodTracesToKeep, row);
        insertToCell(std(val), offset+goodTracesToKeep+1, row);
    end
	
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

%% nested function to return only non-nan entries
	function ap=nonNan(a)
		ap=a(~isnan(a));
		return
	end
%%
		

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
	newCell.mouseID=ipTableRaw{rowCounter,2};
	newCell.cellID=num2str(ipTableRaw{rowCounter,3});
	newCell.breakInRin=num2str(ipTableRaw{rowCounter,4});
	newCell.breakInCm=num2str(ipTableRaw{rowCounter,5});
	
	newCell.pulseID=ipTableRaw{rowCounter,14};
	newCell.pulseList=pulseList.(['p' num2str(newCell.pulseID)]);
	newCell.QC=1; % assume passes QC
	newCell.acqRate=0;
	newCell.ML=ipTableRaw{rowCounter,8};
	newCell.DV=ipTableRaw{rowCounter,9};
	newCell.DV=ipTableRaw{rowCounter,9};
	newCell.holdingCurrent=ipTableRaw{rowCounter,10};	
	newCell.injection=ipTableRaw{rowCounter,11};
	newCell.notes=ipTableRaw{rowCounter,12};
	
	newCell.acq=cell(1,nAcq); % store the full object for that acq sweep
    
    newCell.acqNum=nan(1, nAcq);
    newCell.cycleName=cell(1, nAcq);
    newCell.cyclePosition=nan(1, nAcq);
    newCell.pulsePattern=nan(1, nAcq);
    newCell.extraGain=nan(1, nAcq);
    
   	newCell.traceQC=ones(1, nAcq);

	newCell.VrestMode=nan(1, nAcq);
    newCell.VrestMean=nan(1, nAcq);
    newCell.VrestMax=nan(1, nAcq);
    newCell.VrestMin=nan(1, nAcq);
	newCell.VrestSD=nan(1, nAcq);

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
		
	
	fullPulse=zeros(1, length(newCell.pulseList));
	
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
		
		if fullPulse(newCell.cyclePosition(sCounter))==0
			fullPulse(newCell.cyclePosition(sCounter))=sCounter;
			first=1;
		else
			first=0;
		end
				
		if ~keepOnlyFirst || (keepOnlyFirst && first)
			acqData=a.(['AD0_' num2str(acqNum)]).data;
			if sCounter==1 % assume that the DAC sample rate doesn't change.
				acqRate=headerValue('state.phys.settings.inputRate', 1)/1000; % points per ms
				newCell.acqRate=acqRate;
				acqEndPt=length(acqData)-1;
				acqLen=length(acqData)/acqRate;
			end


			notPulse=[SR(1, checkPulseStart-10) SR(checkPulseEnd+100, pulseStart-10)]; % SR(pulseEnd+100, 2999)];
			newCell.VrestMode(sCounter)=mode(round(notPulse));
			newCell.VrestMean(sCounter)=mean(notPulse);
			newCell.VrestSD(sCounter)=std(notPulse);
			newCell.VrestMin(sCounter)=min(notPulse);
			newCell.VrestMax(sCounter)=max(notPulse);


			[newCell.stepTau(sCounter), ...
				newCell.stepRmE(sCounter), ...
				newCell.stepRmF(sCounter), ...
				newCell.stepCm(sCounter)] = ...
				ipAnalyzeRC(SR(checkPulseStart,checkPulseEnd)-newCell.VrestMean(sCounter), ...
				checkPulseSize, acqRate);
		end
	end
		
	avgVm=median(nonNan(newCell.VrestMean));
	avgStepRmE=median(nonNan(newCell.stepRmE));
%	avgStepRmF=median(nonNan(newCell.stepRmF));
%	avgStepCm=median(nonNan(newCell.stepCm));
	
	hiV_cutoff=-50; 
	loV=avgVm-5;
	hiV=min(avgVm+5, hiV_cutoff);
	
	loR=avgStepRmE*0.9;
	hiR=avgStepRmE*1.1;

	newCell.traceQC=...
		within(newCell.VrestMean, loV, hiV) & ...
		within(newCell.stepRmE, loR, hiR) & ...
		within(newCell.VrestMax-newCell.VrestMin, 0, 5) & ...
		within(newCell.VrestSD, 0, 2)...
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
	
	if ~keepOnlyFirst
		goodTraces=find(newCell.traceQC);	
		denom=nAcq;
	else
		goodTraces=intersect(find(newCell.traceQC), fullPulse);
		denom=length(find(fullPulse>0));
	end
		
	nGood=length(goodTraces);

	avgData=[];
	if nGood>denom/2
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

		acqData=avgData;	
		[newCell.avgStepTau, ...
			newCell.avgStepRmE, ...
			newCell.avgStepRmF, ...
			newCell.avgStepCm] = ...
			ipAnalyzeRC(SR(checkPulseStart,checkPulseEnd)-newCell.avgVrestMean, ...
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
	firstAPwidth=nan;
	firstAPthresh=nan;
	firstAPdvdt=nan;
	firstAPAHP=nan;

	
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
		
		newCell.pulseAPData{sCounter}=ipAnalyzeAP(SR(pulseStart, pulseEnd), acqRate);
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
			
			if isnan(firstAPwidth)
				firstAPpeak=newCell.pulseAPData{sCounter}.AP_peak_V(1);
				firstAPwidth=newCell.pulseAPData{sCounter}.AP_HW(1);
				firstAPthresh=newCell.pulseAPData{sCounter}.AP_thresh_V(1);
				firstAPdvdt=newCell.pulseAPData{sCounter}.AP_max_dVdT(1);
				firstAPAHP=newCell.pulseAPData{sCounter}.AP_AHP_V(1);
			end
		end
		
        newCell.reboundAPData{sCounter}=ipAnalyzeAP(SR(pulseEnd+1, acqLen), acqRate);
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
	ipAllCells{cellCounter,13}=firstAPwidth;
	ipAllCells{cellCounter,14}=firstAPthresh;
	ipAllCells{cellCounter,15}=firstAPdvdt;
	ipAllCells{cellCounter,16}=firstAPAHP;
	
	if newCell.QC
		ipAllCells{cellCounter,17}=newCell.sagV;
		ipAllCells{cellCounter,18}=newCell.reboundV;
		ipAllCells{cellCounter,19}=newCell.VrestSD;
		ipAllCells{cellCounter,20}=newCell.pulseI;
		ipAllCells{cellCounter,21}=newCell.pulseV;
		ipAllCells{cellCounter,22}=newCell.pulseAP;
		ipAllCells{cellCounter,23}=newCell.pulseAHP;
		ipAllCells{cellCounter,24}=newCell.reboundAP;
		ipAllCells{cellCounter,25}=newCell.reboundV;
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




