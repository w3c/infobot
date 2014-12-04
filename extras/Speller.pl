
# infobot :: Kevin Lenzo  (c) 1997

# doce++ for the first version of this!

sub ispell {
    my $in = $_[0];

    $in =~ s/^\s+//;
    $in =~ s/\s+$//;

    return "$in looks funny" unless $in =~ /^\w+$/;

    #derr@rostrum# ispell -a
    #@(#) International Ispell Version 3.1.20 10/10/95
    #peice
    #& peice 4 0: peace, pence, piece, price

    my @tr = `echo $in | ispell -a -S`;

    if (grep /^\*/, @tr) {
	my $result = "'$in' may be spelled correctly";
	if ($msgType =~ /private/) {
	    &msg($who, $result);
	} else {
	    &say("$who: $result");
	}
    } else {
	@tr = grep /^\s*&/, @tr;
	chomp $tr[0];
	($junk, $word, $junk, $junk, @rest) = split(/\ |\,\ /,$tr[0]);
	my $result = "Possible spellings for $in: @rest";
	if (scalar(@rest) == 0) {
	    $result = "I can't find alternate spellings for '$in'";
	}
	if ($msgType =~ /private/) {
	    &msg($who, $result);
	} else {
	    &say($result);
	}
    }
    return '';
}


1;

