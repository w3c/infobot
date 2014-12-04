#####################
#                   #
#  Slashdot.pl for  #
# SlashDot headline #
#     retrival      #
#  tessone@imsa.edu #
#   Chris Tessone   #
#   Licensing:      #
# Artistic License  #
# (as perl itself)  #
#####################
#fixed up to use XML'd /. backdoor 7/31 by richardh@rahga.com
#My only request if this gets included in infobot is that the 
#other header gets trimmed to 2 lines, dump the fluff ;) -rah

#added a status message so people know to install LWP - oznoid
#also simplified the return code because it wasn't working.

use strict;

my $no_slashlines;


BEGIN {
    $no_slashlines = 0;
    eval "use LWP::UserAgent";
    $no_slashlines++ if $@;
}

sub getslashdotheads {
    # configure
    if ($no_slashlines) {
	&status("slashdot headlines requires LWP to be installed");
	return '';
    }
    my $ua = new LWP::UserAgent;
    if (my $proxy = main::getparam('httpproxy')) { $ua->proxy('http', $proxy) };
    $ua->timeout(12);
    my $maxheadlines=5;
    my $slashurl='http://www.slashdot.org/slashdot.xml';
    my $story=0;
    my $slashindex = new HTTP::Request('GET',$slashurl);
    my $response = $ua->request($slashindex);

    if($response->is_success) {
	$response->content =~ /<time>(.*?)<\/time>/;
	my $lastupdate=$1;
	my $headlines = "Slashdot - Updated ".$lastupdate;
	my @indexhtml = split(/\n/,$response->content);
	
	# gonna read in this xml stuff.
       	foreach(@indexhtml) {
	    if (/<story>/){$story++;}
	    elsif (/<title>(.*?)<\/title>/){
		$headlines .= " | $1";
	    }
	    elsif (/<url>(.*?)<\/url>/){
		# do nothing
	    }
	    elsif (/<time>(.*?)<\/time>/){
		# do nothing
	    }     
	    last if $story >= $maxheadlines;
	    next;
	}
	
	return $headlines;
    } else {
	return "I can't find the headlines.";
    }
}
1;

__END__

=head1 NAME

Slashdot3.pl - Slashdot headlines grabber 

=head1 PREREQUISITES

	LWP::UserAgent

=head1 PARAMETERS

slashdot

=head1 PUBLIC INTERFACE

	slashdot [headlines]

=head1 DESCRIPTION

Retrieves the headlines from Slashdot; probably obsoleted by RDF.

=head1 AUTHORS

Chris Tessone <tessone@imsa.edu>
