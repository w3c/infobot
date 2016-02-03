
# infobot :: Kevin Lenzo   (c) 1997-2000

sub setup {
# param setup should stay after most of the requires
# so that it overrides anything they might set.
    &paramSetup();

    if ($param{VERBOSITY} > 1) {
	my $params = "Parameters are:\n";
	foreach (sort keys %param) {
	    $params .= "   $_ -> $param{$_}\n";
	}
	&status($params);
    }

    die "dbname is null" if (!$param{'dbname'});

    %dbs = ("is" => "$param{basedir}/$param{dbname}-is",
	    "are" => "$param{basedir}/$param{dbname}-are");
    srand();

    $setup_time = scalar(localtime());
    $setup_time =~ s/\n//g;

    $startTime = time();

    &setup_help;
    &openDBM(%dbs);

    $qCount = &get("is", "the qCount");
    $qEpochTime = &get("is", "the qEpochTime");

    # things to say when people thank me
    @welcomes = ('no problem', 'my pleasure', 'sure thing',
		 'no worries', 'de nada', 'de rien', 'bitte', 'pas de quoi');

    # when i'm cofused and I have to reply
    @confused = ("huh?", 
		 "what?", 
		 "sorry...", 
		 "i\'m not following you...",
		 "excuse me?");

    # when i recognize a query but can't answer it
    @dunno = ('i don\'t know', 
	      'wish i knew',
	      'i haven\'t a clue',
	      'no idea',
	      'bugger all, i dunno');



    # check the ignore parameter for a filename containing the
    # ignore list

    if ($param{ignore}) {
	&openDBMx('ignore');
    }
	
    if ($param{sanePrefix}) {
	for $d (qw/is are/) {
	    my $dbname = $DBprefix.$d;
	    my $sane = "$param{confdir}/$param{sanePrefix}";
	    $sane .= "-$d.txt";
	    if (-e $sane) {
		&status("loading sane defines $sane");
		&insertFile($dbname, $sane);
	    } else {
		&status("can't fine sane file $sane");
	    }
	}

	if (! open IGNORE, "$param{'confdir'}/$param{sanePrefix}-ignore.txt") {
	    &status("No fallback ignore file $param{'confdir'}/$param{sanePrefix}-ignore.txt");
	} else {
	    while (<IGNORE>) {
		s/^\s+//;
		s/\s+\#.*//;
		chomp;
		/\S/ && do {
		    &postInc(ignore => $_);
		    if ($param{'VERBOSITY'} > 0) {
			&status("Adding $_ to ignore list (from sane).");
		    }
		};
	    }
	    close IGNORE;
	}
    }

    if ($param{'plusplus'}) {
	&openDBMx('plusplus');
    }

    if ($param{'seen'}) {
	&openDBMx('seen');
    }

    # set up the users and ops
	&status("Parsing User File");
    &parseUserfile();

	&status("Parsing Channel File");
	# set up the channel file
	&parseChannelfile();

    # ways to say hello
    @hello = ('hello', 
	      'hi',
	      'hey',
	      'niihau',
	      'bonjour',
	      'hola',
	      'salut',
	      'que tal',
	      'privet',
	      "what's up");

    $param{'maxKeySize'}  ||= 30; # maximum LHS length
    $param{'maxDataSize'} ||= 200; # maximum total length

    if (!@verb) {
	@verb = split(" ", "is are");
	#  am was were does has can wants needs feels
	#  handle s-v agreement for non-being verbs later
    }

    if (!@qWord) {
	@qWord = split(" ", "what where who"); # why how when
    }

    # do this ONCE per startup to amortize.  Still too much mem.
    #&getAllKeys;
    $isCount = &getDBMKeys('is'); 
    $areCount = &getDBMKeys('are');
    $factoidCount = $isCount + $areCount;

    &status("setup: $factoidCount factoids; $isCount IS; $areCount ARE");
}


sub paramSetup {
    my $initdebug = 1;
    $param{'DEBUG'} = $initdebug;

    if (!@paramfiles) {
	# if there is no list of param files, just go for the default
	# (usually ./files/infobot.config)

	@paramfiles = ("$param{confdir}/infobot.config");
    }

    # now read in the parameter files
    &loadParamFiles(@paramfiles);
}


1;
