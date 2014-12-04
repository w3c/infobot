# infobot :: Kevin Lenzo   (c) 1997

use Socket;
use POSIX;

sub I_REAPER {
    $SIG{CHLD} = \&I_REAPER;
    $waitedpid = wait;
}

$SIG{CHLD} = \&I_REAPER;
$DOMAIN_CACHE_EXPIRE_TIME = 7*24*60*60;

sub domain_summary {
    # summarize the goo from internic

    my $item = $_[0];
    my @result;
    my $result;
    my @dom;

    if (($DOMAIN_CACHE{$item}) 
	&& ((time()-$DOMAIN_TIME_CACHE{$item}) < $DOMAIN_CACHE_EXPIRE_TIME)) {
	return $DOMAIN_CACHE{$item};
    }

    if (!defined($pid = fork)) {
	return "no luck, $safeWho";
    } elsif ($pid) {
	# parent
    } else {
	# child
	@dom = &domain_lookup($item);
	if ($dom[0] !~ /No match/) {
	    foreach (@dom) {
		print ;
		next if /^\s*$/;
		s/:/: /;
		s/\s+/ /g;
		next if /^\s*Record/;
		next if /^\s*Domain Name/;
				# next if /^\s*\S+ Contact/;
				# last if /^\s*Domain servers/;
		last if /^To single out/;
		if (s/the internic.*//i) {
		    push @result, $_;
		    last;
		}
		s/Administrative Contact/Admin/;
		s/Technical Contact/Tech/;
		s/Domain servers in listed order/DNS/;
		push @result, $_;
		last if ($#result > 15);
	    }
	    foreach (@result) { s/\s+/ /; s/^\s+//; }
	    foreach (0..$#result-1) {
		$result[$_].="; " unless $result[$_]=~/:\s*$/;
	    }
	    $result = join("", @result);
	    $result =~ s/\s+;/;/g;
	    $result =~ s/\s+/ /g;
	} else {
	    $result =  "I can't find the domain $item";
	}
	$DOMAIN_TIME_CACHE{$item} = time();
	$DOMAIN_CACHE{$item} = $result;
	&msg($who, $result);

	exit;			# exit child.
    }
}

sub domain_lookup {
    # do the actual looking up
    my($lookup) = @_;
    my ($name, $aliases, $proto, $port, $len, 
	$this, $that, $thisaddr, $thataddr, $hostname);

    my @result;

    my $whois_server = 'rs.internic.net';
    my $whois_port = 43;

    $sockaddr = 'S n a4 x8';
    chop($hostname = `hostname`);

    ($name, $aliases, $proto) = getprotobyname('tcp');
    ($name, $aliases, $whois_port)  = getservbyname($whois_port, 'tcp')
	unless $whois_port =~ /^\d+$/;
    ($name, $aliases, $type, $len, $thisaddr) = gethostbyname($hostname);
    ($name, $aliases, $type, $len, $thataddr) = gethostbyname($whois_server);

    $this = pack($sockaddr, AF_INET,  0, $thisaddr);
    $that = pack($sockaddr, AF_INET,  $whois_port, $thataddr);

    socket(DOMAIN_SERVER, PF_INET, SOCK_STREAM, $proto)
	|| die "socket: $!";
    bind(DOMAIN_SERVER, $this)	|| die "bind: $!";	  
    connect(DOMAIN_SERVER, $that) || die "connect: $!";	  

    select(DOMAIN_SERVER); $| = 1;

    print DOMAIN_SERVER $lookup."\r\n"; 

    @result = ();
    my $line;
    while (($#result < 30) && ($line = <DOMAIN_SERVER>)) {
	next if (1.. $line =~ /Registrant:/);
	push(@result,$line);
    }
    close(DOMAIN_SERVER); select(STDOUT);

    unshift @result, "Registrant: " if @result;
    @result;
}

1;

__END__

=head1 NAME

Internic.pl - look up Internic/RIPE whois records for a host

=head1 PREREQUISITES

Just the standard stuff.

=head1 PARAMETERS

allowInternic

=head1 PUBLIC INTERFACE

	Internic|RIPE for <host>

=head1 DESCRIPTION

Queries RIPE or the Internic for the whois information about the
supplied host, and formats it up nicely.

=head1 AUTHORS

Kevin Lenzo
