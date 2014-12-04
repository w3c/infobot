# infobot :: Kevin Lenzo 1997-1999

# process the incoming message

$SIG{'ALRM'} = 'TimerAlarm';

sub process {
    ($who, $msgType, $message) = @_;
    my ($result, $caughtBy);

    $origMessage = $message; # intentionally global

    return 'SELF' if (lc($who) eq lc($param{'nick'}));

    $message =~ s/[\cA-\c_]//ig; # strip control characters
    $msgFilter = "NOFILTER"; 	 # 26Jun19100 - Masque  
#   $msgFilter = $1 if $message =~ s/\s+(?:=~)\s?\/\(\?:(.*?)\)\/i?\s*//;
#   STILL doesn't match '=~ /(?:(toot!))/'!  Grah.  Could make this simpler, but this is fun.  29Jun2K - Masque.
#   FIXME
    $msgFilter = ($1 || $2) if $message =~ s!\s+(?:=~)?\s?/(?:\((?:\?:)?([^)]*)\)|([^()]*))/i?\s*$!!;


    $addressed = 0;
    $karma = 0;		# 12Apr2k - Masque

    return 'ANTIHELP' if $instance =~ /antihelp/;

    my ($n, $uh) = ($nuh =~ /^([^!]+)!(.*)/);
    if ($param{'VERBOSITY'} > 3) { # murrayb++
	&status("Splitting incoming address into $n and $uh");
    }

    if ($msgType =~ /private/ and $message =~ /^hey, what is/) {
	$infobots{$nuh} = $who;
	&msg($who, "inter-infobot communication now requires version 0.43 or higher.");
	return 'INTERBOT';
    }

    return 'INTERBOT' if $message =~ /^...but/;
    return 'INTERBOT' if $message =~ /^.* already had it that way/;
    return 'INTERBOT' if $message =~ /^told /; # reply from friendly infobot
    return 'INTERBOT' if $message =~ /^told /; # reply from friendly infobot
    return 'INTERBOT' if ($message =~ /^[!\*]/);
    return 'INTERBOT' if ($message =~ /^gotcha/i);

    # this assumes that the ignore list will be fairly small, as we
    # loop through each key rather than doing a straight lookup
    # -- this should be moved and made more efficient -- kl
    if (&get(ignore => $uh) or &get(ignore => $who)) {
	&status("IGNORE <$who> $message");
	return 'IGNORE';
    }
    foreach (&getDBMKeys('ignore')) {
	my $ignoreRE = $_;
	my @parts = split /\*/, "a${ignoreRE}a";
	my $recast = join '\S*', map quotemeta($_), @parts;
	$recast =~ s/^a(.*)a$/$1/;
	if ($nuh =~ /^$recast$/) {
	    &status("IGNORE <$who> $message");
	    return 'IGNORE';
	}
    }
    # -- --

    if ($msgType =~ /private/ and $message =~ s/^:INFOBOT://) {
	&status("infobot <$nuh> identified") unless $infobots{$nuh};
	$infobots{$nuh} = $who;
    }

    if ($infobots{$nuh}) {
	if ($msgType =~ /private/) {
	    if ($message =~ /^QUERY (<.*?>) (.*)/) {
		my $r;
		my $target = $1;
		my $item = $2;
		$item =~ s/[.\?]$//;

		&status(":INFOBOT:QUERY $who: $message");

		if ($r = &get("is", $item)) {
		    &msg($who, ":INFOBOT:REPLY $target $item =is=> $r");
		} 
		if ($r = &get("are", $item)) {
		    &msg($who, ":INFOBOT:REPLY $target $item =are=> $r");
		}

	    } elsif ($message =~ /^REPLY <(.*?)> (.*)/) {
		my $r;
		my $target = $1;
		my $item = $2;


		&status(":INFOBOT:REPLY $who: $message");

		my ($X, $V, $Y) = $item =~ /^(.*?) =(.*?)=> (.*)/;
		if ((getparam('acceptUrl') !~ /REQUIRE/) or ($Y =~ /(http|ftp|mailto|telnet|file):/)) {
		    &set($V, $X, $Y);
		    &msg($target, "$who knew: $X $V $Y");
		}

	    }
	}
	return 'INFOBOT';
    }

    $VerifWho = &verifyUser($nuh);

    if ($VerifWho) {
        if (IsFlag("i") eq "i") {
	    &status("Ignoring $who: $VerifWho");
	    return 'IGNORED';
        }

	if ($msgType =~ /private/) {
	    # it's a private message
	    my ($potentialPass) = $message =~ /^\s*(\S+)/;

	    if (exists($verified{$VerifWho})) {
		# aging. you need to keep talking to it re-verify
		if (time() - $verified{$VerifWho} < 60*60) { # 1 hour decay
		    $verified{$VerifWho} = $now;
		} else {
		    &status("verification for $VerifWho expired");
		    delete $verified{$VerifWho};
		}
	    }

	    if ($uPasswd eq "NONE_NEEDED") {
		&status("no password needed for $VerifWho");
		$verified{$VerifWho} = $now;
	    }

	    if (&ckpasswd($potentialPass, $uPasswd)) {
		$message =~ s/^\s*\S+\s*//;
		$origMessage =~ s/^\s*\S+\s*/<PASSWORD> /;
		&status("password verified for $VerifWho");
		$verified{$VerifWho} = $now;
		if ($message =~ /^\s*$/) {
		    &msg($who, "i recognize you there");
		    return 'PASSWD';
		}
	    }
	}
    }

    # see User.pl for the "special" user commands
    return 'NOREPLY' if &userProcessing() eq 'NOREPLY';

    if ($msgType !~ /public/) { $addressed = 1; }

    if (($message =~ s/^(no,?\s+$param{'nick'},?\s*)//i)
	or ($addressed and $message =~ s/^(no,?\s+)//i)) { 
        # clear initial negative
	# an initial negative may signify a correction
	$correction_plausible = 1;
	&status("correction is plausible, initial negative and nick deleted ($1)") if ($param{VERBOSITY} > 2);
    } else {
	$correction_plausible = 0;
    }

    if ($message =~ /^\s*$param{'nick'}\s*\?*$/i) {
	&status("feedback addressing from $who");
	$addressed = 1;
	$blocked = 0;	   
	if ($msgType =~ /public/) {
	    if (rand() > 0.5) {
		&performSay("yes, $who?");
	    } else {
		&performSay("$who?");
	    }
	} else {
	    &msg($who, "yes?");
	}

	$lastaddressedby = $who;
	$lastaddressedtime = time();
	return "FEEDBACK";
    }

    if (($message =~ /^\s*$param{'nick'}\s*([\,\:\> ]+) */i) 
	or ($message =~ /^\s*$param{'nick'}\s*-+ *\??/i)) {
	# i have been addressed!
	my($it) = $&;

	if ($' !~ /^\s*is/i) {
	    $message = $';
	    $addressed = 1;
	    $blocked = 0;   
	}
    }

    if ($message =~ /, ?$param{nick}(\W+)?$/i) { # i have been addressed!
	my($it) = $&; 
	if ($` !~ /^\s*i?s\s*$/i) {
	    $xxx = quotemeta($it);
	    $message =~ s/$xxx//;
	    $addressed = 1;
	    $blocked = 0;   
	}
    }

    if ($addressed) {
	&status("$who is addressing me");
	$lastaddressedby = $who;
	$lastaddressedtime = time();

	if ($message =~ /^showmode/i ) {
	    if ($msgType =~ /public/) {
		if ((getparam('addressing') ne 'REQUIRE') or $addressed) {
		    &performSay ($who.", addressing is currently ".getparam('addressing'));
		}
	    } else {
		&msg($who, "addressing is currently ".getparam('addressing'));
	    }
	    return "SHOWMODE";
	}

	my $channel = &channel();
	$continuity = 0;

    } else {			# apparently not addressed
	my ($now, $diff);

	if (getparam('continuity') and $who eq $lastaddressedby) {
	    $now = time();
	    $diff = $now - $lastaddressedtime;

	    if ($diff < getparam('continuity')) {
		# assume we're talking to the same person even if we're
		# not addressed, if we've been addressed in x seconds 
		&status("assuming continuity of address by $who ($diff seconds elapsed)");
		$continuity = 1;
	    }
	} else {
	    $continuity = 0;
	}
    }

    $skipReply = 0;
    $message_input_length = length($message);

# this was here to help stop bots from just triggering
# "confused" messages to each other, but should be done 
# more systematically.  took it out to cut overhead. --kl
#    $confusedRE = join '|', map quotemeta($_), @confused unless defined $confusedRE;
#    return 'CONFUSED' if $message =~ /$confusedRE/;

    return if ($who eq $param{'nick'});

    $message =~ s/^\s+//;	# strip any dodgey spaces off

    # Half finished thought here - "^Pudge - it's there" looks like math but is
    # often nick completion or similar.  
    # if (($message =~ s/^\S+\s*:\s+//) or ($message =~ s/^\S+\s+--?\s+[.\d]//)) {
    if (($message =~ s/^\S+\s*:\s+//) or ($message =~ s/^\S+\s+--+\s+//)) {
	# stripped the addressee ("^Pudge: it's there") 
	$reallyTalkingTo = $1;
    } else {
	$reallyTalkingTo = '';
	if ($addressed) {
	    $reallyTalkingTo = $param{'nick'};
	}
    }

    $message =~ s/^\s*hey,*\s+where/where/i;
    $message =~ s/whois/who is/ig;
    $message =~ s/where can i find/where is/i;
    $message =~ s/how about/where is/i;
    $message =~ s/^(gee|boy|golly|gosh),? //i;
    $message =~ s/^(well|and|but|or|yes),? //i;
    $message =~ s/^(does )?(any|ne)(1|one|body) know //i;
    $message =~ s/ da / the /ig;
    $message =~ s/^heya*,*( folks)?,*\.* *//i; # clear initial filled pauses & stuff
    $message =~ s/^[uh]+m*[,\.]* +//i;
    $message =~ s/^o+[hk]+(a+y+)?,*\.* +//i; 
    $message =~ s/^g(eez|osh|olly)+,*\.* +(.+)/$2/i;
    $message =~ s/^w(ow|hee|o+ho+)+,*\.* +(.+)/$2/i;
    $message =~ s/^still,* +//i; 
    $message =~ s/^well,* +//i;
    $message =~ s/^\s*(stupid )?q(uestion)?:\s+//i;

    my $holdMessage = $message;

    # the thing to tell someone about ($tell_obj).  Yes i know these are evil globals. --kl
    ($tell_obj, $target) = (undef,undef,undef);

    # i'm telling!
    if (getparam('allowTelling')) {
	# this one catches most of them
	if ($message =~ /^tell\s+(\S+)\s+about\s+(.*)/i) {
	    ($target, $tell_obj) = ($1, $2);
	} elsif ($message =~ /tell\s+(\S+)\s+where\s+(\S+)\s+can\s+(\S+)\s+(.*)/i) {
	    # i'm sure this could all be nicely collapsed
	    ($target, $tell_obj) = ($1, $4);
	} elsif ($message =~ /tell\s+(\S+)\s+(what|where)\s+(.*?)\s+(is|are)[.?!]*$/i) {
	    ($target, $qWord, $tell_obj, $verb) = ($1, $2, $3, $4);
	    $tell_obj = "$qWord $verb $tell_obj";
	}

	if (($target =~/^\s*[\&\#]/) or ($target =~ /\,/)) {
	    $result = "No, ".$who.", i won\'t";
	    $target = $who;
	    $caughtBy = "tell";
	}

	if ($target eq $param{'nick'}) {
	    $result = "Isn\'t that a bit silly, ".$who."?";
	    $target = $who;
	    $caughtBy = "tell";
	}

	$tell_obj =~ s/[\.\?!]+$// if defined $tell_obj;
    }

    if (not defined $result) {
	$target   = $who     unless defined $target;
	$target   = $who     if     $target eq 'me';
	$target   = undef    if     $target eq 'us';

	# here's where the external routines get called.
	# if they return anything but null, that's the "answer".

	$message  = $tell_obj if $tell_obj;

	if ($continuity or $addressed or 
	    (getparam('addressing') ne "REQUIRE")) {

	    if (defined ($result = &myRoutines())) {
		$caughtBy = "myRoutines";
	    } elsif (defined($result = &Extras())) {
		$caughtBy = "Extras";
# BEEP BEEP - TODO ALERT: Change the karma lookup to do a doQuestion
# before returning a karma query to catch factoids that should return
# instead of reporting karma.  Assigned to boojum at the moment.
	    } elsif (defined($result = &doQuestion($msgType, $message, $msgFilter))) {
		$caughtBy = "Question";
	    }

	    if (($result eq 'NOREPLY') or ($who eq 'NOREPLY')) {
		return '';
	    }
	  # This fixes the problem of short karma strings (masque++ for
	  # example) being ignored.   -- Masque, 12Apr2K 
	    if ($message =~ /(?:\+\+|--)/) { $karma = 1; }

	    if (!$finalQMark and !$addressed and !$tell_obj and
		!$karma and
		($input_message_length < getparam('minVolunteerLength'))) {
		$in = '';
		return 'NOREPLY';
	    }
	}

	if ($caughtBy) {
	    if ($tell_obj) {
		$message = $tell_obj;
		&status("$caughtBy: <$who>->$target<  [$message] -> $result");
	    } else {
		&status("$caughtBy: <$who>  $message");
	    }

	    $questionCount++;
	}
    }

    if (defined $result) {
	if ($msgType =~ /public/) {
	    if ($target eq $who) {
		&performSay($result) if ($result and not $blocked);
	    } else {
		my $r = "$who wants you to know: $result";
		&msg($target, $r);
		if ($who ne $target) {
		    &msg($who, "told $target about $tell_obj ($r)");
		}
		return 'NOREPLY';
	    }
	} else {		# not public
	    if ($who eq $target) { # to self
		&msg($who, $result);
	    } else {		# to someone else
		my $r;

		if (lc($who) eq lc($target)) {
		    &msg($target, $result);
		} else {
		    $r = "$who wants you to know: $result";
		    &msg($target, $r);
		    &msg($who, "told $target about $tell_obj ($r)");
		}
	    }
	}
    } else {			# not $caughtBy

	return "No authorization to teach" unless (IsFlag("t") eq "t");

	if (!getparam('allowUpdate')) {
	    return '';
	}

	$result = &doStatement($msgType, $holdMessage);

	if (($who eq 'NOREPLY')||($result eq 'NOREPLY')) { return ''; };

	return 'NOREPLY' if grep $_ eq $who, split /\s+/, $param{friendlyBots};

	if (defined $result) {
	    $caughtBy = "Statement";
	    if ($msgType =~ /public/) { 
		&say("OK, $who.") if $addressed;
	    } else { 
		&msg($who, "gotcha.");
	    }
	}

    }

    if ($addressed and not $caughtBy) {
#	&status("unparseable: $message");

	if ($msgType =~ /public/) { 
	    &say("$who: ".$confused[int(rand(@confused))]) if $addressed;
	} else {
	    &msg($who, $confused[int(rand(@confused))]);
	}
	return "NOPARSE";
    }
}
    
1;

