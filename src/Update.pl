
# infobot :: Kevin Lenzo   (c) 1997

sub update {
    my($lhs, $verb, $rhs) = @_;
    my($reply) = $lhs;

    $lhs =~ s/^\s*=?//;		# handle dcc =oznoid and stuff
    $lhs =~ s/^i (heard|think) //i;
    $lhs =~ s/^some(one|1|body) said //i;
    $lhs =~ s/ +/ /g;

    # this really needs cleaning up
    if ($verb eq "is") {
	$also = ($rhs =~ s/^also //i);

	my $also_or = ($also and $rhs =~ s/\s*\|\s*//);

	if ($exists = &get("is", $lhs."/".&channel())) { 
	    chomp $exists;

	    if ($exists eq $rhs and not $main::googling) {
		if ($msgType =~ /public/) {
		    &performSay("i already had it that way, $who.");
		} else {
		    &msg($who, "it already was $rhs");
		}
		return 'NOREPLY';
	    }

	    $skipReply = 0;	 
	    if ($also) {
		if ($also_or) {
		    $rhs = $exists . '|'.$rhs;
		} else {
		    if ($exists ne $rhs) {
			$rhs = $exists .' or '.$rhs;
		    }
		}
		    if (length($rhs) > getparam('maxDataSize')) {
			if ($msgType =~ /public/) {
			    if ($addressed) {
				if (rand() > 0.5) {
				    &performSay("that is too long, ".$who);
				} else {
				    &performSay("i'm sorry, but that's too long, $who");
				} 
			    }
			} else {
			    &msg($who, "The text is too long");
			}
			return 'NOREPLY';
		}
		if ($msgType =~ /public/) {
		    &performSay("okay, $who.");
		} else {
		    &msg($who, "okay.");
		}

		$updateCount++;
		&status("update: <$who> \'$lhs/".&channel()." =is=> $rhs\'; was \'$exists\'");
		&set("is", $lhs."/".&channel(), $rhs);
	    } else {		# not "also"
		if (($correction_plausible == 0) && ($exists ne $rhs)) {
		    if ($addressed) {
			if (not $main::googling) {
			    if ($msgType =~ /public/) {
				&performSay("...but $lhs is $exists...");
			    } else { 
				&msg($who, "...but $lhs is $exists..");
			    }
			    &status("FAILED update: <$who> \'$lhs/".&channel()." =$verb=> $rhs\'");
			}
		    } else {
			&status("FAILED update: <$who> \'$lhs/".&channel()." =$verb=> $rhs\' (not addressed, no reply)");
			# we were not addressed, so just
			# ignore it.  
			return 'NOREPLY';
		    }
		} else {
		    if (IsFlag("m") ne "m") {
			performReply("You have no access to change factoids");
			return 'NOREPLY';
		    }
		    if ($msgType =~ /public/) {
			&performSay("okay, $who.");
		    } else {
			&msg($who, "okay.");
		    }
		    $updateCount++;
		    &status("update: <$who> '$lhs/".&channel()." =is=> $rhs\'; was \'$exists\'");
		    &set("is", $lhs."/".&channel(), $rhs);
		}
	    }
	    $reply = 'NOREPLY';

	} else {
	    &status("enter: <$who> $lhs/".&channel()." =$verb=> $rhs");
	    $updateCount++; $factoidCount++;
	    if ($factoidCount == 31337) { # particular count
		$mySaveChannel = &channel();
		&say("That would be factoid $factoidCount given on $mySaveChannel by $who.");
		&status("FACTOID NUMBER $factoidCount on channel $mySaveChannel by $who.");
		&say("woohoo!");
		&channel($mySaveChannel);
	    }
	    &set("is", $lhs."/".&channel(), $rhs);
	    $is{"theCount"}++; 
	}

    } else {			# 'is' failed
	if ($verb eq "are") {
	    $also = ($rhs =~ s/^also //i);
	    if ($exists = &get("are", $lhs."/".&channel())) {
		if ($also) {	
		    if ($exists ne $rhs) {
			$rhs = $exists .' or '.$rhs;
		    }
		    if ($msgType =~ /public/) {
			&performSay("okay, $who.") unless $rhs eq $exists;
		    } else {
			&msg($who, "okay.");
		    }
		    $updateCount++;
		    &status("update: <$who> \'$lhs/".&channel()." =are=> $rhs\'; was \'$exists\'");
		    &set("are", $lhs."/".&channel(), $rhs);
		} else {	# not 'also'
		    if (($correction_plausible == 0) && ($exists ne $rhs)) {
			if ($addressed) {
			    &status("FAILED update: \'$lhs/".&channel()." =$verb=> $rhs\'");
			    if ($msgType =~ /public/) {
				&performSay("...but $lhs is $exists...");
			    } else { 
				&msg($who, "...but $lhs is $exists..");
			    }
			} else {
			    &status("FAILED update: $lhs/".&channel()." $verb $rhs (not addressed, no reply)");
			    # we were not addressed, so just
			    # ignore it.  
			    return 'NOREPLY';
			}
			if ($msgType =~ /public/) {
			    &performSay("...but $lhs are $exists...");
			} else {
			    &msg($who, "...but $lhs are $exists...");
			}
		    } else {
			if ($msgType =~ /public/) {
			    &performSay("okay, $who.") unless $rhs eq $exists;
			} else {
			    &msg($who, "okay.") 
				unless grep $_ eq $who, split /\s+/, $param{friendlyBots};
			}
			$updateCount++;
			&status("update: <$who> \'$lhs/".&channel()." =are=> $rhs\'; was \'$exists\'");
			&set("are", $lhs."/".&channel(), $rhs);
		    }
		    $reply = 'NOREPLY';
		} 
	    } else {
		&status("enter: <$who> $lhs/".&channel()." =are=> $rhs");
		$updateCount++;
		&set("are", $lhs."/".&channel(), $rhs);
		$are{"theCount"}++;
	    }
	}
    }

    $lhs .= " $verb $rhs";
    if ($reply ne 'NOREPLY') {	
	$reply = $lhs;
    }

    return $reply;
}

# ---

1;
