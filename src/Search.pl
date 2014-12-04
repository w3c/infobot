# infobot copyright kevin lenzo 1997-1999

sub search {
    return '' unless $addressed;

    my $pattern = shift ;
    $pattern =~ s/^\s*(search|scan)(\s+for)?\s+//i;
    my $type = lc($1);

    my $bail_thresh = 5;

    if ($pattern =~ s/^\d+ //) {
	$bail_thresh = $&; 
    } else {
	if ($type eq 'scan') {
	    $bail_thresh = 1;
	}
    }

    $pattern =~ s/\?+\s*$//; # final ? marks

    return '' if ($pattern =~ /^\s*$/);

    my $minlength = 3;

    return "that pattern's too short.  try something with at least $minlength characters." 
	if (length($pattern) < $minlength);

    &msg($who,"Looking for $pattern:");

    my (@response);

    my (@myIsKeys)  = getDBMKeys("is");

    my $t = time();
    my $count = 0;

    foreach (@myIsKeys) {
	if (/$pattern/) {
	    $r = &get("is", $_);
	} else {
	    next ;
	}
	my $t1 = time();
	if ($t1-$t < 2) {
	    sleep 2;
	}
	&msg($who, "$_ is $r");
	$t = $t1;
	last if ++$count >= $bail_thresh;
    }

    my $last;
    if ($count < $bail_thresh) {
	my (@myAreKeys) = getDBMKeys("are");
	foreach (@myAreKeys) {
	    if (/$pattern/) {
		$r = &get("are", $_);
	    } else {
		next ;
	    }
	    my $t1 = time();
	    if ($t1-$t < 2) {
		sleep 2;
	    }
	    $t = $t1;
	    &msg($who, "$_ are $r");
	    last if ++$count >= $bail_thresh;
	}
	$last = 1;
    }

    if (!$count) {
	&msg($who, "nothing found for $pattern");
    } else {
	my $reply = "  ...showing $count hits";
	if ($last) {
	    $reply .= " (all shown).";
	} else {
	    $reply .= " (more may exist).";
	}
	
	&msg($who, $reply);
    }
    
    return '';
}

1;
