
# infobot :: Kevin Lenzo  (c) 1997

sub setup_help {
    $filesep ||= '/';
    if (!exists $param{'helpfile'}) {
	$param{'helpfile'} = "$infobot.help"; # murrayb++
    }

    if (open (HELP, "$param{confdir}/$param{helpfile}")) {
	undef %help;
	while ($help = <HELP>) {
	    $help =~ s/\#.*//;
	    chomp $help;
	    next unless $help;
	    ($key, $val) = split(/:/, $help, 2);
	    if (!$help{$key}) {
		$helptopics .= "$key ";
	    }
	    if ($help{$key}) {
		$help{$key} .= $val."\n";
	    } else {
		$help{$key} = $val."\n";
	    }
	}
	$helptopics =~ s/\s+$//;
	&status("Loaded help file $param{helpfile}");
    } else { 
	$help{"main"} = "couldn't find the help file";
	&status("No help file $param{helpfile}");
    }
}

sub help {
    my $topic = $_[0];

    if ($topic =~ /^\s*$/) {
	$topic = "main";
    }

    $topic =~ s/^\s*//;
    $topic =~ s/\s*$//;
    $topic =~ s/\s+/ /;
    $topic =~ tr/A-Z/a-z/;

    if ($help{$topic}) {
	foreach (split(/\n/, $help{$topic})) {
	    &msg($who,$_);
	}
    } else {
	&msg($who, "no help on $topic");
    }

    &msg($who, 'topics:  '.$helptopics.". use 'help <topic>'.");

    return '';
}


1;
