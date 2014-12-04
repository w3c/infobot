#!/usr/bin/perl

sub storeNickMessage {
    my $w3c_nick = shift;
    my $w3c_mesg = shift;
    &setNickMessage($w3c_nick, $w3c_mesg);
    return("will do"); 
}

"Yow!";
