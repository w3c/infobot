#!/usr/bin/perl

sub storeNickMessage {
    my $nick = shift;
    my $mesg = shift;
    &setNickMessage($nick, $mesg);
    return("will do"); 
}

"Yow!";
