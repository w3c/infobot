# all the user stuff
#
# kevin lenzo
#

sub parseUserfile {
    $file = $param{'confdir'}.$filesep.$param{'userList'};
    %user = ();
    @userList = ();

    open(FH, $file);
    while (<FH>) {
	if (!/^#/ && defined $_) {
	    if (/^UserEntry\s+(.+?)\s/) {
		push @userList, $1;
		$workname = $1;
		if (/\s*\{\s*/) {
		    while (<FH>) {
			if (/^\s*(\w+)\s+(.+);$/) {
			    $opt = $1; $val = $2;
			    $val =~ s/\"//g;
			    if ($opt =~ /^mask$/i) {
				push @{$workname."masks"}, $val;
			    } elsif ($opt =~ /^flags$/i) {
				$val =~ s/\+//;
				$user{$workname."flags"} = $val;
			    } else {
				$opt =~ tr/A-Z/a-z/;
				$user{$workname.$opt} = $val;
			    }
			} elsif (/^\s*\}\s*$/) {
			    last;
			}
		    }
		} else {
		    status("parse error: User Entry $workname without right brace");
		}
	    }
	}
    }

    my $u;
    foreach $u (@userList) {
	status("found user $user: flags +".$user{$u."flags"}) 
	    if $param{VERBOSITY} > 1;
	
	if ($param{VERBOSITY} > 2) {
	    my $h;
	    foreach $h (@{$u."masks"}) {
		status(" -> hostmask: $h");
	    }
	}
    }
}

sub IsFlag {
    my $flags = $_[0];
    my ($ret, $f, $o);
    my @ind = split //, $flags;

    foreach $f (split //, $uFlags) {
	foreach $o (@ind) {
	    if ($f eq $o) {
		$ret .= $f;
		last;
	    }
	}
    }
    $ret;
}

sub verifyUser {
    my $lnuh = $_[0];
    my ($u, $m);
    my $VerifWho;

    foreach $u (@userList) {
	foreach (@{$u."masks"}) {
	    $m = $_;
	    $m =~ s/\*/.*?/g;
	    $m =~ s/([\@\(\)\[\]])/\\$1/g;
	    if ($lnuh =~ /^$m$/i) {
		$VerifWho = $u;
		last;
	    }
	}
    }

    my $now = time();

    my $m = $message;
    if ($msgType !~ /public/) {
	$m = "<private message>";
    }
    &set('seen', lc $who, $now.$;.channel().$;.$m);

    if ($VerifWho) {
	$uFlags = $user{$VerifWho."flags"};
	$uPasswd = $user{$VerifWho."pass"};
	$uTitle = $user{$VerifWho."title"};

	if (exists $seenVerif{$VerifWho} and 
	    (time()-$seenVerif{$VerifWho} > 360)) {
	    status("mask verified for $VerifWho");
	}

	$seenVerif{$VerifWho} = $now;
    }

    return $VerifWho;
}

sub mkpasswd {
    my $what = $_[0];
    my $salt = chr(33+rand(64)).chr(33+rand(64));
    $salt =~ s/:/;/g;

    return crypt($what, $salt);
}

sub ckuser {
    # returns user level if matched, zero otherwise
    my ($nuh, $plaintextpass) = @_;
    if (!$plaintextpass) {
	($nuh, $plaintextpass) = split(/\s+/, $nuh);
    }

    return '' unless $nuh;
    my ($level, $cryptedpass, $rest, $nuh2) = &userinfo($nuh);

    if (&ckpasswd($plaintextpass, $cryptedpass)) {
	# password matched for user nick!user@host
	&status("confirmed user: $nuh");
	return $level;
    } else {
	# no match
	return 0;
    }
}

sub ckpasswd {
    # returns true if arg1 encrypts to arg2
    my ($plain, $encrypted) = @_;
    if (!$encrypted) {
        ($plain, $encrypted) = split(/\s+/, $plain, 2);
    }
    return '' unless ($plain && $encrypted);
    return ($encrypted eq crypt($plain, $encrypted));
}

