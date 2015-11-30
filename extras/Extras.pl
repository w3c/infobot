# Infobot extensions inside the distribution.
# Local extensions go in myRoutines.pl

# Kevin A. Lenzo

sub Extras {
    # called after it decides if it's been addressed.
    # you have access tothe global variables here, 
    # which is bad, but anyway.

    if ($message =~ /^(tell|inform|notify|advise|alert|advise|enlighten|send\sword\sto|ping|remind|ask|beseech|beg|say) +([^ ,]+),? +((that|to|about) +)?(.+)/i) {
        return &storeNickMessage($2."/".&channel, "at ".&getGMTtimestamp.", $who said: $5");
    }
    # you can return 'NOREPLY' if you want to stop
    # processing past this point but don't want 
    # an answer. if you don't return NOREPLY, it
    # will let all the rest of the default processing
    # go to it. think of it as 'catching' the event.

    # $addressed is whether the infobot has been 
    #			named or, if a private or standalone
    #			context, addressed is always 'true'

    # $msgType can be 'public', 'private', maybe 'dcc_chat'

    # $who is the sender of the message

    # $message is the current state of the input, after
    #		  the addressing stuff stripped off the name

    # $origMessage is the text of the original message before
    #			  any normalization or processing

    # you have access to all the routines in urlIrc.pl too,
    # of course.

    # -- this section moved from Process.pl -- kl

    if ($addressed and $message =~ m|^\s*(.*?)\s+=~\s+s\/(.+?)\/(.*?)\/([a-z]*);?\s*$|) {
	# substitution: X =~ s/A/B/

	my ($X, $oldpiece, $newpiece, $flags) = ($1, $2, $3, $4);
	my $matched = 0;
	my $subst = 0;
	my $op = quotemeta($oldpiece);
	my $np = $newpiece;
	$X = lc($X);

	foreach $d ("is","are") {
	    if ($r = get($d, $X)) { 
		my $old = $r;
		$matched++;
		if ($r =~ s/$op/$np/i) {
		    if (length($r) > getparam('maxDataSize')) {
			if ($msgType =~ /private/) {
			    &msg($who, "That's too long, $who");
			} else {
			    &say("That's too long, $who");
			}
			return 'NOREPLY';
		    }
		    set($d, $X, $r);
		    &status("update: '$X =$d=> $r'; was '$old'");
		    $subst++;
		}
	    }
	}
	if ($matched) {
	    if ($subst) {
		if ($msgType =~ /private/) {
		    &msg($who, "OK, $who");
		} else {
		    &say("OK, $who");
		}
		return 'NOREPLY';
	    } else {
		if ($msgType =~ /private/) {
		    &msg($who, "That doesn't contain '$oldpiece'");
		} else {
		    &say("That doesn't contain '$oldpiece', $who");
		}
	    }
	} else {
	    if ($msgType =~ /private/) {
		&msg($who, "I didn't have anything matching '$X'");
	    } else {
		&say("I didn't have anything matching '$X', $who");
	    }
	}
	return 'NOREPLY';
    }				# end substitution

    if ($addressed and IsFlag("S")) {
	if ($message =~ s/^\s*say\s+(\S+)\s+(.*)//) {
	    &msg($1, $2);
	    &msg($who, "ok.");
	    return 'NOREPLY';
	}
    }

    if (($addressed) && ($message =~ /^\s*help\b/i)) {
	$message =~ s/^\s*help\s*//i;
	$message =~ s/\W+$//;
	&help($message);
	return 'NOREPLY';
    }

    if ($message =~ s/^forget\s+((a|an|the)\s+)?//i) {
	# cut off final punctuation
	$message =~ s/[.!?]+$//;
	#return 'no authorization to lobotomize';
	#}
	$k = &normquery($message);
	$k = lc($k);

	$found = 0;

	foreach $d ("is", "are") {
	    if ($r = get($d, $k."/".&channel())) { 
		if (IsFlag("r") ne "r") {
		    performReply("you have no access to remove factoids");
		    return 'NOREPLY';
		}
		$found = 1 ;
		&status("forget: <$who> $k/".&channel()." =$d=> $r");
		clear($d, $k."/".&channel()); 
		$factoidCount--;
	    }
	}
	if ($found == 1) {
	    if ($msgType !~ /public/) {
		&msg($who, "$who: I forgot $k");
	    } else {
		&say("$who: I forgot $k");
	    }
	    $l = $who; $l =~ s/^=//;
	    $updateCount++;
	    return 'NOREPLY';
	} else {
	    if ($msgType !~ /public/) {
		&msg($who, "I didn't have anything matching $k");
		return 'NOREPLY';
	    } else {
		if ($addressed > 0) {
		    &say("$who, I didn't have anything matching $k");
		    return 'NOREPLY';
		}
	    }
	}
    }				# end forget


    # Aldebaran++ !
    if (getparam("shutup") and $message =~ /^\s*wake\s*up\s*$/i ) {
	if ($msgType =~ /public/) {
	    if ($addressed) {
		if (rand() > 0.5) {
		    &performSay("Ok, ".$who.", I'll start talking.");
		    &status("Changing to Optional mode");
		    # Oh shit. - Simon
		    $chanopts{Channel()}->{'addressing'} = 'OPTIONAL';
		    return 'NOREPLY';
		} else {
		    &performSay(":O");
		    return 'NOREPLY';
		}
	    }
	} else {
	    &msg($who, "OK, I'll start talking.");
	    $param{'addressing'} = 'OPTIONAL';
	    &status("Changing to Optional mode");
	    return 'NOREPLY';
	}
    }				# end wake up

    if ($param{"shutup"} and $message =~ /^\s*shut\s*up\s*$/i ) {
	if ($msgType =~ /public/) {
	    if ($addressed) {
		if (rand() > 0.5) {
		    &performSay("Sorry, ".$who.", I'll keep my mouth shut. ");
		    $chanopts{Channel()}->{'addressing'} = 'REQUIRE';
		    &status("Changing to Require mode");
		    return 'NOREPLY';
		} else {
		    &performSay(":X");
		    return 'NOREPLY';
		}
	    } 
	} else {
	    &msg($who, "Sorry, I'll try to be quiet.");
	    $param{'addressing'} = 'REQUIRE';
	    &status("Changing to Require mode");
	    return 'NOREPLY';
	}
    }				# end shut up

    # -- from here down, 'tell' needs to be worked into the forkers.
    #    anything that just returns a value will be handled automatically,
    #    but anything that forks will require special handling.

    # mendel++
    if (getparam('zippy')) {
	if (my $resp = zippy::get($message)) {
	    return $resp;
	}
    }

    # Masque++
    my $triggers = getparam("purldoc_trigger") if getparam('purldoc');
    if (defined getparam('purldoc') and $message =~ s/^\s*$triggers\s+-?(\w+)/$1/) {
        return &purldoc();	
    }

    # from Chris Tessone: slashdot headlines
    # "slashdot" or "slashdot headlines"

    if (defined(getparam('slash')) and $message =~
	/^\s*slashdot( headlines)?\W*\s*$/) {
	my $headlines = &getslashdotheads();
	return $headlines;
    } 

    # internic or RIPE whois
    if (getparam('allowInternic')) {
	if ($message =~ /^(internic|ripe)(?: for)?\s+(\S+)$/i) {
	    my $where = $1;
	    my $what = $2;
	    &domain_summary($what, $where);

	    return 'NOREPLY';
	}
    }

    # currency exchanger, bobby@bofh.dk
    if( defined(getparam('exchange'))
       and   getparam('exchange')
       and ( $message =~ /^\s*(?:ex)?change\s+/i or $message =~ /^\s*currenc(?:ies|y) for\s/i )){

	&status("message($message)");
	my $response='';

	if ($pid = fork) {
	    # this takes some time, so fork.
	    return 'NOREPLY';
	}

	if ($message =~ /^\s*(?:ex)?change\s+([\d\.\,]+)\s+(\S+)\s+(?:into|to|for)\s+(\S+)/i) {
	    my($Amount,$From,$To) = ($1,$2,$3);
	    $From = uc $From; $To = uc $To;
	    &status("calling exchange($From, $To, $Amount) ...");
	    $response = &exchange($From, $To, $Amount);
	# Change Finland, purl!  No no.  How about 'currency for'.
	# } elsif( $message =~ /^\s*(?:ex)?change ([\w\s]+)/) {
	} elsif( $message =~ /^\s*currenc(?:ies|y) for\s(?:the\s)?([\w\s]+)/i ) {
	    # looking up the currency for a country
	    my $Country = $1;
	    &status("calling exchange($Country) ...");
	    $response = &exchange($Country);
	} else {
	    $response = "that doesn't look right";
	}

	&status("exchange got response($response)");

	if($response =~ /^EXCHANGE: \S*/) {
	    &status($response);
	} elsif ($msgType eq 'public') {
	    &say("$who: $response");
	} else{
	    &msg($who, $response);
	}

	# exit the child or it gets weird
	exit 0;
    }				# end excange

    # Jonathan Feinberg's babel-bot  -- jdf++
    if (defined getparam('babel') && 
	(1 or $addressed) && 
	$message =~ m{
	    ^\s*
		(?:babel(?:fish)?|x|xlate|translate)
		    \s+
			(to|from) # direction of translation (through)
			    \s+
				($babel::lang_regex)\w*	# which language?
				    \s*
					(.+) # The phrase to be translated
					}xoi) {           
	my $whom = $who;	# building a closure, need lexical
	my $callback = $msgType eq 'public' ? 
	    sub{say("$who: $_[0]")} : sub{msg($who, $_[0])};
	&babel::forking_babelfish(lc $1, lc $2, $3, $callback);
	return 'NOREPLY';
    }				# end babel

    # insult server. patch thanks to michael@limit.org
    if (getparam('insult') and ($message =~ /^\s*insult (.*)\s*$/)) {
	my $person = $1;
	my $language = "english";
	# Could have SWORN Simon patched this.  Simon++ for the fix, either way.  - 3Jul2K, Masque
	# > purl, insult mountain dew
	# <purl> mounta ist nichts aber ein gegorener Stapel des squishy Programmfehlerspit.
	# if ($person =~ s/ in \s*($babel::lang_regex)\w*\s*$//xi) {
	if ($person =~ s/ in \s*($babel::lang_regex)\w*\s*$//i) {
	    $language = lc($1);
	}
	$person = $who if $person =~ /^\s*me\s*$/i;

	my $insult = &insult();
	if ($person ne $who) {
	    $insult =~ s/^\s*You are/$person is/i;
	}

	if ($insult =~ /\S/) { 
	    if (getparam('babel') and ($language ne "english")) {
		my $whom = $who; # building a closure, need lexical
		my $callback = $msgType eq 'public' ? 
		    sub{say("$_[0]")} : sub{msg($whom, $_[0])};
		&babel::forking_babelfish("to", $language, $insult, $callback);
		return 'NOREPLY';
	    }
	} else {
	    $insult = "No luck, $who";
	}

	return $insult;
    }				# end insult

    if (getparam('weather') and ($message =~ /^\s*weather\s+(?:for\s+)?(.*?)\s*\?*\s*$/)) {
	my $code = $1;
	my $weath ;
	if ($code =~ /^[a-zA-Z][a-zA-Z0-9]{3,4}$/) {
	    $weath = &Weather::NOAA::get($code);
	} else {
	    $weath = "Try a 4-letter station code (see http://weather.noaa.gov/weather/curcond.html for locations and codes)";
	}
#	if ($msgType eq 'public') {
#	    &say("$who: $weath");
#	} else {
	&msg($who, $weath);
#	}
	return 'NOREPLY';
    }

    # This replaced 'metar'. Lotsa aviation stuff. Go look.
    if(defined(getparam('aviation') or defined(getparam('metar'))) and
       $message =~ /^(metar     |
		      taf       |
		      great[-\s]?circle | 
		      zulutime  |
		      tsd       |
		      airport   |
                      aviation)/xi) 
    {
      my $callback = $msgType eq 'public' ? 
	  sub{say("$who: $_[0]")} : sub{msg($who, $_[0])};
      &Aviation::get($message, $callback);
      return 'NOREPLY';
    }

# from Simon: google searching
# modified to fork and generally search by oznoid

    if(defined(getparam('wwwsearch')) and $message =~  
       /^\s*
       (?:search\s+)?
       ($W3Search::regex)
       \s+for\s+
       [\'\"]?(.*?)[\'\"]?
       \s*\?*\s*$
       /ix ) {
	my $callback = $msgType eq 'public' ? 
            sub{say("$who: $_[0]")} : sub{msg($who, $_[0])};
	&W3Search::forking_W3Search($1,$2,getparam('wwwsearch'), $callback);
	return 'NOREPLY';
    }

    # Adam Spiers' nickometer
    if ($message =~ /^\s*(?:lame|nick)-?o-?meter(?: for)? (\S+)/i) {
	my $term = $1;
	if (lc($term) eq 'me') {
	    $term = $who;
	}

	$term =~ s/\?+\s*//;

	my $percentage = &nickometer($term);

	if ($percentage =~ /NaN/) {
	    $percentage = "off the scale";
	} else {
	#    $percentage = sprintf("%0.4f", $percentage);
	    $percentage =~ s/\.0+$//;
	    $percentage .= '%';
	}

	if ($msgType eq 'public') {
	    &say("'$term' is $percentage lame, $who");
	} else {
	    &msg($who, "the 'lame nick-o-meter' reading for $term is $percentage, $who");
	}

	return 'NOREPLY';
    }				# end nick-o-meter

    if ($message =~ /^foldoc(?: for)?\s+(.*)/i) {
	my ($terms) = $1;
	$terms =~ s/\?\W*$//;

	my $key= $terms;
	$key =~ s/\s+$//;
	$key =~ s/^\s+//;
	$key =~ s/\W+/+/g;

	my $reply = "$terms may be sought in foldoc at http://wombat.doc.ic.ac.uk/foldoc/foldoc.cgi?query=$key";

	return $reply;
    }

    if ($message =~ /^(?:quote|stock price)(?: of| for)? ([A-Z]{1,6})\?*$/) {
	my $reply = "stock quotes for $1 may be sought at http://quote.yahoo.com/q?s=$1\&d=v1";

	return $reply;
    }

    if ($message =~ /^rot13\s+(.*)/i) {
	# rot13 it
	my $reply = $1;
	$reply =~ y/A-Za-z/N-ZA-Mn-za-m/;
	return $reply;
    }

    # search imdb
    if ($message =~ s/^\s*(search )?imdb (for )?//) {
	$check = $message;
	my $url = $message;

	# freeside++ for URL cleanup code

	my $date = "";
	if ($url =~ s/( \(\d+\))$//) { $date = $1; }
	$url =~ s/^(The|A|An|Les) (.*)/$2, $1/i;
	$url = "http://www.imdb.com/M/title-substring?title=$url$date&type=fuzzy";
	$url =~ s/ /+/g;
	$V = "-> "; $orig_lhs = $message; $theVerb= "is";
	return "$message can be found at $url";
    }				# end imdb

    if ($message =~ s/^\s*(search )?hyperarchive (for )?//) {
	$message =~ /\w+/;
	$check = $message;
	my $q = $message;
	$q =~ s/\W+//g;
	$result = "http://hyperarchive.lcs.mit.edu/cgi-bin/NewSearch?key=$q";
	$V = "-> "; $orig_lhs = $message; $theVerb= "is";
	return "$message may be sought at $result";
    }

    # websters
    if ($message =~ s/^\s*(search )?websters* (for )?//) {
	$message =~ /\w+/;
	$word = $&;
	$check = $message;
	my $q = $message;
	$q =~ s/\W+/+/g;
	$result = "http://work.ucsd.edu:5141/cgi-bin/http_webster?$word";
	$V = "-> "; $orig_lhs = $message; $theVerb= "is";
	return "$message may be sought at $result";
    }				# end websters

    # -- from Question

	# Now with INTENSE CASE INSENSITIVITY!  SUNDAY SUNDAY SUNDAY!
    if ($message =~ /^seen (\S+)/i) {
	my $person = $1;
	$person =~ s/\?*\s*$//;
	my $seen = &get(seen => lc $person);
	if ($seen) {
	    my ($when,$where,$what) = split /$;/, $seen;
	    my $howlong = time() - $when;
	    $when = localtime $when;

	    my $tstring = ($howlong % 60). " seconds ago";
	    $howlong = int($howlong / 60);

	    if ($howlong % 60) {
		$tstring = ($howlong % 60). " minutes and $tstring";
	    }
	    $howlong = int($howlong / 60);

	    if ($howlong % 24) {
		$tstring = ($howlong % 24). " hours, $tstring";
	    }
	    $howlong = int($howlong / 24);

	    if ($howlong % 365) {
		$tstring = ($howlong % 365). " days, $tstring";
	    }
	    $howlong = int($howlong / 365);
	    if ($howlong > 0) {
		$tstring = "$howlong years, $tstring";
	    }

	    if ($msgType =~ /public/) {
		&performSay("$person was last seen on $where $tstring, saying: $what [$when]");
	    } else {
		&msg($who, "$person was last seen on $where $tstring, saying: $what [$when]");
	    }
	    return 'NOREPLY';
	}

	if ($msgType =~ /public/) {
	    &performSay("I haven't seen '$person', $who");
	} else {
	    &msg($who,"I haven't seen '$person', $who");
	}
	return 'NOREPLY';
    }

    if ($message =~ /^\s*heya?,? /) {
	return 'NOREPLY' unless $addressed;
    }

    # Gotta be gender-neutral here... we're sensitive to purl's needs. :-)
    if ($message =~ /(good(\s+fuckin[\'g]?)?\s+(bo(t|y)|g([ui]|r+)rl))|(bot(\s|\-)?snack)/i) {
	&status("random praise [$msgType,$addressed]: $message");
	if ($msgType =~ /public/) {
            if ($addressed) {
		if (rand()  < .5)  {
		    &performSay("thanks $who :)");
		} else {
		    &performSay(":)");
		}
            }
	} else {
	    &msg($who, ":)");
	}
	return 'NOREPLY';
    }

    if ($addressed) {
	if ($message =~ /you (rock|rocks|rewl|rule|are so+ co+l)/) {
	    if ($msgType =~ /public/) {
		if (rand()  < .5)  {
		    &performSay("thanks $who :)");
		} else {
		    &performSay(":)");
		}
		return 'NOREPLY';
            } else {
		&msg($who, ":)");
            }
        }
	if ($message =~ /thank(s| you)/i) {
	    if ($msgType =~ /public/) {
		if (rand()  < .5)  {
		    &performSay($welcomes[int(rand(@welcomes))]." ".$who);
		} else {
		    &performSay($who.": ".$welcomes[int(rand(@welcomes))]);
		}
	    } else {
		if (rand()  < .5)  {
		    &msg($who, $welcomes[int(rand(@welcomes))].", ".$who);
		} else {
		    &msg($who, $welcomes[int(rand(@welcomes))]);
		}
	    }
	    return 'NOREPLY';
	}
    }

    if ($message =~ /^\s*(h(ello|i( there)?|owdy|ey|ola)|salut|bonjour|niihau|que\s*tal)( $param{nick})?\s*$/i) {
	if (!$addressed and rand() > 0.35) {
	    # 65% chance of replying to a random greeting when not addressed
	    return 'NOREPLY';
	}

	my($r) = $hello[int(rand(@hello))];
	if ($msgType =~ /public/) {
	    &performSay($r.", $who");
	} else {
	    &msg($who, $r);
	}
	return 'NOREPLY';
    }

    if (($message =~ /^\s*(?:nslookup|dns)(?: for)?\s+(\S+)$/i) and getparam('allowDNS')) {
	&status("DNS Lookup: $1");
	&DNS($1);
	return 'NOREPLY';
    }

    if (getparam('ispell') and ($message =~ s/^spell(ing)? (?:of |for )?//)) {
        &status("Spell: $message");
        &ispell($message);
        return 'NOREPLY';
    }

    if (($message =~ /^traceroute (\S+)$/i) and getparam("allowTraceroute")) {
	&status("traceroute to $1");
	&troute($1);
	return 'NOREPLY';
    }

    if ($message =~ /^crypt\s*\(\s*(\S+)\s*(?:,| )\s*(\S+)/) {
	my $cr = crypt($1, $2);
	if ($msgType =~ /private/) {
	    &msg($who, $cr);
	} else {
	    &performSay($cr);
	}
	return 'NOREPLY';
    }

    # may not want to cut off all: all i know is ... 
    # but for now seem mostly content-free

    if (getparam('allowLeave') =~ /$msgType/) {
	if ($message =~ /(leave|part) ((\#|\&)\S+)/i) {
	    if (IsFlag("o") or $addressed) {
		if (IsFlag("c") ne "c") {
		    &performReply("you don't have the channel flag");
		    return 'NOREPLY';
		}
		&channel($2);
		&performSay("goodbye, $who.");
		&status("PART $2 <$who>");
		&part($2);
		return 'NOREPLY';
	    }
	}
    }

    if ($msgType !~ /public/) {
	# accept only msgs leaves/joins
	my($ok_to_join);

        if ($message =~ /join ([\&\#]\S+)(?:\s+(\S+))?/i) {
            # Thanks to Eden Li (tile) for the channel key patch
            my($which, $key) = ($1, $2);
            $key = defined ($key) ? " $key" : "";
	    foreach $chan (split(/\s+/, $param{'allowed_channels'})) {
		if (lc($which) eq lc($chan)) {
		    $ok_to_join = $which . $key;
		    last;
		}
	    }
	    if (IsFlag("o")) { $ok_to_join = $which.$key };
	    if ($ok_to_join) {
		if (IsFlag("c") ne "c") {
		    &msg($who, "You don't have the channel flag");
		    return 'NOREPLY';
		}
		joinChan($ok_to_join);
		&status("JOIN $ok_to_join <$who>");
		&msg($who, "joining $ok_to_join") 
		    unless ($channel eq &channel());
		sleep(1);
				# my $temp = &channel();
				# &performSay("hello, $who.");
				# &channel($temp);
		return 'NOREPLY';
	    } else {
		&msg($who, "I am not allowed to join that channel.");
		return 'NOREPLY';
	    }
	}
    }

    if (IsFlag("s") eq "s") {
	if ($message =~ /^\s*(scan|search)\s*for\s+/i) {
	    if ($^O =~ /(win|mac)/i) {
		# can't fork
		&search($message);
	    } else {
		&status("forking off: $message");
		if (my $cpid = fork) {
		    # do nothing if we're the parent
		} else {
		    # we're the child
		    &search($message);
		    &status("child exit: $message");
		    exit 0;
		}
	    }
	    return 'NOREPLY';
	}
    }

    if (getparam('allowConv')) { 
	if ($message =~ /^\s*(asci*|chr) (\d+)\s*$/) {
	    $num = $2;
	    if ($num < 32) {
		$num += 64;
		$res = "^".chr($num);
	    } else {
		$res = chr($2);
	    }
	    if ($num == 0) { $res = "NULL"; } ;
	    return "ascii ".$2." is \'".$res."\'";
	}
	if ($message =~ /^\s*ord (.)\s*$/) {
	    $res = $1;
	    if (ord($res) < 32) {
		$res = chr(ord($res) + 64);
		if ($res eq chr(64)) {
		    $res = 'NULL';
		} else {
		    $res = '^'.$res;
		}
	    }
	    return "\'$res\' is ascii ".ord($1);
	}
    }

    if (getparam('plusplus')) {
	my $message2 = $message;

	# Fixes the "soandso? has neutral karma" bug. - Masque, 12Apr2k
	if ($message2 =~ s/^(?:karma|score)\s+(?:for\s+)?(.*?)\??$/$1/) {

	    # Some people prefer to have a factoid for their karma.
	    # This was the default behavior, pre-0.43.
	    $answer = &doQuestion($msgType, $message, $msgFilter);
	    return $answer if $answer;

	    $message2 = lc($message2);
	    $message2 =~ s/\s+/ /g;
&status("Karma string is currently \'$message2\'");
	    $message2 ||= "blank karma";
	    if ($message2 eq "me") {
		$message2 = lc($who);
	    }
	    my $karma = &get(plusplus => $message2);
	    if ($karma) {
		return "$message2 has karma of $karma";
	    } else {
		return "$message2 has neutral karma";
	    }
	}
    }

    if (($addressed) && ($message =~ /^statu?s/)) {
	$upString = &timeToString(time()-$startTime);
	$eTime = &get("is", "the qEpochDate");
	return "Since $setup_time, there have been $updateCount " 
	    . "modifications and $questionCount questions.  " 
		. "I have been awake for $upString this session, "
		    . "and currently reference $factoidCount factoids. "
			. "Addressing is in ".lc(getparam('addressing'))." mode.";
    }

    # divine added routine (boojum++)
    if ($message =~ /^(8-?ball|divine)\s+(.*)/i) {
        my %m8ball = ('original'  => 'shakes the psychic black sphere...',
                      'sarcastic' => 'shakes the psychic purple sphere...',
                      'userdef'   => 'shakes the psychic prismatic sphere...',
		      );

        if (!@m8_answers) {
	    my $answer_file  =  getparam('magic8_answers') || "$param{miscdir}/magic8.txt";

	    print "reading from $answer_file\n";

	    if (open MAGIC8, "<$answer_file") {
		while (<MAGIC8>) {
		    chomp;
		    push @m8_answers, $_;
		}
	    } else {
		@m8_answers = ('the Magic Ball is cloudy or missing a fact file.');
	    }
        }

        my ($type, $reply) = split /\s+=>\s+/, $m8_answers[rand(@m8_answers)];

        if ($msgType eq 'public') {
            &say("\cAACTION $m8ball{$type}\cA");
            &say("It says '$reply,' $who");
        } else {
            &msg($who, "\cAACTION $m8ball{$type} \cA");
            &msg($who, "It says '$reply'."); 
        }        
	return 'NOREPLY';
    }				# end divine

    # excuse server. bobby@bofh.dk
    if (getparam('excuse') and 
        ($message =~ /^\s*(?:give\s+(.*)\s+an\s+excuse|excuse\s*(.*))\s*$/)) {
	&status("excuses...");
        if ($1 ne 'in') {
	    $person = $1 || "me";
        } 

	$person = $who if $person =~ /^\s*me\s*$/i;

	&status("calling &excuse()...");
	my $excuse = "$who: " . &excuse();
	if ($person ne $who) {
	    $excuse =~ s/^\s*Your excuse is/$who\'s excuse is/i;
	}

	if (not $excuse) { 
	    $excuse = "No luck getting an excuse, $who";
	}

	if ($msgType eq 'public') {
	    &say($excuse);
	} else {
	    &msg($who, $excuse);
	}
	return 'NOREPLY';
    }				# end excuse

    return undef;
}


1;

