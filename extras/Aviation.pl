#
# aviation -- infobot module for various flight-planning bits.
#             Was originally 'metar' until infobot 44.5.
#
# 1999/07/?? Rich Lafferty <rich@alcor.concordia.ca>
#            - Initial version
# 1999/08/02 lenzo@cs.cmu.edu      
#            - package, BEGIN, eval checks
# 1999/09/16 lenzo@cs.cmu.edu        
#            - added a timeout 
# 2000/??/?? Lazarus Long <lazarus@frontiernet.net> 
#            - modified to weather.noaa.gov to reflect hostname change
# 2000/11/09 rich@alcor.concordia.ca 
#            - NAME CHANGE: now 'aviation' to reflect new functions
#            - partial rewrite of metar code: now that we have 'weather', we
#              don't need to massage the data for grounded people.
#            - status() added to whine about missing modules
#            - added more aviation functions (taf, great-circle, zulutime)
# 2000/11/17 rich@alcor.concordia.ca
#            - rewrite each function into separate sub
#            - fork to handle all requests (even though only web-based requests
#              really need to fork.
# 2000/11/18 rich@alcor.concordia.ca
#            - added airport name/code lookups, fixed minor bugs in other parts

package Aviation;

my ($no_aviation, $no_entities);

BEGIN {
    eval "use LWP::UserAgent";
    if ($@) { $no_aviation++};
    eval "use HTML::Entities";
    if ($@) { $no_entities++};
}

# Set the following to 1 if you want the forecast separators in 
# a TAF (PROB, BECMG, FM, TEMPO) to be bold. For those that don't know
# from aviation forecasts, each of the above keywords signifies a new
# section of the TAF -- the equivalent, for example, of the "from 10 to 2"
# in "Sunny tomorrow; from 10 to 2, chance of showers".
my $taf_highlight_bold = 1;

#
# Figure out what we're supposed to do, and do it
#
sub Aviation::get { 
    if ($no_aviation) {
	&main::status("Aviation module requires LWP::UserAgent.");
	return '';
    }

    my ($line, $callback) = @_;
    $SIG{CHLD} = 'IGNORE';
    my $pid = eval { fork() };   # catch non-forking OSes and other errors
    return 'NOREPLY' if $pid;              # parent does nothing
    if    ($line =~ /^metar/i)         { $callback->(metar($line))       }
    elsif ($line =~ /^taf/i)           { $callback->(taf($line))         }
    elsif ($line =~ /^great[-\s]?circle/i) { $callback->(greatcircle($line)) }
    elsif ($line =~ /^tsd/i)           { $callback->(tsd($line))         }
    elsif ($line =~ /^zulutime/i)      { $callback->(zulutime($line))    }
    elsif ($line =~ /^airport/i)       { $callback->(airport($line))     }
    elsif ($line =~ /^aviation/i)      { $callback->(aviation($line))    }
    else  { $callback->("I think we just lost a wing!") }  # reach here -> Extras.pl problem
    exit 0 if defined $pid;      # child exits, non-forking OS returns

}

#
# aviation - list available aviation functions
#
sub aviation {
    return "My aviation-related functions are metar, taf, great-circle, tsd, zulutime, and airport. For help with any, ask me about '<function name> help'.";
}

