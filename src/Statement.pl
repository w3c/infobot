
# infobot :: Kevin Lenzo  (c) 1997

## 
##  doStatement --
## 
##	decide if $in is a statement, and if so, 
##		- update the dbm
##		- return feedback statement
##
##	otherwise return null. 
##

sub doStatement {
    return '' if (lc($who) eq lc($param{'nick'}));

    my($msgType, $in) = @_;

    $in =~ s/\\(\S+)/\#$1\#/g;

    # switch person

    $in =~ s/(^|\s)i am /$1$who is /i; 
    $in =~ s/(^|\s)my /$1$who\'s /ig;
    $in =~ s/(^|\s)your /$1$param{'ident'}\'s /ig;

    if ($addressed) {
	$in =~ s/(^|\s)you are /$1$param{'ident'} is /i;
    }

    $in =~ s/^no,\s+//i;	# don't want to complain if it's new but negative


    if (getparam('plusplus')) {
	$in =~ s/\W(--|\+\+)(\(.*?\)|[^(++)(--)\s]+)/$2$1/;

	# Hacked to allow multiple karma per line and to fix
	# related issues.  foo++foo++ no longer becomes
	# foofoo++++.     - Masque, 12Apr2K
	# ...and to allow only one karma point per item
	# per line.       - Masque, 13Apr2K

	my %k_limit;

	while ($in =~ s/(\(.*?\)|[^(++)(--)\s]+)(\+\+|--)//) {
            my($term,$inc) = ($1,$2);
	    $term = lc($term);
	    next if exists $k_limit{$term};
	    $k_limit{$term} = 1;

    	    # try to normalize phrases
	    $term =~ s/^\((.*)\)$/$1/;
	    $term =~ s/\s+/ /g;

	    if ($msgType !~ /public/i) {
		&msg($who, "karma must be done in public!");
		return "NOREPLY";
	    }

	    if (lc($term) eq lc($who)) {
		&msg($who, "please don't karma yourself");
		return 'NOREPLY';
	    }

	# Whoops!  Better make sure that we're adding karma to something existant.
	    next if $term eq "";

	    if ($inc eq '++') {
		&postInc(plusplus => $term);
	    } elsif ($inc eq '--') {
		&postDec(plusplus => $term);
	    }
	}
	return 'NOREPLY' if $karma;
    }

    my($theType);
    my($lhs, $mhs, $rhs);	# left hand side, uh.. middlehand side...

    # the unignore hack...
    # if we see this word, unignore all
	my $magicword=getparam('unignoreWord');
    if ($in =~ /$magicword/i) { 
	&clearAll('ignore');
	&status("unignoring all ($who said the word)");
    }

    # check if we need to be addressed and if we are
    if ((getparam('addressing') eq 'REQUIRE') && !$addressed) {
	return 'NOREPLY';
    }

    # prefix www with http:// and ftp with ftp://
    $in =~ s/ www\./ http:\/\/www\./ig;	
    $in =~ s/ ftp\./ ftp:\/\/ftp\./ig;

    # look for a "type nugget". this should be externalized.
    $theType = "";
    $theType = "mailto" if ($in =~ /\bmailto:.+\@.+\..{2,}/i);
    $theType = "mailto" if ($in =~ s/\b(\S+\@\S+\.\S{2,})/mailto:$1/gi);
    $in =~ s/(mailto:)+/mailto:/g;

    $theType = "about" if ($in =~ /\babout:/i);
    $theType = 'afp' if ($in =~ /\bafp:/);
    $theType = 'file' if ($in =~ /\bfile:/);
    $theType = 'palace' if ($in =~ /\bpalace:/);
    $theType = 'phoneto' if ($in =~ /\bphone(to)?:/);
    if ($in =~ /\b(news|http|ftp|gopher|telnet):\s*\/\/[\-\w]+(\.[\-\w]+)+/) {
	$theType = $1;
    }

    # here's where you set the behaviour.
    if ((getparam('acceptUrl') =~ /\d+/) && $addressed
	&& (getparam('acceptUrl') < $theUserLevel)) {
    } else {
	if (getparam('acceptUrl') eq 'REQUIRE') {
	    # require url type.
#	    &status("REJECTED non-URL entry") if ($param{VERBOSITY});
	    return 'NOREPLY' if ($theType eq "");
	} elsif (getparam('acceptUrl') eq 'REJECT') {
	    &status("REJECTED URL entry") if ($param{VERBOSITY});
	    return 'NOREPLY' unless ($theType eq "");
	} else {
	    # OPTIONAL
	    # you could put another filter here
	}
    }

    # report status somewhere is we're doing that
    &status("type $theType: $in") if $theType;

    foreach $item (@verb) {	# check for verb
	if ($in =~ /(^|\s)$item(\s|$)/i) {
	    ($lhs, $mhs, $rhs) = ($`, $&, $');
	    $lhs =~ tr/A-Z/a-z/;
	    $lhs =~ s/^\s*(the|da|an?)\s+//i; # discard article
	    $lhs =~ s/^\s*(.*?)\s*$/$1/;
	    $mhs =~ s/^\s*(.*?)\s*$/$1/;
	    $rhs =~ s/^\s*(.*?)\s*$/$1/;

	    # note : prevent access to globals in the eval
	    return '' unless ($lhs and $rhs);

		my $maxkey = getparam("maxKeySize");
	    return "The key is too long (> $maxkey chars)." 
		if (length($lhs) > $maxkey);

	    if (length($message) > getparam('maxDataSize')) {
		if ($msgType =~ /public/) {  
		    if ($addressed) {
			if (rand() > 0.5) {
			    &performSay("that entry is too long, ".$who);
			} else {
			    &performSay("i'm sorry, but that entry is too long, $who");
			} 
		    }	 
		} else {
		    &msg($who, "The text is too long");
		}
		return '';
	    }

	    return 'NOREPLY' if ($lhs eq 'NOREPLY');

	    my $failed = 0;
	    $lhs =~ /^(who|what|when|where|why|how)$/ and $failed++;

	    if (!$failed and !$addressed) {
		# the arsenal of things to ignore if we aren't addressed directly

		$lhs =~ /^(who|what|when|where|why|how|it) /i and $failed++;
		$lhs =~ /^(this|that|these|those|they|you) /i and $failed++;
		$lhs =~ /^(every(one|body)|we) /i and $failed++;

		$lhs =~ /^\s*\*/ and $failed++; # server message
		$lhs =~ /^\s*<+[-=]+/ and $failed++; # <--- arrows
		$lhs =~ /^[\[<\(]\w+[\]>\)]/ and $failed++; # [nick] from bots
		$lhs =~ /^heya?,? / and $failed++; # greetings
		$lhs =~ /^\s*th(is|at|ere|ese|ose|ey)/i and $failed++; # contextless
		$lhs =~ /^\s*it\'?s?\W/i and $failed++; # contextless clitic
		$lhs =~ /^\s*if /i and $failed++; # hypothetical
		$lhs =~ /^\s*how\W/i and $failed++; # too much trouble for now
		$lhs =~ /^\s*why\W/i and $failed++; # too much trouble for now
		$lhs =~ /^\s*h(is|er) /i and $failed++; # her name is
		$lhs =~ /^\s*\D[\d\w]*\.{2,}/ and $failed++; # x...
		$lhs =~ /^\s*so is/i and $failed++; # so is (no referent)
		$lhs =~ /^\s*s+o+r+[ye]+\b/i and $failed++; # sorry
		$lhs =~ /^\s*supposedly/i and $failed++;
		$lhs =~ /^all / and $failed++; # all you have to do, all you guys...
	    } elsif (!$failed and $addressed) {
		# things to skip if we ARE addressed
	    }
	    
	    if ($failed) {
		&status("statement: IGNORED <$who> $message");
		return 'NOREPLY';
	    }

	    &status("statement: <$who> $message");

	    $lhs =~ s/\#(\S+)\#/$1/g;
		# Avi++
        $rhs =~ s/\#\|\#/\\\|/g;
	    $rhs =~ s/\#(\S+)\#/$1/g;

	    $lhs =~ s/\?+\s*$//; # strip the ? off the key
	    $lhs = &update($lhs, $mhs, $rhs);

	    return 'NOREPLY' if ($lhs eq 'NOREPLY');

	    last;
	}
	}

	$lhs;
    }

    1;
