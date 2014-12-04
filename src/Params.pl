
# infobot :: Kevin Lenzo (c) 1997

if (!$filesep) {
    $filesep = '/';
};

sub loadParamFiles {
    my (@files) = @_;
    my @result;
    my $p;

    if (!@files) {
	# &status("no param files to load");
	return '';
    }

    foreach $p (@files) {
	if ($p !~ /\S/) {
	    &status("warning: param file name is null");
	    return '';
	}

	if (open(PARAM, $p)) {
	    my $count;
	    while (<PARAM>) {
		chomp;
		next if /^\s*\#/;
		next unless /\S/;
		my ($key, $val) = split(/\s+/, $_, 2);
		$val =~ s/\s+$//;

		# perform variable interpolation

		$val =~ s/(\$(\w+))/$param{$2}/g;
		&status("setting $key => $val") 
		    if (exists $param{VERBOSITY} and $param{VERBOSITY} > 2);

		$param{$key} = $val;

		++$count;
	    }
	    &status("loaded param file $p ($count items)");
	    close(PARAM);
	} else {
	    &status("failed to load param file $p");
	}
    }
}

sub writeParamFile {
    my ($filename) = $_[0];
    # write the current parameter set to $filename.
    # returns 1 if successful

    if (open POUT, ">$filename") {
	foreach (sort keys %param) {
	    print POUT "$_ $param{$_}\n";
	}
	close POUT;
	return 1;
    } else {
	# couldn't write the file
	return 0;
    }
}

1;
