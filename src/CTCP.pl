# infobot (c) 1997 Lenzo

sub parsectcp {
    my ($nick, $user, $host, $type, $dest) = @_;
    &status("CTCP $type $dest request from $nick");
    if ($type =~ /^version/i) {
	ctcpreply($nick, "VERSION", $version);
    } elsif ($type =~ /^(echo|ping) ?(.*)/i) { 
	rawout("NOTICE $nick :\001PING $2\001");
#	ctcpreply($nick, uc($1)." $2");
    } elsif ($type =~ /^DCC /) {
	&status("DCC attempt from $who (not supported, ignored)");
    }
}

sub ctcpReplyParse {
    my ($nick, $user, $host, $type, $reply) = @_;
    &status("CTCP $type reply from $nick: $reply");
}


sub ctcpreply {
    my ($rnick, $type, $reply) = @_;
    rawout("NOTICE $rnick :\001$type $reply\001");
}

1;
