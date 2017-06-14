injInt=[];
for c=1:nCells
	inj=ipAllCells{c, 4}
	if inj=='M'
		injInt(end+1)=1;
	elseif inj=='C'
		injInt(end+1)=2;
	elseif inj=='L'
		injInt(end+1)=3;
	end
end