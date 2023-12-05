function [data, fac1, fac2, chans] = reshapeForAnova(dStruct, f1, f2)


data = [];
chans = [];
fac1 = [];
fac2 = [];

ncond = length(f1);
if nargin < 3
    f2 = [];
end

if ncond ~= length(dStruct.conditions)
    error("The number of factor levels is %i but there are only %i conditions\n", ncond, length(dStruct.conditions));
end

nchan = length(dStruct.channum);

for ii = 1:ncond
    tempfac1 = []; tempfac2 = [];
    d = []; c = [];

    ntrials = dStruct.singletrials(ii).ntrials;
    for cc = 1:nchan
        if nchan==1
            d = [d;dStruct.singletrials(ii).trials];
        else
            d = [d;dStruct.singletrials(ii).trials(cc,:)'];
        end
        c = [c;repmat(dStruct.channame(cc), ntrials,1)];
        tempfac1 = [tempfac1; repmat(f1(ii), ntrials,1)];
        if ~isempty(f2)
            tempfac2 = [tempfac2;repmat(f2(ii), ntrials, 1)];
        end
    end
    data = [data;d];
    chans = [chans;c];
    fac1 = [fac1; tempfac1];
    fac2 = [fac2; tempfac2];
   
end