#
# METAR - current weather observation 
#
sub metar {
    my $line = shift;
    if ($line =~ /^metar\s+(for\s+)?(.*)/i) {

	# ICAO airport codes *can* contain numbers, despite earlier claims.
	# Americans tend to use old FAA three-letter codes; luckily we can
	# *usually* guess what they mean by prepending a 'K'. The author,
	# being Canadian, is similarly lazy.
	my $site_id = uc($2);
	$site_id =~ s/[.?!]$//;
	$site_id =~ s/\s+$//g;
	return "'$site_id' doesn't look like a valid ICAO airport identifier."
	    unless $site_id =~ /^[\w\d]{3,4}$/;
	$site_id = "C" . $site_id if length($site_id) == 3 && $site_id =~ /^Y/;
	$site_id = "K" . $site_id if length($site_id) == 3;
	
	# HELP isn't an airport, so we use it for a reference work.
	return "For observations, ask me 'metar <code>'. For information on decoding Aerodrome Weather Observations (METAR), see http://www.avweb.com/toc/metartaf.html"
	    if $site_id eq 'HELP';
	
	my $metar_url = "http://weather.noaa.gov/cgi-bin/mgetmetar.pl?cccc=$site_id";
	
	# Grab METAR report from Web.   
	my $agent = new LWP::UserAgent;
	if (my $proxy = main::getparam('httpproxy')) { $agent->proxy('http', $proxy) };
	$agent->timeout(10);
	my $grab = new HTTP::Request GET => $metar_url;
	
	my $reply = $agent->request($grab);
	
	# If it can't find it, assume luser error :-)
	return "Either $site_id doesn't exist (try a 4-letter station code like KAGC), or the site NOAA site is unavailable right now." 
	    unless $reply->is_success;
	
	# extract METAR from incredibly and painfully verbose webpage
	my $webdata = $reply->as_string;
	$webdata =~ m/($site_id\s\d+Z.*?)</s;    
	my $metar = $1;                       
	$metar =~ s/\n//gm;
	$metar =~ s/\s+/ /g;
	
	# Sane?
	return "I can't find any observations for $site_id." if length($metar) < 10;
       
	return $metar;
    }
    else {
	# malformed
	return "That doesn't look right. The 'metar' command takes an airport identifier and returns the current conditions at the airport in METAR format. (Also, try 'metar HELP'.)";
    }
}    

#
# TAF - terminal area (aerodrome) forecast
#
sub taf {
    my $line = shift;
    if ($line =~ /^taf\s+(for\s+)?(.*)/i) {
 
	# ICAO airport codes *can* contain numbers, despite earlier claims.
	# Americans tend to use old FAA three-letter codes; luckily we can
	# *usually* guess what they mean by prepending a 'K'. The author,
	# being Canadian, is similarly lazy.
	my $site_id = uc($2);
	$site_id =~ s/[.?!]$//;
	$site_id =~ s/\s+$//g;
	return "'$site_id' doesn't look like a valid ICAO airport identifier."
	    unless $site_id =~ /^[\w\d]{3,4}$/;
	$site_id = "C" . $site_id if length($site_id) == 3 && $site_id =~ /^Y/;
	$site_id = "K" . $site_id if length($site_id) == 3;
	
	# HELP isn't an airport, so we use it for a reference work.
	return "For a forecast, ask me 'taf <ICAO code>'. For information on decoding Terminal Area Forecasts, see http://www.avweb.com/toc/metartaf.html"
		if $site_id eq 'HELP';
	
	my $taf_url = "http://weather.noaa.gov/cgi-bin/mgettaf.pl?cccc=$site_id";
	
	# Grab METAR report from Web.   
	my $agent = new LWP::UserAgent;
	if (my $proxy = main::getparam('httpproxy')) { $agent->proxy('http', $proxy) };
	$agent->timeout(10);
	my $grab = new HTTP::Request GET => $taf_url;
	
	my $reply = $agent->request($grab);
	
	# If it can't find it, assume luser error :-)
	return "I can't seem to retrieve data from weather.noaa.com right now."
	    unless $reply->is_success;
	
	# extract TAF from equally verbose webpage
	my $webdata = $reply->as_string;
	$webdata =~ m/($site_id( AMD)* \d+Z .*?)</s; 
	my $taf = $1;                       
	$taf =~ s/\n//gm;
	$taf =~ s/\s+/ /g;
	
	# Optionally highlight beginnings of parts of the forecast. Some
	# find it useful, some find it obnoxious, so it's configurable. :-)
	$taf =~ s/(FM\d+Z?|TEMPO \d+|BECMG \d+|PROB\d+)/\cB$1\cB/g if $taf_highlight_bold;
	
	# Sane?
	return "I can't find any forecast for $site_id." if length($taf) < 10;
	
	return $taf;
    }
    else {
	# malformed
	return "That doesn't look right. The 'taf' command takes an airport identifier as an argument and returns the aerodrome forecast for the airport in TAF format. (Also, try 'taf HELP'.)";
    }
}



