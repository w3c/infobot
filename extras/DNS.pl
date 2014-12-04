
# infobot :: Kevin Lenzo  (c) 1997

# once again, thanks to Patrick Cole

#use POSIX;
use Socket;

sub REAPER {
	$SIG{CHLD} = \&REAPER;	# loathe sysV
	$waitedpid = wait;
}

$SIG{CHLD} = \&REAPER;
$DNS_CACHE_EXPIRE_TIME = 7*24*60*60;

sub DNS {
    my $in = $_[0];
    my($match, $x, $y, $result);

    if (($DNS_CACHE{$in}) && ((time()-$DNS_TIME_CACHE{$in}) < $DNS_CACHE_EXPIRE_TIME)) {
	return $DNS_CACHE{$in};
    }

    if (!defined($pid = fork)) {
	return "no luck, $safeWho";
    } elsif ($pid) {
	# parent
    } else {
	# child
	if ($in =~ /(\d+\.\d+\.\d+\.\d+)/) {
	    &status("DNS query by IP address: $in");
	    $match = $1;
	    $y = pack('C4', split(/\./, $match));
	    $x = (gethostbyaddr($y, &AF_INET));
	    if ($x !~ /^\s*$/) {
		$result = $match." is ".$x unless ($x =~ /^\s*$/);
	    } else {
		$result = "I can't seem to find that address in DNS";
	    }
	} else { 
	    &status("DNS query by name: $in");
	    $x = join('.',unpack('C4',(gethostbyname($in))[4]));
	    if ($x !~ /^\s*$/) {
		$result = $in." is ".$x;
	    } else {
		$result = "I can\'t find that machine name";
	    }
	}
	$DNS_TIME_CACHE{$in} = time();
	$DNS_CACHE{$in} = $result;

	if ($msgType eq 'public') {
	    &say($result);
	} else {
	    &msg($who, $result);
	}
	exit;			# bye child
    }
}

1;

__END__

=head1 NAME

DNS.pl - Look up hosts in DNS

=head1 PREREQUISITES

None.

=head1 PARAMETERS

allowDNS

=head1 PUBLIC INTERFACE

	nslookup|DNS [for] <host>

=head1 DESCRIPTION

Looks up DNS entries for the given host using
C<gethostbyaddr>/C<gethostbyname> calls.

=head1 AUTHORS

Kevin Lenzo
