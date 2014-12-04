# infobot :: Kevin Lenzo & Patrick Cole   (c) 1997

use Socket;

sub srvConnect {
    my ($server, $port) = @_;
    my ($iaddr, $paddr, $proto);
    select(STDOUT);
    $| = 1;

    $iaddr  = inet_aton($server);
    $ip_num = inet_ntoa($iaddr);
    if (not $ip_num) {
	die "can't get the address of $server ($ip_num)!\n";
    }
    &status("Connecting to port $port of server $server ($ip_num)...");
    $paddr = sockaddr_in($port, $iaddr);
    $proto = getprotobyname('tcp');
    socket(SOCK, PF_INET, SOCK_STREAM, $proto) or die "socket failed: $!";
    $sockaddr = 'S n a4 x8';
    if ($param{'vhost_name'}) {
	my $hostname = $param{'vhost_name'};
	$this = pack($sockaddr, AF_INET,  0, inet_aton($hostname));
	&status("trying to bind as $hostname"); 
	bind(SOCK, $this) || die "bind: $!";
    }
    connect(SOCK, $paddr) or die "connect failed: $!";

    &status(" connected.");
}

sub procservmode {
    my ($server, $e, $f) = @_;
    my @parts = split (/ /, $f);
    $cnt=0;
    my $mode="";
    my $chan="";
    foreach (@parts) {
	if ($cnt == 0) {
	    $chan = $_;
	} else {
	    $mode .= $_;
	    $mode .= " ";
	}
	++$cnt;
    }
    chop $mode;
    $mode=~s/://;

    if ($server eq $chan) {
	if ($params{ansi_control}) {
	    &status(">>> $b$server$ob sets user mode: $b$mode$ob");
	} else {
	    &status(">>> $server sets mode: $mode");
	}

    } else {
	if ($params{ansi_control}) {
	    &status(">>> $b$server$ob/$b$chan$ob sets server mode: $b$mode$ob");
	} else {
	    &status(">>> $server/$chan sets mode: $mode");
	}
    }
}

### added by the xk.
# Usage: &nickServ(text);
sub nickServ {
    my $text	= shift;
    return if !defined $param{'nickServ_pass'};

    &status("NickServ: <= '$text'");

    if ($text =~ /Password incorrect/i) {
	&status("NickServ: ** identify failed.");
	return;
    }

    if ($text =~ /Password accepted/i) {
	&status("NickServ: ** identify success.");
	return;
    }

    if ($nickserv_try) { return; }

    &status("NickServ: => Identifying to NickServ.");
    rawout("PRIVMSG NickServ :IDENTIFY $param{'nickServ_pass'}");
    $nickserv_try++;
}

###
# Usage: &chanServ(text);
sub chanServ {
    my $text	= shift;
#    return if !defined $param{'chanServ_ops'};
    &status("chanServ_ops => '$param{'chanServ_ops'}'.");

    &status("ChanServ: <= '$text'");

    # to be continued...
    return;
}
# end of xk functions.

