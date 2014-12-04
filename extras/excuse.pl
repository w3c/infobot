#!/usr/bin/perl

# excuse.pl - serve up bofh-style excuses
#
# lenzo@cs.cmu.edu -- fixed return codes
# updated 990818 08:31:11, bobby@bofh.dk
#

BEGIN {
    eval "use Net::Telnet";
    $no_excuse++ if ($@) ;
}

sub excuse {
    my $host = "bofh.engr.wisc.edu";
    my $port = 666;
    my $t = Net::Telnet->new(Host => $host,
			     Errmode => "return",
			     Port => $port);  
    if (defined $t) {
	$t->waitfor("/Your excuse is: /"); 
	my $reply = $t->get;
	return $reply;
    } else { 
	return "The server at $host (port $port) appears to be down.";
    }
}

1;
