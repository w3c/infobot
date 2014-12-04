#!/usr/bin/perl

# kevin lenzo

# run infobot.track through here to get the 
# enters and updates in order.  Adding these
# in order should give you the db as it was.

while (<>) {
    next unless s/.*: (enter|update): //;
    next if /FAILED/;
    chomp; 
    s/\'; was .*//;
    s/\'\s*$//;
    s/.*?\'//;

    print "$_\n";
}
