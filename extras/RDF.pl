
# LotR++ for this one
# minor mods by lenzo@cs.cmu.edu

BEGIN {
  eval qq{
    use LWP::UserAgent;
    use XML::RSS;
    use HTTP::Request::Common qw(GET);
  };

  $no_headlines++ if($@);
}

sub get_headlines {
  my ($rdf_loc) = @_;

  if ($no_headlines) {
    return "error: RDF headlines require LWP::UserAgent, XML::RSS, and HTTP::Request... sorry.";
  }

  if ($rdf_loc) {
    &status("getting headlines from $rdf_loc");

    my $ua = new LWP::UserAgent;
    if (my $proxy = main::getparam('httpproxy')) { $ua->proxy('http', $proxy) };
    $ua->timeout(10);

    my $request = new HTTP::Request ("GET", $rdf_loc);
    my $result = $ua->request ($request);

    if ($result->is_success) {
      my ($str);
      $str = $result->content;
      $rss = new XML::RSS;
      eval { $rss->parse($str); };
      if ($@) {
	return "that gave some error";
      } else {
	my $return;

	foreach my $item (@{$rss->{"items"}}) {
	  $return .= $item->{"title"} . "; ";
	  last if length($return) > $param{maxDataSize};
	}

	$return =~ s/; $//;

	return $return;
      }
    } else {
      return "error: $rdf_loc wasn't successful";
    }
  } else {
    return "error: no location stored for $where";
  }
};

1;

__END__

=head1 NAME

RDF.pl - Read RDF files into factoids

=head1 PREREQUISITES

    LWP::UserAgent
    XML::RSS
	HTTP::Request::Common

=head1 PARAMETERS

rss


=head1 PUBLIC INTERFACE

	<site> is <rss="site.rdf">

=head1 DESCRIPTION

This allows you to read and parse RSS files; RSS is a format
for getting news headlines off web news services.

=head1 AUTHORS

LotR <martijn@earthling.net> and Kevin Lenzo, of course.
