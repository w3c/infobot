
# infobot :: Kevin Lenzo  (c) 1997

# Tidied up ?

sub IrcActionHook {
    my ($who, $channel, $message) = @_;

    &channel($channel);
    &process($who, 'public action', $message);

    if ($msgType =~ /public/) {
	&status("<$who/$channel> $origMessage");
    } else {
	&status("[$who] $origMessage");
    }
}

sub IrcMsgHook {
    my ($type, $channel, $who, $message) = @_;

    if ($type =~ /public/i)	{
	&channel($channel);
	&process($who, $type, $message);
	&status("<$who/$channel> $origMessage");
    }

    if ($type =~ /private/i) {
	if (($params{'mode'} eq 'IRC') && ($who eq $prevwho)) {
	    $delay = time() - $prevtime;
	    $prevcount++;

	    if (0 and $delay < 1) {
		# this is where to put people on ignore if they flood you
		if (IsFlag("o") ne "o") {
		    &msg($who, "You will be ignored -- flood detected.");
		    &postInc(ignore => $who);
		    &log_line("ignoring ".$who);
		    return;
		}
	    }
	    return if (($message eq $prevmsg) && ($delay < 10));
	} else {
	    $prevcount = 0;
	    $firsttime = time;
	}

	$prevtime = time unless ($message eq $prevmsg);
	$prevmsg = $message;
	$prevwho = $who;
	&process($who, $type, $message);
	&status("[$who] $origMessage");
    }
    return;
}

sub hook_dcc_request {
    my($type, $text) = @_;
    if ($type =~ /chat/i) {
	&status("received dcc chat request from $who  :  $text");
	my($locWho) = $who;
	$locWho =~ tr/A-Z/a-z/;
	$locWho =~ s/\W//;
	&docommand("dcc chat ".$who);
	&msg('='.$who, "Hello, ".$who);
    }

    return '';
}

sub hook_dcc_chat {
    my($locWho, $message)=@_;
    $msgType = "dcc_chat";
    my($saveWho) = $who;

    $who = "=".$who;
    &process($who, $msgType, $message);
    $who = $saveWho;
    return '';

}

1;
