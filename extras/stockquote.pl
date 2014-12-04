use strict;

my $no_quote;

BEGIN {
    eval qq{
	use LWP::UserAgent;
	use HTTP::Request::Common qw(GET);
    };

    $no_quote++ if($@);
}

sub get_quote { 
    my ($symbol) = @_;

    if ($no_quote) {
	return "error: stock quotes require LWP::UserAgent and HTTP::Request... sorry.";
    }

    if ($symbol) {
	&status ("getting stock quote for $symbol");

	my $ua = new LWP::UserAgent;
	if (my $proxy = main::getparam('httpproxy')) { $ua->proxy('http', $proxy) };
	$ua->timeout(10);

	my $request = new HTTP::Request ("GET", "http://quote.yahoo.com/d/quotes/csv?s=$symbol&f=sl1d1t1c1ohgv&e=.csv");
	my $result = $ua->request ($request);

	if ($result->is_success) {
	    my $str = $result->content;
	    # strip quotes and extra whitespace
	    $str =~ s/["\s]//g;
	    chomp ($str);
	    my ($name, $current, $date, $time, $change) = split (/,/, $str);

	    if ($current eq "N/A") {
		return "No match for $name";
	    }
	    return "At $time GMT-4, $name traded at $current ($change)";
	} else {
	    return "error: there was a problem getting the quote from Yahoo\n";
	}
    }
}

1;

__END__

=head1 NAME

quote.pl - Get stock quote from yahoo

=head1 PREREQUISITES

	LWP::UserAgent
	HTTP::Request::Common

=head1 PARAMETERS

quote

=head1 PUBLIC INTERFACE

	purl, quote <4-LETTER-TICKERNAME>

=head1 DESCRIPTION

This allows you to get a stock quote for a symbol from yahoo's stock
service.

=head1 AUTHORS

LotR <martijn@earthling.net> based on quote.pl from
Xachbot (http://www.xach.com/xachbot/quote.pl)
