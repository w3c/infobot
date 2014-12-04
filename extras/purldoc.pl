# purldoc.pl - Part of the kinder, gentler #Perl.

# Though he hates to admit it, this was written by the gent
# on EFNet #Perl known most often as Masque.  Comments to 
# masque@pound.perl.org.  This code is covered under the same
# license as the rest of infobot.

# Eternal thanks to oznoid for writing the other bits, and 
# for being a good friend to all Perldom.  We're fortunate
# to have him.

# Please note that in this version, purldoc only searches the
# question _titles_.  This is MUCH faster, and reduces the 
# amount of work that the host machine has to do.  This is
# the same way that perldoc -q does it, so don't complain
# _too_ loudly. 

# KNOWN BUGS: Still sucks in many ways.

# removed all throttling code and replaced with returning
# \n-delimited clumps rather than direct msg or say.

sub purldoc {
    my @results;
    my $msg_params;
    my $msg_limit = 6;

    # changed this to just return the answers, mainly -- kl
    ($message, $msg_params) = split /;/, $message, 2; 

    print "got: $message\n";

    my $pd_return = &purldoc_lookup($message, \@results);
    return $pd_return unless @results;

    my $res = '';

    # removed the public/private distinction to be handled in
    # the calling code -- kl

# This is one of those ideas that sounds great until you actually
# implement it.  I now think the following concept sucks.  Hard.
# On the off chance you disagree with me, leave it in.  :]

    # Complain if the user wants a specific number of all messages.

    if ($msg_params =~ /\d+/ && $msg_params =~ /all/i) {
	&msg($who, "Oh come now.  Don't give me a number AND 'all'."); 
	return 'NOREPLY';
    }

    # Many thanks to crimson for the following join incantation.
    # This is basically join() with a limit of $msg_limit items.  Neat.
    # I've uglified it by putting spaces in it and thus making it human
    # readable.  ;)  The solution used lower to truncate the array to 
    # the message limit is somewhat more elegant, but I'm leaving this
    # in comments because it's neat.

    # &msg($who, join("; ",(@results[0..(@results < $msg_limit ? @results - $msg_limit : $msg_limit - 1)]))) and return unless $msg_params;

    $msg_limit = $1 if $msg_params =~ /(\d+)/;
    my $max_lines = getparam('purldoc_max_lines');

    if ($msgType =~ /public/) {
	my $max_public = getparam('purldoc_max_public');
	$msg_limit = $max_public if $max_public < $max_lines;
    }

    # moved this down -- kl

    if (getparam('purldoc') eq 'verbose') {
	&msg($who, "There are " . (scalar @results - $msg_limit) . " more matches for your query.  /msg me with the query to see more.");
    }

    # Okay, so it turns out that 'all' is a bit of a lie.  It's
    # more like 'all, unless X'.  30 will tie the bot up long enough, 
    # and people need to learn to limit their matches to some degree
    # anyway.  PATCHES ARE WELCOME.  Yes, I'm aware the clumping code
    # is total baby-talk.  See earlier 'patches' comment. 

    # clump limit is hardcoded.

    # Look what happens when you try to crossbreed style rules!  
    # ;]  Hey, for that matter, check out the low-quality "let's pass
    # the -w test" kludge!  Did I mention that this whole subroutine
    # was written over four days, spending no more than 10 minutes at
    # a time per sitting?  I'll rewrite this, but for now I just want
    # to get the output working.  Besides, I've got a couple of hours
    # before the next code release....

    # Come to think of it, we're not using -w at all.  I am 
    # DEFINITELY going to rewrite this, so please stop laughing
    # at this code now.  The other subroutine is reasonably well
    # written, go read that one instead.

    # Thanks, lucs!  $#results = $msg_limit -1 is neato.  :]
    $#results = $msg_limit - 1 if @results > $msg_limit;  

    if (defined $msg_params && $msg_params =~ /clump/i) {
	my $clump;
	for (0..$#results) {
	    $clump .= "$results[$_]; ";
	    if ($_ == $#results) {
		$clump =~ s/; $//;
		return $clump;
	    }
	    unless (($_  + 1) % 4) {
		$clump =~ s/; $/.../;
		$clump .= " \n";
	    }
	}
    } else {  
	my $res = '';
	for (0..$#results) { 
	    $res .= " \n" if $res;
	    $res .= $results[$_];
	}
	return $res;
    }       
}

