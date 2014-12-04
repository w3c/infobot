# infobot :: Kevin Lenzo  (c) 1997

## 
##  doQuestion --
## 
##	decide if $in is a query, and if so, return its value.
##	otherwise return null. 
##

sub doQuestion {
    local ($msgType, $qmsg, $msgFilter) = @_;
    chomp $qmsg;

    $finalQMark = $qmsg =~ s/\?+\s*$//;

    $questionWord = "";		# this is shared for a reason
    $input_message_length = length($qmsg);

    my($locWho) = $who;

    $locWho =~ tr/A-Z/a-z/;
    $locWho =~ s/^=//;

    my ($origIn) = $qmsg;
    $finalQMark += $qmsg =~ s/\?\s*$//;

    # convert to canonical reference form
    $qmsg = &normquery($qmsg);
    $qmsg = &switchPerson($qmsg);

    # where is x at?
    $qmsg =~ s/\s+at\s*(\?*)$/$1/;

    $qmsg = " $qmsg ";

    my $qregex = join '|', @qWord;

    # what's whats => what is; who'?s => who is, etc
    $qmsg =~ s/ ($qregex)\'?s / $1 is /i;
    if ($qmsg =~ s/\s+($qregex)\s+//i) { # check for question word
	$questionWord = lc($1);
    }

    $qmsg =~ s/^\s+//;
    $qmsg =~ s/\s+$//;

    if (($questionWord eq "") && ($finalQMark > 0) 
	&& ($addressed or $continuity)) {
	$questionWord = "where";
    }

    # ok, here's where we try to actually get it
    $answer = &getReply($msgType, $qmsg, $msgFilter);
    
    return 'NOREPLY' if ($answer eq 'NOREPLY');

    if (($param{'addressing'} eq 'REQUIRE') && not ($addressed or $continuity)) {
	return 'NOREPLY';
    }

    if (not defined $answer) {
	$answer = &math($qmsg); # clean up the argument syntax for this later
    }

    if ($questionWord ne "" or $finalQMark) {
	# if it has not been explicitly marked as a question
	if ($addressed && (not defined $answer)) {
	    # and we're addressed and so far the result is null
	    &status("notfound: <$who> $origIn :: $qmsg");

	    return 'NOREPLY' if $infobots{$nuh};
	    my $reply;

	    # generate some random i-don't-know reply.
	    if ($target ne $who and $target ne $talkchannel) {
		$target = $who;	# set the target back to the originator
		$reply = "I don't know about '$qmsg'";
	    } else {
		$reply = $dunno[int(rand(@dunno))];
	    }

	    if (rand() > 0.5) {
		$reply = "$locWho: $reply";
	    } else {
		$reply = "$reply, $locWho";
	    }

	    &askFriendlyBots($qmsg);

	    # and set the result
	    $answer = $reply;
	} else {
	    # the item was found
	    if ($answer ne "") {
		&status("match: $qmsg => $answer");
	    }
	}
    }

    return $answer;
}

sub timeToString {
	my $upTime = $_[0];
	$upTime = (time()-$startTime);
	my $upDays = int($upTime / (60*60*24));
	my $upString = "";
	if ($upDays > 0) {
		$upString .= $upDays." day";
		$upString .= "s" if ($upDays > 1);
		$upString .=", ";
	}
	$upTime -= $upDays * 60*60*24;
	my $upHours = int($upTime / (60*60));
	if ($upHours > 0) {
		$upString .= $upHours." hour";
		$upString .= "s" if ($upHours > 1);
		$upString .=", ";
	}
	$upTime -= $upHours *60*60;
	my $upMinutes = int($upTime / 60);
	if ($upMinutes > 0) {
		$upString .= $upMinutes." minute";
		$upString .= "s" if ($upMinutes > 1);
		$upString .=", ";
	}
	$upTime -= $upMinutes * 60;
	my $upSeconds = $upTime;
	$upString .= $upSeconds." second";
	$upString .= "s" if ($upSeconds != 1);
	$upString;
}

1;