#
# greatcircle -- calculate great circle distance and heading between
#                 two airports
sub greatcircle {
    my $line = shift;
    if ($line =~ /^great-?circle\s+((from|between|for)\s+)?(\w+)\s+((and|to)\s)?(\w+)/i) {

	# See metar part for explanation of this bit.
	my $orig_apt = uc($3);
	my $dest_apt = uc($6);

	$dest_apt =~ s/[.?!]$//;
	$dest_apt =~ s/\s+$//g;

	return "'$orig_apt' doesn't look like a valid ICAO airport identifier."
	    unless $orig_apt =~ /^[\w\d]{3,4}$/;	
	return "'$dest_apt' doesn't look like a valid ICAO airport identifier."
	    unless $dest_apt =~ /^[\w\d]{3,4}$/;	

	$orig_apt = "C" . $orig_apt if length($orig_apt) == 3 && $orig_apt =~ /^Y/;
	$orig_apt = "K" . $orig_apt if length($orig_apt) == 3;

	$dest_apt = "C" . $dest_apt if length($dest_apt) == 3 && $dest_apt =~ /^Y/;
	$dest_apt = "K" . $dest_apt if length($dest_apt) == 3;

	my $gc_url = "http://www6.landings.com/cgi-bin/nph-dist_apt?airport1=$orig_apt&airport2=$dest_apt";

	# Grab great-circle data
	my $agent = new LWP::UserAgent;
	if (my $proxy = main::getparam('httpproxy')) { $agent->proxy('http', $proxy) };
	$agent->timeout(10);
	my $grab = new HTTP::Request GET => $gc_url;
	
	my $reply = $agent->request($grab);
    
	# If it can't find it, assume luser error :-)
	unless ($reply->is_success) {
	    return "I can't seem to retrieve data from www.landings.com right now.";
	}  
	
	# extract TAF from equally verbose webpage
	my $webdata = $reply->as_string;
	my $gcd;
	if ($webdata =~ m/circle: ([.\d]+).*?, ([.\d]+).*?, ([.\d]+).*?heading: ([.\d]+)/s) {
	    $gcd = "Great-circle distance: $1 mi, $2 nm, $3 km, heading $4 degrees true";	
	}
	else {
	    $webdata =~ m/(No airport.*?database)/;
	    $gcd = $1;
	}
	
	return $gcd;
    }
    else {
	# malformed
	return "That doesn't look right. The 'great-circle' command takes two airport identifiers and returns the great circle distance and heading between them.";
    }
}

#
# tsd -- calculate time, speed, distance, given any two
# 
sub tsd {
    my $line = shift;
    return "To solve time/speed/distance problems, substitute 'x' for " .
	"the unknown value in 'tsd TIME SPEED DISTANCE'. For example, " .
	"'tsd 3 x 200' will solve for the speed in at which you can travel " .
	"200 mi in 3h." if $line =~ /help/i;
    
    my ($time, $speed, $distance) = ($line =~ /^tsd\s+(\S+)\s+(\S+)\s+(\S+)$/);
    
    my $error;
    $error++ unless $time && $speed && $distance;
    
    if ($time =~ /^[A-Za-z]$/) { # solve for time
	$error++ unless $speed =~ /^[\d.]+$/;
	$error++ unless $distance =~ /^[\d.]+$/;
	return $distance / $speed unless $error;
    }
    elsif ($speed =~ /^[A-Za-z]$/) { # solve for speed
	$error++ unless $time =~ /^[\d.]+$/;
	$error++ unless $distance =~ /^[\d.]+$/;
	return $distance / $time unless $error;
    }
    elsif ($distance =~ /^[A-Za-z]$/) { # solve for distance
	$error++ unless $speed =~ /^[\d.]+$/;
	$error++ unless $time =~ /^[\d.]+$/;
	return $time * $speed unless $error;
    }
    
    return "Your time/speed/distance problem looks incorrect. For help, try 'tsd help'.";

}
	

# 
# zulutime -- return current UTC time
#
sub zulutime {
    $line = shift;
    return "zulutime returns the time in DDHHMM format." if $line =~ /help/i;
    return sprintf('%02d%02d%02dZ', reverse((gmtime())[1..3]));
}
    