sub userinfo {
    my $lnuh = $_[0];
    my $k;

    if (!$lnuh) {
	$lnuh = $nuh;
    }
    foreach $k (keys %userList) {
	my $n = $k;
	$n =~ s/\*/.*/g;
	$n =~ s/([\@\(\)\[\]])/\\$1/g;

	if ($lnuh =~ /^$n$/i) {
	    # this may expand later
	    my ($userlevel, $pass, $rest) = split(/:/, $userList{$k}, 3);
	    return ($userlevel, $pass, $rest, $k);
	}
    }
    return ();
}

sub users {
    my @stuff;
    foreach (sort keys %userList) {
	push(@stuff, "$_ => $userList{$_}\n");
    }
    return @stuff;
}

sub adduser {
    my($nuh, $level, $plainpass, $rest) = @_;
    if (!$level) {
	($nuh, $level, $plainpass, $rest) = split(/\s+/, $nuh, 4);
    }
    if (!$plainpass && ($level =~ /\D/)) {
	my $x = $level;
	if ($plainpass =~ /^\D+/) {
	    $level = $plainpass;
	    $plainpass = $level;
	}
    }

    if (($level =~ /^\d+/) && $plainpass) {
	my $cryptedpass = mkpasswd($plainpass);
	my $i = join(":", $level, $cryptedpass, $rest);
	$userLevel{$nuh} = $i;
	&status("user $nuh added at level $i");
	return "user $nuh added at level $i";
    } else {
	&status("bad params to adduser");
	return '';
    }
}

sub writeUserFile {
    my $where = $_[0];
    chomp $where;
    if (!$where) {
	$where = $param{'confdir'}.$filesep.$param{'userList'};
    }
    if (!$where) {
	return "no file given and no param set for writing user file\n";
    }
    if (open(UF, ">$where")) {
	foreach (sort keys %userLevel) {
	    print UF "$_:$userLevel{$_}\n";
	}
	close UF;
	&status("wrote user file to $where");
	return "wrote user file";
    } else {
	&status("failed to write user file to $where");
	return "couldn't write user file";
    }
}

sub changepass {
    my ($nuh, $oldpass, $newpass) = @_;

    if (&ckuser($nuh, $oldpass)) {
	my $cryptednew = mkpasswd($newpass);
	my ($level, $pass, $rest, $nuh2) = &userinfo($nuh);
	my $i = join(":", $level, $newpass, $rest);
	$userList{$nuh2} = $i;
	&status("password changed for $nuh");
	return "password changed for $nuh";
    } else {
	&status("password change failed for $nuh");
	return "password did not match you: $nuh";
    }
}

sub removeuser {
    my $nuh = $_[0];

    if ($userList{$nuh}) {
	delete $userList{$nuh};
	&status("deleted $nuh from userlist");
	return "deleted $nuh from the userlist";
    } else {
	return 'No match for $nuh';
    }
}

sub setlevel {
    my ($nuh, $newlevel) = @_;
    if (!$newlevel) {
	($nuh, $newlevel) = split(/\s+/, $nuh, 2);
    }
    my ($level, $pass, $rest, $nuh2) = &userinfo($nuh);
    if ($newlevel !~ /^\d+/) {
	return "bad user level: $newlevel";
    }
    if ($userList{$nuh}) {
	($level, $pass, $rest) = split(/:/, $userList{$nuh});
	$nuh2 = $nuh;
    }
    if ($nuh2) {
	my $i = join(":", $newlevel, $pass, $rest);
	$userList{$nuh2} = $i;
	&status("level for $nuh changed to $newlevel (was $level)");
    } else {
	&status("no match for $nuh");
    }
    0;
}

