#!/usr/bin/perl

my $no_insult;

BEGIN {
    eval "use Net::Telnet ();";
    $no_insult++ if ($@) ;
}

sub insult {
    # alex ayars was a sport and constributed a patch
    my $t = new Net::Telnet (Errmode => "return", Timeout => 3);
    $t->Net::Telnet::open(Host => "insulthost.colorado.edu", Port => "1695");
    my $line = $t->Net::Telnet::getline(Timeout => 4);
    return $line;
}

1;

__END__

=head1 NAME

insult.pl - Contact the Insult Server for an insult

=head1 PREREQUISITES

	Net::Telnet

=head1 PARAMETERS

insult

=head1 PUBLIC INTERFACE

	insult <foo>

If you have Babel enabled,

	insult <foo> in <language code>

=head1 DESCRIPTION

	Produces an insult from the Insult Server.

=head1 AUTHORS

<michael@limit.org>
