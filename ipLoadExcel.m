function [ output_args ] = ipLoadExcel( input_args )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
    
    evalin('base', 'global ipTableNum ipTableTxt ipTableRaw ipTableSize')
    global ipTableNum ipTableTxt ipTableRaw ipTableSize

    
    [filename,pathname,~] = uigetfile('*.*','Select excel file with annotations');
    if isequal(filename,0)
        disp('User selected Cancel')
        return
    else
        disp(['User selected ', fullfile(pathname, filename)])
        [ipTableNum, ipTableTxt, ipTableRaw] = xlsread(fullfile(pathname, filename));
    end
    
    aa=cellfun(@isnan, ipTableRaw(1,:), 'un',0);
    lastCol=find(cell2mat(cellfun(@all, aa, 'un',0)));
    if isempty(lastCol)
        lastCol=size(ipTableRaw,2);
    else
        lastCol=lastCol(1)-1;
    end
    
    aa=cellfun(@isnan, ipTableRaw(:,1), 'un',0);
    lastRow=find(cell2mat(cellfun(@all, aa, 'un',0)));
    if isempty(lastRow)
        lastRow=size(ipTableRaw,1);
    else
        lastRow=lastRow(1)-1;
    end   
    disp([num2str(lastCol) ' columns of data loaded for ' ...
        num2str(lastRow-1) ' cells'])
    ipTableSize=[lastCol, lastRow];

    
    
    
    