# End sub purldoc()

# I probably don't need to pass the array to the subroutine, but
# it looks more impressive when the subroutine is all pr0totyped,
# etc., and perhaps I can distract you, the noble reader, from
# noticing the other less impressive bits of this code by putting
# in overly complicated code.  We pass the array because we're only
# using return values if the sub blows up.  Lame?  Yes.  Stupid?
# Perhaps.  Intentional?  Sure!  This is perl, it's supposed to 
# be fun.  ;)

sub purldoc_lookup (\$\@) {

    my $regex            =  shift;
    my $original_regex   =  $regex;
    my $target_filename  =  getparam('purldoc_override') || 'pod/perlfaq.pod';
    my @search_dirs      =  @INC;
    my $results          =  shift;

# There is most likely a much more elegant way to do this search, however
# this works, and it's 2am, so you're welcome to comment all you like either
# to /dev/null or to masque@pound.perl.com.  Patches welcome.  :]

    unless (getparam('purldoc_override')) {
	for (@search_dirs) { 
	    $target_filename = "$_/$target_filename" and last if -e "$_/$target_filename";
	}
    } 

# We don't do -f.  -f would be crazy-long to return.  It'd be easy 
# enough to do, but it should only reply via /msg if implemented.
# Hmm...perhaps it should also be usable as 
# 'tell $who about purldoc -f $function', though that has the 
# potential for abuse.  Perhaps purl should respond '$who wants
# you to ask me about purldoc -f $function,' but that is really
# pretty lame (and likely to be ignored.)  Ah well.  Reserved for
# future use.

    return "No -f for you!  NEXT!" if $regex =~ /^\s*-t?f/i;

# Sanity check on $regex.  We don't want people searching for 'I', etc.
# It was most tempting to add 'HTML' and 'CGI' to the first regex, but
# I overcame the temptation...for now.  ;)

    $regex =~ s/(?:^|\b|\s)(?:\-t?qt?|I|do|how|my|what|which|who|can)\b/ /gi;

# I'm not proud of using the fearsome '.*?' here, but that leading and
# trailing whitespace MUST GO!  IT ALL MUST GO!  WE'LL MAKE ANY DEAL!
# IT'S CRAAAAAAAAAAAAAAAAAAZY MASQUE'S USED REGEX EMPORIUM!  COME ON
# DOWN!  WE'LL CLUB A SEAL TO MAKE A BETTER DEAL!  (Weird Al, UHF)++ 

    $regex =~ s/^\s*(.*?)\s*$/$1/;

# We're pretty picky about the regex.  Currently there are no helpful 
# two-letter strings in perlfaq (with the possible exception of 'do', 
# which is being filtered for other reasons) so we require the length
# to be above that, and also we only want letters of the alphabet, 
# thanks.  

    return "\'$original_regex\' isn't a good purldoc search string." unless $regex =~ /^[A-Za-z ]+$/ and length $regex > 2;

    open PURLDOC, "<$target_filename" or return "Sorry, guys.  I can't open perlfaq right now.";

# ACHTUNG!  THE FOLLOWING CODE IS WILDLY INEFFICIENT!  HAVE A CAPS LOCKY DAY.

    my $chapter;
    my $versecount;

    while (<PURLDOC>) {
	last if /^=head1 Credits/;
	$chapter = $1 and $versecount = 0 if /^=item L<(\w+\d)/;
	if (s/=item \* //) { 
	    chomp;
	    $versecount++;
	    push(@$results, "$chapter, question $versecount: $_") if /$regex/i;
	}
    }
    return "No matches for keyphrase '$regex' found." unless scalar @$results;
}
    1;

    __END__

=head1 NAME

purldoc.pl - Interface to the Perl FAQ.

=head1 PREREQUISITES

Nothing.

=head1 PARAMETERS

=over 4

=item purldoc

Turns the facility on and off

=item purldoc_triggers

Regexp used to match a call to the FAQ. Should be something like
`purldoc' or `perldoc'.

=back

=head1 PUBLIC INTERFACE

(Depends on your triggers, but generally:)

		purldoc <topic>


=head1 DESCRIPTION

This looks up the given words as parts of a question in the Perl FAQ,
and returns the top three matching questions.

=head1 AUTHORS

Masque <masque@pound.perl.org>
