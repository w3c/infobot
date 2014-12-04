# infobot :: Kevin Lenzo   (c) 1997

sub getReply {
    my($msgType, $message, $msgFilter) = @_;
    my($theMsg) = "";
    my($locMsg) = $message;

    # x is y

    # x    is the lhs (left hand side)
    # 'is' is the mhs ("middle hand side".. the "head", or verb)
    # y    is the Y (right hand side)

    my($X, $V, $Y, $result);
    my ($theVerb, $orig_Y);

    $locMsg =~ tr/A-Z/a-z/;

    my $literal = ($locMsg =~ s/^literal //);

    if (getparam('rss') and $message =~ m/^perlfaq\'\s+(.*?)\?*$/) {
	# specially defined type.  get and process an RSS (RDF Site Summary)
	eval "use URI::Escape";
	not ($@) and do {
	    my $q = uri_escape($1, '\W');
	    my $result = &get_headlines("http://www.perlfaq.com/cgi-bin/rss/kw?q=$q");
	    if ($result =~ s/^error: //) {
		return "$who: couldn't get the perlfaq: $result";
	    } else {
		return "$who: $result";
	    }
	}
    } elsif ($result = get("is", $locMsg."/".&channel())) {
#	&status("exact: $message =is=> $result");
	$theVerb = "is";
	$X = $message;
	$V = $theVerb;
	$Y = $result;
	$orig_Y = $X;

    } elsif ($result = get("are", $locMsg."/".&channel())) {
#	&status("exact: $message =is=> $result");
	$theVerb = "are";
	$X = $message;
	$V = $theVerb;
	$Y = $result;
	$orig_Y = $X;

    } else { # no verb
	$y_determiner = '';
	$verbs = join '|', @verb;

	$message = " $message ";

	if ($message =~ / ($verbs) /i) {
	    $X = $`;
	    $V = $1; 
	    $Y = $';

	    $X =~ s/^\s*(.*?)\s*$/$1/;
	    $Y =~ s/^\s*(.*?)\s*$/$1/;
	    $orig_Y = $Y;
	    $Y =~ tr/A-Z/a-z/;

	    $V =~ s/^\s*(.*?)\s*$/$1/;

	    if ($Y =~ s/^(an?|the)\s+//) {
		$y_determiner = $1;
	    } else {
		$y_determiner = '';
	    }

	    if ($questionWord !~ /^\s*$/) {
		if ($V eq "is") {
		    $result = &get("is", $Y);
		} else {
		    if ($V eq "are") {
			$result = &get("are", $Y);
		    }
		}
	    }
	    $theVerb = $V;
	}

	if ($param{'VERBOSITY'} > 1) {
	    my $debugstring = "\tmsgType:\t$msgType\n";
	    $debugstring .= "\tquestionWord:\t$questionWord\n";
	    $debugstring .= "\taddressed:\t$addressed\n";
	    $debugstring .= "\tfinalQMark:\t$finalQMark\n";
	    $debugstring .= "\tX[$X] verb[$theVerb] det[$y_determiner] Y[$Y]\n";
	    $debugstring .= "\tresult:\t$result\n";
	    &status($debugstring);
	}

	if ($y_determiner) {
	    # put the det back on 
	    $Y = "$y_determiner $Y";
	}

# check "is" tables anyway for lhs alone

	if (!defined($V)) {	# no explicit head had been found
	    my $det;
	    if ($locMsg =~ s/^\s*(an?|the)\s+//) {
		$det = $1;
	    }
	    $locMsg =~ s/[.!?]+\s*$//;

	    my($check) = "";

	    $check = &get("is", $locMsg);

	    if ($check ne "") {
		$result = $check;
		$orig_Y = $locMsg;
		$theVerb = "is";
		$V = "is";	# artificially set the head to is
	    } else {
		$check = &get("are", $locMsg);
		if ($check ne "") {
		    $result = $check;
		    $V = "are"; # artificially set the head to are
		    $orig_Y = $locMsg;
		    $theVerb = "are";
		}
	    }
	    if ($det) {
		$orig_Y = "$det $orig_Y";
	    }
	}
    }

    if ($V ne "") {		# if there was a head...
	if (not $literal) {	# Changed to cope with $msgFilter - 26Jun19100, Masque
	    my(@poss) = split(/(?<!\\)\|/, $result);
	    $poss[0] =~ s/^\s//;
	    $poss[$#poss] =~ s/\s$//;
	    my @filtered  =   grep /\Q$msgFilter\E/, @poss unless $msgFilter eq "NOFILTER";

	    if (@filtered) {
                $theMsg =   $filtered[int(rand(@filtered))];
                $theMsg =~  s/^\s*//;
	    } elsif (@poss > 1 && $msgFilter eq "NOFILTER") {
		$theMsg =   $poss[int(rand(@poss))];
		$theMsg =~  s/^\s*//;
	    } else {
		if ($msgFilter eq "NOFILTER" || $result =~ /\Q$msgFilter\E/) {
			$theMsg = $result;
		} else {
			$theMsg = q!<reply>Hmm.  No matches for that, $who.!;
		}
	    }
            $theMsg =~ s/\\\|/\|/g;
	} else {
	    $theMsg = $result;
	}
    }

    $skipReply = 0;

    if ($theMsg ne "") {
	if ($msgType =~ /public/) {
	    my $interval = time() - $prevTime;
	    if ( ($param{'mode'} eq 'IRC' ) 
		&& getparam('repeatIgnoreInterval')
		&& ($theMsg eq $prevMsg) 
		&& ((time()-$prevTime) < getparam('repeatIgnoreInterval'))) {
		&status("repeat ignored ($interval secs < ".getparam('repeatIgnoreInterval').")");
		$skipReply = 1;
		$theMsg = "NOREPLY";
		$prevTime = time();
	    } else {
		$skipReply = 0;
		$prevTime = time() unless ($theMsg eq $prevMsg);
		$prevMsg = $theMsg;
	    }
	}


	# by now $theMsg should contain the result, or null

	# this global is nto a great idea
	$shortReply = 0;
        $noReply = 0;
       
	if (0 and $theMsg =~ s/^\s*<noreply>\s*//i) { 
	    # specially defined type. No reply. Experimental.
	    $noReply = 1;
	    return 'NOREPLY';
	}

	if (!$msgType) {
	    $msgType = 'private';
	    &status("NO MSG TYPE / set to private\n");
	}
	
	if ($literal) {
	    $orig_Y =~ s/^literal //;
	    $theMsg = "$who: $orig_Y =$theVerb= $theMsg";
	    return $theMsg;
	}

	if ($msgType !~ /private/ and $theMsg =~ s/^\s*<reply>\s*//i) {
	    # specially defined type.  only remove '<reply>'
	    $shortReply = 1;
	} elsif (getparam('rss') and $theMsg =~ m/(<(?:rss|rdf)\s*=\s*(\S+)>)/i) {
	    # specially defined type.  get and process an RSS (RDF Site Summary)
	    my ($replace, $rdf_loc) = ($1,$2);
	    $shortReply = 1;
	    $rdf_loc =~ s/^\"+//;
	    $rdf_loc =~ s/\"+$//;

	    if ($rdf_loc !~ /^(ht|f)tp:/) {
		&msg($who, "$orig_Y: bad RSS [$rdf_loc] (not an HTTP or FTP location)");
	    } else {
		my $result = &get_headlines($rdf_loc);
		if ($result =~ s/^error: //) {
		    $theMsg = "couldn't get the headlines: $result";
		} else {
		    $theMsg =~ s/\Q$replace\E/$result/;
		    $theMsg = "$who: $theMsg";
		}
	    }
	} elsif ($msgType !~ /private/ and 
		 $theMsg =~ s/^\s*<action>\s*(.*)/\cAACTION $1\cA/i) {
	    # specially defined type.  only remove '<action>' and make it an action
	    $shortReply = 1;
	} else {		# not a short reply
	    if (!$infobots{$nuh} and $theVerb =~ /is/) {
		my($x) = int(rand(16));
		# oh this could be done much better
		if ($x <= 5) {
		    $theMsg= "$orig_Y is $theMsg";
		}
		if ($x == 6) { 
		    $theMsg= "i think $orig_Y is $theMsg";
		}
		if ($x == 7) { 
		    $theMsg= "hmmm... $orig_Y is $theMsg";
		}
		if ($x == 8) { 
		    $theMsg= "it has been said that $orig_Y is $theMsg";
		}
		if ($x == 9) { 	
		    $theMsg= "$orig_Y is probably $theMsg";
		}
		if ($x == 10) { 
		    $theMsg =~ s/[.!?]+$//;
		    $theMsg= "rumour has it $orig_Y is $theMsg";
		    # $theMsg .= " dumbass";
		}
		if ($x == 11) { 
		    $theMsg= "i heard $orig_Y was $theMsg";
		}
		if ($x == 12) { 
		    $theMsg= "somebody said $orig_Y was $theMsg";
		}
		if ($x == 13) { 
		    $theMsg= "i guess $orig_Y is $theMsg";
		}
		if ($x == 14) { 
		    $theMsg= "well, $orig_Y is $theMsg";
		}
		if ($x == 15) { 
		    $theMsg =~ s/[.!?]+$//;
		    $theMsg= "$orig_Y is, like, $theMsg";
		}
	    } else {
		$theMsg = "$orig_Y $theVerb $theMsg" if ($theMsg !~ /^\s*$/);
	    }
	}
    }

    my $safeWho = &purifyNick($who);

    if (!$shortReply) {
	# shouldn't this be in switchPerson?
	# this is fixing the person for going back out

# /^onz!lenzo@lenzo.pc.cs.cmu.edu privmsg rurl :*** noctcp: omega42 is/: nested *?+ in regexp at /usr/users/infobot/infobot-current/src/Reply.pl line 266, <FH> chunk 176.
	
	if ($theMsg =~ s/^$safeWho is/you are/i) { # fix the person 
	} else {
	    $theMsg =~ s/^$param{'nick'} is /i am /ig;
	    $theMsg =~ s/ $param{'nick'} is / i am /ig;
	    $theMsg =~ s/^$param{'nick'} was /i was /ig;
	    $theMsg =~ s/ $param{'nick'} was / i was /ig;

	    if ($addressed) {
		$theMsg =~ s/^you are (\.*)/i am $1/ig;
		$theMsg =~ s/ you are (\.*)/ i am $1/ig;
	    } else {
		if ($theMsg =~ /^you are / or $theMsg =~ / you are /) {
		    $theMsg = 'NOREPLY';
		}
	    }
	}

	$theMsg =~ s/ $param{'ident'}\'?s / my /ig;
	$theMsg =~ s/^$safeWho\'?s /$safeWho, your /i;
	$theMsg =~ s/ $safeWho\'?s / your /ig;
    }
    

    if (1) {			# $date, $time 
	$curDate = scalar(localtime());
	chomp $curDate;
	$curDate =~ s/\:\d+(\s+\w+)\s+\d+$/$1/;
	$theMsg =~ s/\$date/$curDate/gi;
	$curDate =~ s/\w+\s+\w+\s+\d+\s+//;
	$theMsg =~ s/\$time/$curDate/gi;
    }

    $theMsg =~ s/\$who/$who/gi;

    if (1) {			# variables. like $me or \me
	$theMsg =~ s/(\\){1,}([^\s\\]+)/$1/g;
    }

    $theMsg =~ s/^\s*//;
    $theMsg =~ s/\s+$//;

    if (getparam('filter')) {
	require "src/filter.pl";
	$theMsg = &filter($theMsg);
    }

    if ($theMsg =~ /\S/) {
	return $theMsg;
    } else {
	return undef;
    }
}

1;