#
# airport -- look up airport by identifier (airport name for ___) or by
#            name (airport code(s) for ___). To avoid confusion, we
#            explicitly discard FAA-but-not-ICAO identifiers.
#
sub airport {

    my $line = shift;
    if ($line =~ /^airport\s+(name|code|id)s?\s+(for\s+)?(.*)/i) {
	my $function = lc($1);
	my $query    = $3;
	
	if ($function eq 'name') {
	    $query = "C" . $query if length($query) == 3 && $query =~ /^Y/;
	    $query = "K" . $query if length($query) == 3;
            $query = uc($query);
	    $query =~ s/[.?!]$//;
	    $query =~ s/\s+$//;
	
	    return "That doesn't look like a valid ICAO airport identifier. (Perhaps you mean 'airport code for $query'?)" 
	    unless length($query) == 4;
	
	    my $apt_url = "http://www6.landings.com/cgi-bin/nph-search_apt?1=$query&max_ret=1";

	    # Grab airport data from Web.   

	    my $agent = new LWP::UserAgent;
	    if (my $proxy = main::getparam('httpproxy')) { $agent->proxy('http', $proxy) };
	    $agent->timeout(10);
	    my $grab = new HTTP::Request GET => $apt_url;
	
	    my $reply = $agent->request($grab);

	    # If it can't find it, assume luser error :-)
	    return "I can't seem to access my airport data -- perhaps try again later."
		unless $reply->is_success;
	
	    # extract csv-format airport data from incredibly and painfully verbose webpage
	    my $webdata = $reply->as_string;
	    @apt_lines = split (/\n/, $webdata);

	    my $print_next = 0;
	    my $response   = '';

	    foreach (@apt_lines) {
		# skip over entries without ICAO idents (ICAO: n/a)
		if    (/\(ICAO: <b>[^n]/) { $response .= "$_, "; $pnext = 1; }
		elsif ($pnext)            { $response .= $_; $pnext = 0; }
	    }

     	    $response =~ s/(<.*?>)+/ /g; # naive, but works in *this* case.
            $response =~ s/.*?\) //;      # strip (ICAO: foo) bit
	    $response =~ s/\s+/ /g;
            $response =~ s/ ,/,/g;       # pet peeve.

	    if ($no_entities and $response =~ /(&.*?;)/) {
		&main::status("Aviation module 'airport' function just output a raw HTML entity ($1) because you don't have HTML::Entities installed.");
		$response .= "\n(Excuse the HTML entity. I don't have HTML::Entities handy.)";
	    }
	    else {
		$response = decode_entities($response);
	    }

	    if ($response) {
		return "$query is $response";
	    } 
	    else {
		return "I can't find an airport for $query.";
	    }

	}
	elsif ($function eq 'code' or $function eq 'id') {
	    $query =~ s/[.?!]$//;
	    $query =~ s/\s+$//;
	    my $apt_url = "http://www6.landings.com/cgi-bin/nph-search_apt?5=$query&max_ret=100";

	    # Grab airport data from Web.   

	    my $agent = new LWP::UserAgent;
	    if (my $proxy = main::getparam('httpproxy')) { $agent->proxy('http', $proxy) };
	    $agent->timeout(10);
	    my $grab = new HTTP::Request GET => $apt_url;
	
	    my $reply = $agent->request($grab);

	    # If it can't find it, assume luser error :-)
	    return "I can't seem to access my airport data -- perhaps try again later."
		unless $reply->is_success;
	
	    # extract csv-format airport data from incredibly and painfully verbose webpage
	    my $webdata = $reply->as_string;
	    @apt_lines = split (/\n/, $webdata);

	    my $response   = '';

	    foreach (@apt_lines) {
		$response .= "$1 " if m|\(ICAO: <b>([^n]+?)</b>|;
	    }
	    
	    $response =~ s/(<.*?>)+/ /g; # naive, but works in *this* case.

	    if ($response) {
		return "$query may be: $response";
	    } 
	    else {
		return "I can't find an airport code for $query.";
	    }

	}
	# else fall through to malformed bit below
    }

    # malformed
	return "That doesn't look right. Try 'airport code for CITY' or 'airport name for CODE' instead.";
}

    
1;
__END__
