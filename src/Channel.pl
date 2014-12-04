# Channel specific data, based heavily on User.pl
#
# Simon Cozens, for infobot (C) Kevin Lenzo 1997
#

sub parseChannelfile {
    $file = $param{'confdir'}.$filesep.$param{'channelList'};
    %chanopts = ();

    open(FH, $file) or return; # Oz, you didn't check a retval. :P
    while (<FH>) {
		next unless (!/^#/ && defined $_);
	    if (/^ChannelEntry\s+(.+?)\s/) {
		$workname = $1;
		if (/\s*\{\s*/) {
		    while (<FH>) {
			if (/^\s*(\w+)\s+(.+);$/) {
			    $opt = $1; $val = $2;
			    $val =~ s/\"//g;
				$opt =~ tr/A-Z/a-z/;
				$chanopts{$workname}->{$opt} = $val;
			} elsif (/^\s*\}\s*$/) {
			    last;
			}
		    }
		} else {
		    status("parse error: Channel Entry $workname without right brace");
		}
	    }
    }
}

sub getparam {
	my $optname = shift;
	my $chan = channel();
	return $param{$optname} if ($msgType =~ /private/);
	return $chanopts{$chan}->{$optname} 
		if defined $chanopts{$chan}->{$optname};
	return $param{$optname};
}

"false";
