function make_bob_file(outfile, days, SAMPLES_PER_DAY)
    % make_bob_file(outfile, days);
    samplesperyear = round(days)*round(SAMPLES_PER_DAY);
    a = zeros(samplesperyear,1);
    % ensure host directory exists
    outdir = fileparts(outfile);
    if ~exist(outdir,'dir')
    	mkdir(outdir);
    end
    % write blank file
    fid = fopen(outfile,'w');
    fwrite(fid,a,'float32');
    fclose(fid);
end