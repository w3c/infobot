# First stab at automagically generating the manual from the config
# files and module documentation.
# Simon Cozens, 1999-

# DON'T, I'M NOT FINISHED YET!

use Pod::Html;
use strict;
use vars qw($version $VER_MAJ $VER_MIN $VER_MOD);
sub status (@) {print "@_\n"}

require "../src/Params.pl";
require "../src/IrcExtras.pl";

# Things we know to be core modules:
my %source = map {$_, 1} qw{
	ANSI.pl          IrcHooks.pl      Reply.pl         CTCP.pl
	Search.pl        Channel.pl       Math.pl          Setup.pl
	DBM.pl           Misc.pl          Speller.pl       Extras.pl
	Norm.pl          Statement.pl     module-template  Help.pl
	Params.pl        myRoutines.pl    Process.pl       Update.pl
	Irc.pl           Question.pl      User.pl          IrcExtras.pl     
};


status "Generating manual for $version";
loadParamFiles($ARGV[0]||"../files/infobot.config");

open(OUT,">infobot-guide.html") 
	or die "! Couldn't write on infobot-guide.html: $!\n";

status "Writing the header...";
print OUT <<EOF;

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">

<html>
  <head>
    <title>Infobot Guide $VER_MAJ\.$VER_MIN\.$VER_MOD</title>
  </head>

  <body bgcolor="#ffffff">
    <h1>Infobot Guide $VER_MAJ\.$VER_MIN\.$VER_MOD</h1>

EOF

status "Writing the introduction and main commands summary...";
open(BIT1, "intro.bit") 
	or die "! Can't load the introduction to the guide: $!\n";
{ local $/=undef; print OUT <BIT1>;}

print "Scanning for extension modules...";
opendir(DH, "../src/") or die "! Couldn't open source directory: $!\n";
my @mods=();
$|=1;
while (defined ($_=readdir(DH))) {
	next unless -f "../src/$_";
	next if exists $source{$_};
	print ".";
	read_it($_);
}

status "\nWriting the rest of the document...";
open(BIT1, "outro.bit") 
	or die "! Can't load the end of the guide: $!\n";
{ local $/=undef; print OUT <BIT1>;}

status "Manual created succesfully.";

sub read_it {
	my $file=shift;
	open (FH, "../src/$file") or die "! Couldn't open $file: $!\n";
	my $found=0;
	my @pods;
	local $/="";
	while (<FH>) {
		$found =1 if (/^=head1/);
		push @pods, $_ if $found;
	}
	unless ($found) {
		warn "\nNo documentation for $file; bad author!\n" unless $found;
		return;
	}
	close FH;
	# Process pods into HTML
}