sub userProcessing {
    my $now = time();

    if ($VerifWho) {
	if ($msgType =~ /private/) {
	    my $unverified_message = "you must identify yourself; /msg $param{nick} <pass> <command>";

	    if (IsFlag("e")) { # eval
		if ($message =~ s/^(\S+) eval//) {
		    if (!exists $verified{$VerifWho}) {
			&status("unverified <$who> $message");
			&msg($who, $unverified_message);
			return 'NOREPLY';
		    } 
		    my ($pass, $m) = ($1, $message);
		    $_ = "";
		    &msg($who, "WARNING: exposed eval security risk");
		    $x = eval($m); 
		    &msg($who, $x);
		}
	    }

	    if (IsFlag("o")) { # owner/operator flag
		if ($message =~ /^die/) {
		    if (!exists $verified{$VerifWho}) {
			&status("unverified <$who> $message");
			&msg($who, $unverified_message);
			return 'NOREPLY';
		    } 
		    &rawout("QUIT :$who");
		    &closeDBMAll();
		    sleep 2;
		    status("Dying by $who\'s request");
		    exit(0);
		}

		if ($message =~ /^reload$/i) {
		    if (!exists $verified{$VerifWho}) {
			&status("unverified <$who> $message");
			&msg($who, $unverified_message);
			return 'NOREPLY';
		    } 
		    &status("RELOAD <$who>");
		    opendir DIR, $infobot_src_dir;
		    while ($file = readdir DIR) {
			next unless $file =~ /\.pl$/;
			next if $file eq 'Process.pl';
			if (!do $file) {
			    &status("Error reloading $file: "
				    . ($@ || "did not return a true value"));
			}
		    }
		    close DIR;
		    &msg($who, "reloaded init files");
		    return 'NOREPLY';
		}

		if ($message =~ /^rehash$/i) {
		    if (!exists $verified{$VerifWho}) {
			&status("unverified <$who> $message");
			&msg($who, $unverified_message);
			return 'NOREPLY';
		    } 
		    &status("REHASH <$who>\n");
		    &setup();
		    &msg($who, "rehashed");
		    return 'NOREPLY';
		}

		if ($message =~ /^modes$/) {
		    if (!exists $verified{$VerifWho}) {
			&status("unverified <$who> $message");
			&msg($who, $unverified_message);
			return 'NOREPLY';
		    } 
		    my ($chan, $mode, $user, $msg, $m1);
		    foreach $chan (keys %channels) {
			my $msg = "$chan: ";
			foreach $mode (keys %{$channels{$chan}}) {
			    my $m1 = $msg." $mode: ";
			    foreach $user (keys %{$channels{$chan}{$mode}}) {
				$m1 .= "$user ";
			    }
			    &msg($who, $m1);
			}
		    }
		    return 'NOREPLY';
		}
	    }

	    if (IsFlag("p") eq "p") { # oP on channel
		if ($message =~ s/^op( me)?$//i or $message =~ s/^op //i) {
		    if (!exists $verified{$VerifWho}) {
			&status("unverified <$who> $message");
			&msg($who, $unverified_message);
			return 'NOREPLY';
		    } 
		    &status("trying to op $who at their request");
		    foreach $chan (keys %channels) {
			if ($message) {
			    &op($chan, $message);
			} else {
			    &op($chan, $who);
			}
		    }
		    return 'NOREPLY'; 
		}
		my $regex = 0;

		if ($message =~ /^ignore\s+(.*)/) {
		    my $what = $1;

		    &postInc(ignore => $what);
		    &status("ignoring $what at $VerifWho's request");
		    &msg($who, "added $what to the ignore list");

		    return 'NOREPLY';
		}

		if ($message =~ /^ignorelist$/) {
		    &status("$who asked for the ignore list");
		    my $all = join " ", &getDBMKeys('ignore');
		    while (length($all) > 200) {
			$all =~ s/(.{0,200}) //;
			&msg($who, $1);
		    }
		    &msg($who, $all);
		    return 'NOREPLY';
		}
		
		if ($message =~ /^unignore\s+(.*)/) {
		    my $what = $1;

		    if (&clear(ignore => $what)) {
			&status("unignoring $what at $VerifWho's request");
			&msg($who, "removed $what from the ignore list");
		    } else {
			&status("unignore FAILED for $1 at $who's request");
			&msg($who, "no entry for $1 on the ignore list");
		    }
		    return 'NOREPLY';
		}
	    }
	}
    } else {
	$uFlags = $user{"defaultflags"};
    }
}

1;

