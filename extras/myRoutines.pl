# Infobot user extension stubs 
# Kevin A. Lenzo

# put your routines in here.

@howAreYa = ("just great", "peachy", "mas o menos", 
	 "you know how it is", "eh, ok", "pretty good. how about you");

sub myRoutines {
    # called after it decides if it's been addressed.
    # you have access tothe global variables here, 
    # which is bad, but anyway.

    # you can return 'NOREPLY' if you want to stop
    # processing past this point but don't want 
    # an answer. if you don't return NOREPLY, it
    # will let all the rest of the default processing
    # go to it. think of it as 'catching' the event.

    # $addressed is whether the infobot has been 
    #			named or, if a private or standalone
    #			context, addressed is always 'true'

    # $msgType can be 'public', 'private', maybe 'dcc_chat'

    # $who is the sender of the message

    # $message is the current state of the input, after
    #		  the addressing stuff stripped off the name

    # $origMessage is the text of the original message before
    #			  any normalization or processing

    # you have access to all the routines in urlIrc.pl too,
    # of course.

    # example:

    if ($addressed) {
	# only if the infobot is addressed
	if ($message =~ /how (the hell )?are (ya|you)( doin\'?g?)?\?*$/) {
	    return $howAreYa[rand($#howAreYa)];
	}

    } else {
	# we haven't been addressed, but we are still listening
    }

    # another example: rot13 

    if ($message =~ /^rot13\s+(.*)/i) {
	# rot13 it
	my $reply = $1;
	$reply =~ y/A-Za-z/N-ZA-Mn-za-m/;
	return $reply;
    }

    return undef;	# do nothing and let the other routines have a go
    # Extras.pl is called next; look there for more complex examples.
}

1;

