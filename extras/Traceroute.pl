
# infobot :: Kevin Lenzo  (c) 1997
# with thanks to Patrick Cole

use POSIX;

sub T_REAPER {
    $SIG{CHLD} = \&REAPER;	# loathe sysV
    $waitedpid = wait;
}

$SIG{CHLD} = \&T_REAPER;

sub troute {
    my $in = $_[0];

    if (!defined($pid = fork)) {
	return "no luck, $safeWho";
    } elsif ($pid) {
	# parent
    } else {
	# child
	if ($in !~ /^[-_a-zA-Z0-9]+(\.[-_a-zA-Z0-9]+)+$/) {
	    &status("malformed traceroute: :$in:\n");
	    exit;
	}

	@tr = `traceroute $in`;
	chomp($out = $tr[@tr-1]);
	if ($msgType eq 'public') {
	    &msg($who, $out);
#	    &say($out);
	} else {
	    &msg($who, $out);
	}
	exit;			# kill child
    }
}

1;

__END__

=head1 NAME

DNS.pl - Look up hosts in DNS

=head1 PREREQUISITES

External `traceroute' application

=head1 PARAMETERS

allowTraceroute

=head1 PUBLIC INTERFACE

    traceroute <host>

=head1 DESCRIPTION

Shells out to the `traceroute' application to trace the route to a
host.

=head1 AUTHORS

Kevin Lenzo and Patrick Cole
