#!/usr/bin/perl

# you will probably need to change $homedir
# and possibly the path to perl above

my $homedir = '/usr/home/infobot/infobot0.34';
my @ps = `ps auxw`;

@result = grep !/grep/, @ps;
@result = grep /infobot/, @ps;

if (!@result) {
    print "trying to run new process\n";
    chdir($homedir) || die "can't chdir to $homedir";
    system("nohup $homedir/infobot -i $homedir/files/irc.params > /dev/null &");
} else {
    print "already running: \n";
    print "  @result\n";
}

