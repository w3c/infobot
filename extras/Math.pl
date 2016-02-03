
# infobot copyright (C) kevin lenzo 1997-98

if (!%digits) {
    %digits = ( 
	       "first", "1",
	       "second", "2",
	       "third", "3",
	       "fourth", "4",
	       "fifth", "5",
	       "sixth", "6",
	       "seventh", "7",
	       "eighth", "8",
	       "ninth", "9",
	       "tenth", "10",
	       "one", "1",
	       "two", "2",
	       "three", "3",
	       "four", "4",
	       "five", "5",
	       "six", "6",
	       "seven", "7", 
	       "eight", "8",
	       "nine", "9",
	       "ten", "10"
	       ); 
}

sub math {
    my $in = $_[0];
    # Math handling.

    foreach $x (keys %digits) {
	$in =~ s/\b$x\b/$digits{$x}/g;
    }

    if (getparam('fortranMath')) {
	if ($in =~ /^calc\s+(.+)$/) {
	    $parm = $1;
	    $parm =~ s/\s//g;
	    #$parm =~ s/[a-zA-Z]//g;
	    status("bc: $parm");
	    open(P, "echo '$parm'|bc 2>&1 |");  # dgl++
	    $tmp = '';
	    @prevs = ();
	    foreach $line (<P>) {
		chomp $line;
		$line =~ s/\\$//;
		$line =~ s/\(standard_in\) 1: /$who: /;
		$tmp = 0;
		foreach $p (@prevs) {
		    if ($p eq $line) {
			$tmp = 1;
		    }
		}
		if ($tmp == 0 && $line !~ /illegal character/) {
		    performReply($line);
		}
		push(@prevs, $line);
	    }
	    close(P);
	    return undef;
	}
    }

    if (getparam('perlMath')) {
	if (($in !~ /^\s*$/) and ($in !~ /(\d+\.){2,}/)) {
	    my($locMsg) = $in;

	    foreach (keys %digits) {
		$locMsg =~ s/$_/$digits{$_}/g;
	    }

	    while ($locMsg =~ /(exp ([\w\d]+))/) {
		$exp = $1;
		$val = exp($2); 
		$locMsg =~ s/$exp/+$val/g;
	    }
	    while ($locMsg =~ /(hex2dec\s*([0-9A-Fa-f]+))/) {
		$exp = $1;
		$val = hex($2);
		$locMsg =~ s/$exp/+$val/g;
	    }
	    if ($locMsg =~ /^\s*(dec2hex\s*(\d+))\s*\?*/) {
		$exp = $1;
		$val = sprintf("%x", "$2");
		$locMsg =~ s/$exp/+$val/g;
	    }
	    $e = exp(1);
	    $locMsg =~ s/\be\b/$e/;

	    while ($locMsg =~ /(log\s*((\d+\.?\d*)|\d*\.?\d+))\s*/) {
		$exp = $1;
		$res = $2;
		if ($res == 0) { $val = "Infinity";} 
		else { $val = log($res); } ;
		$locMsg =~ s/$exp/+$val/g;
	    }

	    while ($locMsg =~ /(bin2dec ([01]+))/) {
	    	$exp = $1;
		$val = join ('', unpack ("B*", $2)) ;
	    	$locMsg =~ s/$exp/+$val/g;
	    }

	    while ($locMsg =~ /(dec2bin (\d+))/) {
	    	$exp = $1;
	    	$val = join('', unpack('B*', pack('N', $2)));
		$val =~ s/^0+//;
	    	$locMsg =~ s/$exp/+$val/g;
	    }

	    $locMsg =~ s/ to the / ** /g;
	    $locMsg =~ s/\btimes\b/\*/g;
	    $locMsg =~ s/\bdiv(ided by)? /\/ /g;
	    $locMsg =~ s/\bover /\/ /g;
	    $locMsg =~ s/\bsquared/\*\*2 /g;
	    $locMsg =~ s/\bcubed/\*\*3 /g;
	    $locMsg =~ s/\bto\s+(\d+)(r?st|nd|rd|th)?( power)?/\*\*$1 /ig;
	    $locMsg =~ s/\bpercent of/*0.01*/ig;
	    $locMsg =~ s/\bpercent/*0.01/ig;
	    $locMsg =~ s/\% of\b/*0.01*/g;
	    $locMsg =~ s/\%/*0.01/g;
	    $locMsg =~ s/\bsquare root of (\d+)/$1 ** 0.5 /ig;
	    $locMsg =~ s/\bcubed? root of (\d+)/$1 **(1.0\/3.0) /ig;
	    $locMsg =~ s/ of / * /;
	    $locMsg =~ s/(bit(-| )?)?xor(\'?e?d( with))?/\^/g;
	    $locMsg =~ s/(bit(-| )?)?or(\'?e?d( with))?/\|/g;
	    $locMsg =~ s/bit(-| )?and(\'?e?d( with))?/\& /g;
	    $locMsg =~ s/(plus|and)/+/ig;

	    if (($locMsg =~ /^\s*[-\d*+\s()\/^\.\|\&\*\!]+\s*$/) 
		&& ($locMsg !~ /^\s*\(?\d+\.?\d*\)?\s*$/)
		&& ($locMsg !~ /^\s*$/)
		&& ($locMsg !~ /^\s*[( )]+\s*$/))
	    {
		# $tmpMsg = $locMsg;

		$locMsg = eval($locMsg);

		if ($locMsg =~ /^[-+\de\.]+$/) {
		   # $locMsg = sprintf("%1.12f", $locMsg);
		    $locMsg =~ s/\.0+$//;
		    $locMsg =~ s/(\.\d+)000\d+/$1/; 
		    if (length($locMsg) > 30) {
			$locMsg = "a number with quite a few digits...";
		    }

		    return $locMsg;
		} else {
		    $locMsg = undef;
		}
	    }
	}
    }


    return undef;
}

1;