sub procmode {
    my ($nick, $user, $host, $e, $f) = @_;
    my @parts = split (/ /, $f);
    $cnt=0;
    my $mode="";
    my $chan="";
    foreach (@parts) {
	if ($cnt == 0) {
	    $chan = $_;
	} else {
	    $mode .= $_;
	    $mode .= " ";
	}
	++$cnt;
    }
    $mode =~ s/\s$//;


    if ($param{ansi_control}) {
	&status(">>> mode/$b$chan$ob [$b$mode$ob] by $b$nick$ob");
    } else {
	&status(">>> mode/$chan [$mode] by $nick");
    }

    if ($chan =~ /^[\#\&]/) {
	my ($modes, $targets) = ($mode =~ /^(\S+)\s+(.*)/);
	my @m = ($modes =~ /([+-]*\w)/g);
	my @t = split /\s+/, $targets;
	if (@m != @t) {
	    &status("number of modes does not match number of targets: @m / @t");
	} else {
	    my $parity = 0;
	    foreach (0..$#m) {
		if ($m[$_] =~ s/^([-+])//) {
		    $sign = $1;
		    if ($sign eq '-') {
			$parity = -1;
		    } else {
			$parity = 1;
		    }
		}
		if ($parity == 0) {
		    &status("zero parity mode change... ignored");
		} else {
		    if ($parity > 0) {
			$channels{$chan}{$m}{$t} = '+';
		    } else {
			delete $channels{$chan}{$mode}{$t};
		    }
		}
	    }
	}
    }
}

sub entryEvt {
    my ($nick, $user, $host, $type, $chan) = @_;
    if ($type=~/PART/) {
	if ($param{ansi_control}) {
	    &status(">>> $nick ($user\@$host) has left $chan");
	} else {
	    &status(">>> $nick ($user\@$host) has left $chan");
	}
    } elsif ($type=~/JOIN/) {
	if ($netsplit) {
	    foreach (keys(%snick)) {
		if ($nick eq $snick{$_}) {
		    @be = split (/ /);
		    if ($param{ansi_control}) {
			&status(">>> ${b}Netjoined$ob: $be[0] $be[1]");
		    } else {
			&status(">>> ${b}Netjoined$ob: $be[0] $be[1]");
		    }
		    $netsplit--;
		}
	    }
	}
	if ($param{ansi_control}) {
	    &status(">>> $nick ($user\@$host) has joined $chan");
	} else {
	    &status(">>> $nick ($user\@$host) has joined $chan");
	}
  $nickMsg=&checkNickMessages($nick."/".$chan);
  if ($nickMsg=~/.+/) {
      $nickMsg =~ s/(.{0,300}(?:\s|$))/$1\n/g;
      @nickMsgPart = split /\n/, $nickMsg;
      &rawout("PRIVMSG $chan :$nick, @nickMsgPart[0]");
      &status("on $chan told $nick @nickMsgPart[0]");
      shift(@nickMsgPart);
      foreach(@nickMsgPart) {
          &rawout("PRIVMSG $chan :$_");
          &status("on $chan told $nick $_");
      }
  }

    } elsif ($type=~/QUIT/) {
	$chan=~s/\r//;
	if ($chan=~/^([\d\w\_\-\/]+\.[\.\d\w\_\-\/]+)\s([\d\w\_\-\/]+\.[\.\d\w\_\-\/]+)$/) {
	    $i=0;
	    while (0 and ($i < $netsplit || !$netsplit)) {
#	    while ($i < $netsplit || !$netsplit) {
		$i++;
		if (($prevsplit1{$i} ne $2) && ($prevsplit2{$i} ne $1)) {
		    &status("Netsplit: $2 split from $1");
		    $netsplit++;
		    $prevsplit1{$netsplit} = $2;
		    $prevsplit2{$netsplit} = $1;
		    $snick{"$2 $1"}=$nick;
		    $schan{"$2 $1"}=$chan;
		}
	    }
	} else {
	    if ($param{ansi_control}) {
		&status(">>> $b$nick$ob has signed off IRC ($b$chan$ob)");
	    } else {
		&status(">>> $b$nick$ob has signed off IRC ($b$chan$ob)");
	    }
	}
    } elsif ($type=~/NICK/) {
	if ($param{ansi_control}) {
	    &status(">>> ".c($nick,'bold green').
		    " materializes into ".c($chan,'bold green'));
       } else {
           &status(">>> $b$nick$ob materializes into $b$chan$ob");
       }
    }
}

sub procevent {
    my ($nick, $user, $host, $type, $chan, $msg) = @_;

    # support global $nuh, $who
    $nuh = "$nick!$user\@$host";

    if ($type=~/PRIVMSG/) {
	if ($chan =~ /^$ischan/) {
	    ## It's a public message on the channel##
	    $chan =~ tr/A-Z/a-z/;

	    if ($msg =~ /\001(.*)\001/ && $msg !~ /ACTION/) {
		#### Client To Client Protocol ####
		parsectcp($nick, $user, $host, $1, $chan);
	    } elsif ($msg !~ /ACTION\s(.+)/) {
		#### Public Channel Message ####
    $nickMsg=&checkNickMessages($nick."/".$chan);
    if ($nickMsg=~/.+/) {
        $nickMsg =~ s/(.{0,300}(?:\s|$))/$1\n/g;
        @nickMsgPart = split /\n/, $nickMsg;
        &rawout("PRIVMSG $chan :$nick, @nickMsgPart[0]");
        &status("on $chan told $nick @nickMsgPart[0]");
        shift(@nickMsgPart);
        foreach(@nickMsgPart) {
            &rawout("PRIVMSG $chan :$_");
            &status("on $chan told $nick $_");
        }
    }
 		&IrcMsgHook('public', $chan, $nick, $msg);
	    } else {
		#### Public Action ####
		&IrcActionHook($nick, $chan, $1);
	    }
	} else {
	    ## Is Private ##
	    if ($msg=~/\001(.*)\001/) {
		#### Client To Client Protocol ####
		parsectcp($nick, $user, $host, $1, $chan);
	    } else {
		#### Is a Private Message ##
		&IrcMsgHook('private', $chan, $nick, $msg);
	    }
	}
    } elsif ($type=~/NOTICE/) {
	if ($chan =~ /^$ischan/) {
	    $chan =~ tr/A-Z/a-z/;
	    if ($msg !~ /ACTION (.*)/) {
		&status("-$nick/$chan- $msg");
	    } else {
		&status("* $nick/$chan $1");
	    }
	} else {
	    if ($msg=~/\001([A-Z]*)\s(.*)\001/) {
		ctcpReplyParse($nick, $user, $host, $1, $2);
	    } else {
		&status("-$nick($user\@$host)- $msg");
	    }
	}
    }
}

sub servmsg {
    my $msg=$_[0];
    my ($ucount, $uc) = (0, 0);
    if ($msg=~/^001/) {
# joinChan(split/\s+/, $param{'join_channels'});
# Line in infobot.config:
#   join_channels #chan,key #chan_with_no_key
#
# since , is not allowed in channels, we'll use it to specify keys
# without breaking current join_channels format
	for (split /\s+/, $param{'join_channels'}) {
            # if it's a keyed chan, replace the comma with a space so it'll
	    # work as per the RFC (i.e. JOIN #chan key)
	    s/,/ /; 
	    joinChan ($_);
	}
 	$nicktries=0;
    } elsif ($msg=~/^NOTICE ($ident) :(.*)/) {
	serverNotice($1,$2);
    } elsif ($msg=~/^332 $ident ($ischan) :(.*)/) {
	if ($param{ansi_control}) {
	    &status(">>> topic for $b$1$ob: $2");
	} else {
	    &status(">>> topic for $1: $2");
	}
    } elsif ($msg=~/^333 $ident $ischan (.*) (.*)$/) {
       if ($param{ansi_control}) {
           &status(">>> set by $b$1$ob at $b$2$ob");
       } else {
           &status(">>> set by $1 at $2");
       }
    } elsif ($msg=~/^433/) {
	++$nicktries;
	if (length($param{wantNick}) > 9) {
	    $ident = chop $param{wantNick};
	    $ident .= $nicktries;
	} else {
	    $ident = $param{wantNick}.$nicktries;
	}
	if ($param{'opername'}) {
	    &rawout("OPER $param{opername} $param{operpass}");
	}
	$param{nick} = $ident;
	&status("*** Nickname $param{wantNick} in use, trying $ident");
	rawout("NICK $ident");

    } elsif ($msg=~/[0-9]+ $ident . ($ischan) :(.*)/) {
	my ($chan, $users) = ($1, $2);
	&status("NAMES $chan: $users");
	my $u;
	foreach $u (split /\s+/, $users) {
	    if (s/\@//) {
		$channels{$chan}{o}{$u}++;
	    }
	    if (s/\+//) {
		$channels{$chan}{v}{$u}++;
	    }
	}
    } elsif ($msg=~/[0-9]{3} $ident(\s$ischan)*?\s:(.*)/) {
	&status("$2");
    }
}

sub serverNotice {
    ($type, $msg) = @_;
    if ($type=~/AUTH/) {
	&status("!$param{server}! $msg");
    } else {
	$msg =~ s/\*\*\* Notice -- //;
	&status("-!$param{server}!- $msg");
    }
}

sub OperWall {
    my ($nick, $msg) = @_;
    $msg=~s/\*\*\* Notice -- //;
    &status("[wallop($nick)] $msg");
}

sub prockick {
    my ($kicker, $chan, $knick, $why) = @_;

     if ($param{ansi_control}) {
	 &status(">>> $b$knick$ob was kicked off $b$chan$ob by $b$kicker$ob ($b$why$ob)");
     } else {
	 &status(">>> $b$knick$ob was kicked off $b$chan$ob by $b$kicker$ob ($b$why$ob)");
     }
    if ($knick eq $ident) {
	&status("SELF attempting to rejoin lost channel $chan");
	&joinChan($chan);
    }
}

sub prockill {
    my ($killer, $knick, $kserv, $killnick, $why) = @_;
    if ($knick eq $ident) {
	&status("KILLED by $killnick ($why)");	
    } else {
	&status("KILL $knick by $killnick ($why)");
    }
}

sub fhbits {
    local (@fhlist) = split(' ',$_[0]);
    local ($bits);
    for (@fhlist) {
	vec($bits,fileno($_),1) = 1;
    }
    $bits;
}

sub irc {
    local ($rin, $rout);
    local ($buf, $line);

    $nicktries=0;
    $connected=1;
    while ($connected) {
	srvConnect($param{server}, $param{port});

        if ($param{server_pass}) { # ksiero++
            rawout("PASS $param{server_pass}");
        }

	rawout("NICK $param{wantNick}");
	rawout("USER $param{ircuser} $param{ident} $param{server} :$param{realname}");
	if ($param{operator}) {
	    rawout("OPER $param{operName} $param{operPass}\n");
	}
	$param{nick} = $param{wantNick};
	$ident = $param{wantNick};

	$/ = "\015" if $^O eq "MacOS";

	$rin = fhbits('SOCK');
	while (1) {
	    ($nfound,$timeleft) = select($rout=$rin, undef, undef, 0);
	    if ($rout & SOCK) {
		if (sysread(SOCK,$buf,1) <= 0) {
		    last;
		}
		if ($buf=~/\n/) {
		    $line.=$buf;
		    sparse($line);
		    undef $line;
		} else {
		    $line.=$buf;
		}
	    }
	}
    }
}

#Corion++
# Fixed baaaad backdor in server parsing (regexes are a bitch :( )
# /msg infobot :a@b.c PRIVMSG #channel seen <nick>
# can be used to flood a channel witout getting ever caught !

# Affected lines were
# PRIVMSG / NOTICE / TOPIC / KICK

sub sparse {
    $_ = $_[0];
    s/\r//;

    if (/^PING :(\S+)/) {	# Pings are important
	rawout("PONG :$1");
	&status("SELF replied to server PING") if $param{VERBOSITY} > 2;
    } elsif (/^:\S+ ([\d]{3} .*)/) {
	servmsg($1);
    } elsif (/^:([\d\w\_\-\/]+\.[\.\d\w\_\-\/]+) NOTICE ($ident) :(.*)/) {
	&status("\-\[$1\]- $3");
    } elsif (/^NOTICE (.*) :(.*)/) {
	serverNotice($1, $2);
    } elsif (/^:NickServ!s\@NickServ NOTICE \S+ :(.*)/i) {
	&nickServ($1);		# added by the xk.
    } elsif (/^:ChanServ!s\@ChanServ NOTICE \S+ :(.*)/i) {
	&chanServ($1);		# added by the xk.
    } elsif (/^:(\S+)!(\S+)@(\S+)\s(PRIVMSG|NOTICE)\s([\#\&]?\S+)\s:(.*)/) {
	procevent($1,$2,$3,$4,$5,$6);
    } elsif (/^:(\S+)!(\S+)@(\S+)\s(PART|JOIN|NICK|QUIT)\s:?(.*)/) {
	entryEvt($1,$2,$3,$4,$5);
    } elsif (/^:(\S+)!(\S+)@(\S+)\s(INVITE)\s:?(\S+) (.*)/) {
	&joinChan($6);
    } elsif (/^:(.*) WALLOPS :(.*)/) {
	OperWall($1,$2);
    } elsif (/^:(.*)!(.*)@(.*) (MODE) (.*)/) {
	procmode($1,$2,$3,$4,$5);
    } elsif (/^:(.*) (MODE) (.*)/) {
	procservmode($1,$2,$3);
    } elsif (/^:(\S+)!(?:\S+)@(?:\S+) KICK ((\#|&).+) (.*) :(.*)/) {
	prockick($1,$2,$4,$5);
    } elsif (/^ERROR :(.*)/) {
	&status("ERROR $1");
    } elsif (/^:([^! ]+)!\S+@\S+ TOPIC (\#.+) :(.*)/) {
	if ($param{ansi_control}) {
	    &status(">>> $1$b\[$ob$2$b\]$ob set the topic: $3");
	} else {
	    &status(">>> $1\[$2\] set the topic: $3");
	}
    } elsif (/^:(\S+)!\S+@\S+ KILL (.*) :(.*)!(.*) \((.*)\)/) {
	prockill($1,$2,$3,$4,$5);
    } else {
	&status("UNKNOWN $_");
    }
#Corion--
}

	     1;
