# $Id: DBM.pl,v 1.7 2000/12/09 22:58:27 lenzo Exp $
#
# infobot :: Kevin Lenzo  (c) 1997

use strict;

package Infobot::DBM;

=head1 NAME

DBM.pl - infobot's interface to on-disk databases

=head1 SYNOPSIS

    openDBMx 'mydb', fatal => 1;	# more switches listed below

    $val = get 'mydb', $key;		# get value

    set 'mydb', $key, $val;		# set value
    $prev_val = postInc 'mydb', $key;	# increment, return old value
    $prev_val = postDec 'mydb', $key;	# decrement, return old value

    @keys = getDBMKeys 'mydb';		# get all keys
    clear 'mydb', $key;			# delete key
    clearAll 'mydb';			# delete all keys
    insertFile 'mydb', $filename;	# load space-separated fields
    closeDBM 'mydb';			# close this db
    closeDBMAll;			# close all dbs
    syncDBM 'mydb';			# flush changes to disk

=head1 DESCRIPTION

These functions provide B<infobot>'s interface to on-disk databases.

=cut

BEGIN { push @INC, 'src' } # baad, bad juju here

use vars qw(%DBMS $Debug $Init_done $Old_warnings);

use Fcntl	qw(
    :flock
    O_CREAT
    O_RDWR
);

use Symbol	qw(
    gensym
);

use Util	qw(
    export_to_main
    import_from_main
    process_args
);

BEGIN {
    if (!$Init_done) {
	$Old_warnings = $^W;
	$^W = 1;
    }
}

my @Import;
my @Export;

BEGIN {
    @Import = qw(
    	$filesep
	%param
	status
    );

    @Export = qw(
	clear
	clearAll
	closeDBM
	closeDBMAll
	forget
	get
	getDBMKeys
	insertFile
	openDBM
	openDBMx
	postDec
	postInc
	set
	showdb
	syncDBM
	whatdbs
    );

    export_to_main @Export;
    import_from_main @Import;
}

use subs grep /^\w/, @Export;
use vars grep /^\W/, @Import, @Export;

use subs qw(_open);

# %DBMS maps from the user's database name to an array of data about each
# db.  The referenced array is indexed by the following constant subs.

%DBMS = () unless $Init_done;

sub F_DBNAME	() { 0 }	# %DBMS key
sub F_HASH	() { 1 }	# reference to the tied hash
sub F_FILE	() { 2 }	# name of file opened
sub F_LOCKING	() { 3 }	# true if locking is enabled for this db
sub F_LOCK_FH	() { 4 }	# filehandle used for locking
sub F_LOCK_STAT	() { 5 }	# current LOCK_* status
sub F_MODULE	() { 6 }	# database module used
sub F_SYNC_SUB	() { 7 }	# cached sync() method
sub F_INITFILE	() { 8 }	# initial contents when creating
sub F_UPDATE_COUNT () { 9 }	# number of updates since last sync

$Debug = 0 unless $Init_done;

=head1 CONFIGURATION SETTINGS

=over 4

=item DBMModule

Setting C<DBMModule> lets you explicitly specify the DBM backend which
you'd like to use.  Standard values for this are C<NDBM_File>, C<DB_File>,
C<GDBM_File>, C<SDBM_File>, and C<ODBM_File>, but anything which provides
a tied hash interface should work.  If you don't specify this the default
will generally be the first of these which is present on your system.

Eg:

    DBMModule DB_File

=item DBMExt

This is appened to the file names passed to DBM open.  This can be
useful for DBM modules which don't modify the file name passed to them,
such as DB_File and GDBM_File.  For example,

    DBMExt .db

will provide traditional naming for DB_File databases.

=item sharedDBMs

This provides support for sharing database files among multiple B<infobot>s
on the same machine by using locking.  NB:  Using any sharedDBMs currently
requires that you set C<DBMModule> to C<DB_File>, as none of the other DBM
modules provides the required support.

Eg, if you said

    sharedDBMs is are plusplus

your infobot would use locking when accessing the main factoid databases
and the C<karma> database, but not, say, the C<seen> database.  You can
have multiple infobots accessing the same databases for which they all
use locking.  It's up to you to make sure that all the bots which access
a particular file use locking for it, if you screw that up the rogue
will end up corrupting your database.

There are two special values:

    sharedDBMs /all
    sharedDBMs /all-but-ignore

These set up locking for everything, and for everything but the
C<ignore> database (which is used more than any other, so perhaps
it's a good candidate for such special treatment).

=item commitDBM

This setting controls how often changes to the database are flushed to
disk.  Normally this isn't done manually, so it will depend on how the
DBM module you're using behaves.  If you set C<commitDBM> to a number,
changes will be forced to disk every that many updates (so use 1 to
force a sync after every update).

=back

=cut

unless ($Init_done) {
    $param{DBMModule}	= 'AnyDBM_File';
    $param{DBMExt}	= '';
    $param{sharedDBMs}	= '';
    $param{commitDBM}	= 0;
}

=head1 INTERFACE FUNCTIONS

=over 4

=item opemDBMx I<dbname>, [I<arg> => I<val>]...

This function opens up a database.  The I<dbname> is the name you'll use
to refer to it with all the other functions.  The normal practice is to
supply only the I<dbname>, most of the other arguments have reasonable
(preferred, even) defaults.  openDBMx() returns true if the database was
opened successfully, false otherwise, unless you've set C<fatal> to a
true value.

Arguments are:

    fatal => $boolean

This boolean, which is off by default, tells openDBMx() to
die() rather than returning false if the database can't be
successfully opened.

    tag => $tag

This defaults to the I<dbname> you gave.  That's normally what
you want, it'd be unusual to specify the tag manually.  The tag
is what's actually used to look up the other values in %param.

    file => $filename

This allows you to override the name of database file (though
the user's C<DBMExt> is still appended).  Normally you wouldn't
specify this, and the value the user specifies in $param{$tag}
is used.

    initfile => $filename

When a database is created the code uses insertFile() to load a
file called F<$misc_dir/infobot-$tag.txt> into it.  You can
override the name of the file used by specifying it with this
argument.

    locking => $boolean

This boolean tells the code whether to use locking or not.
Normally you wouldn't specify it and the user's C<sharedDBMs>
setting would dictate that.

    module => $db_module

This allows you to override the user's C<DBMModule> for this database.

=cut

sub openDBMx {
    my ($dbname, @arg) = @_;
    my ($fatal, $file, $initfile, $tag, $locking, $module);

    my $fail = sub {
	my $s = join '', @_;
	status $s;
	die $s if $fatal;
	return 0;
    };

    process_args \@arg,
	    fatal	=> \$fatal,
	    file	=> \$file,
	    locking	=> \$locking,
	    initfile	=> \$initfile,
	    module	=> \$module,
	    tag		=> \$tag
	or return;

    $tag ||= $dbname;

    if (!defined $file) {
	my $base = $param{$tag};
	if (!defined $base) {
	    return $fail->("$tag not specified in config file"
			    . " and no default supplied");
	}
	$file = $param{basedir} . $filesep . $base;
    }
    $file .= $param{DBMExt};

    $initfile = $param{confdir} . $filesep . "infobot-$tag.txt"
	if !defined $initfile;
    $locking = $param{sharedDBMs} eq '/all'
	    	|| ($tag ne 'ignore'
		    && $param{sharedDBMs} eq '/all-but-ignore')
		|| grep { $_ eq $tag } split ' ', $param{sharedDBMs}
	if !defined $locking;
    $module = $param{DBMModule} if !defined $module;

    if ($locking) {
	if ($module ne 'DB_File') {
	    die "Locking is specified for the $tag database, but ",
		    "DBMModule isn't DB_File (it's $module)";
	}
    }

    eval "require $module";
    if ($@) {
	chomp $@;
	die "Invalid DBMModule setting `$module' ($@)\n";
    }

    if ($DBMS{$dbname}) {
	status "$file replaces $DBMS{$dbname}[F_FILE]"
	    unless $file eq $DBMS{$dbname}[F_FILE];
    }

    my $rdb = $DBMS{$dbname} ||= [];
    $rdb->[F_DBNAME]	= $dbname;
    $rdb->[F_FILE]	= $file;
    $rdb->[F_LOCKING]	= $locking;
    $rdb->[F_MODULE]	= $module;
    $rdb->[F_INITFILE]	= $initfile;

    _open $rdb
    	or return $fail->($@);

    return 1;
}

# Perform the actual open on the given db record.  Return true is
# successful, else false and set $@ to an explanation.

sub _open {
    my ($rdb) = @_;
    my ($created);

    my $dbname	= $rdb->[F_DBNAME];
    my $file	= $rdb->[F_FILE];
    my $locking	= $rdb->[F_LOCKING];
    my $module	= $rdb->[F_MODULE];

    my $with_locking = $locking ? ' (with locking)' : '';
    if (tie %{ $rdb->[F_HASH] }, $module, $file, O_RDWR, 0) {
	status "opened $dbname -> $file$with_locking";
    } elsif (tie %{ $rdb->[F_HASH] }, $module, $file, O_CREAT | O_RDWR, 0666) {
	status "created new db $dbname -> $file$with_locking";
	$created = 1;
    } else {
	$@ = "failed to open $dbname -> $file";
	return 0;
    }

    if ($locking) {
	my $fh = $rdb->[F_LOCK_FH] = gensym;
	my $fd = tied(%{ $rdb->[F_HASH] })->fd;
	if (!open $fh, "+<&=$fd") {
	    delete $DBMS{$dbname};
	    $@ = "can't fdopen fd $fd to provide locking for $dbname";
	    return 0;
	}
    }
    $rdb->[F_LOCK_STAT] = LOCK_UN;
    $rdb->[F_UPDATE_COUNT] = 0;

    # Wait until after the locking FH is set up to do the inserts.
    insertFile $dbname, $rdb->[F_INITFILE]
	if $created;

    return 1;
}

sub _close_open {
    my ($dbname) = @_;
    my ($fail_reason);

    closeDBM '_no_delete', $dbname;

    # The old (commented-out) code for this would sleep and retry if the
    # reopen failed.  It seems bogus to me, but I don't want to piss
    # anybody off by removing it.

    for (1..10) {
	return 1 if _open $DBMS{$dbname};
    } continue {
	status "Error re-opening $dbname ($@), sleeping";
	sleep 1;
    }
    status "Error re-opening $dbname ($@), giving up";
    return 0;
}

=item openDBM $dbname => $file, ...

This is the old interface to opening databases.  It's equivalent to
running

    openDBMx $dbname, file => $file;

for each pair of arguments.  The return value is true if all the opens
succeeded.

=cut

sub openDBM {
    my %arg = @_;
    my ($dbname, $file, $fail);

    while (($dbname, $file) = each %arg) {
	next unless $dbname =~ /\S/;
	openDBMx $dbname, file => $file
	    or $fail = 1;
    }

    return !$fail;
}

=item syncDBM $dbname

Flush to disk any unwritten changes to the database.

=cut

sub syncDBM {
    my ($dbname) = @_;
    my $rdb = $DBMS{$dbname};

    print "sync $rdb->[F_DBNAME]\n" if $Debug;
    $rdb->[F_UPDATE_COUNT] = 0;
    &{ $rdb->[F_SYNC_SUB] ||= do {
		if (tied(%{ $rdb->[F_HASH] })->can('sync')) {
		    print "syncDBM: $dbname using ->sync\n" if $Debug;
		    sub { tied(%{ $rdb->[F_HASH] })->sync }
		}
		else {
		    print "syncDBM: $dbname using reopen\n" if $Debug;
		    sub { _close_open $dbname }
		}
	    }
	}();
}

sub lock {
    my ($rdb, $bits) = @_;

    my $have = $rdb->[F_LOCK_STAT];
    my $want = $bits - ($bits & LOCK_NB);

    printf "lock db %-8s fd %2s have $have want $want bits $bits\n",
	    $rdb->[F_DBNAME],
	    $rdb->[F_LOCKING] ? fileno $rdb->[F_LOCK_FH] : '-',
	if $Debug;

    return if $have == $want;

    # Possibly flush when unlocking (or downgrading LOCK_EX to LOCK_SH).
    if ($have == LOCK_EX) {
	$rdb->[F_UPDATE_COUNT]++;
	if ($rdb->[F_LOCKING]
		|| $param{commitDBM} eq 'ALWAYS' # grandfather
                || ($param{commitDBM} > 0 &&
                    $rdb->[F_UPDATE_COUNT] >= $param{commitDBM})) {
	    syncDBM $rdb->[F_DBNAME];
	}
    }

    flock $rdb->[F_LOCK_FH], $bits or die "Can't lock $rdb->[F_FILE]: $!\n"
	if $rdb->[F_LOCKING];
    $rdb->[F_LOCK_STAT] = $want;
}

=item insertFile $dbname, $filename

This loads the given file into the database.  Input lines look like

    key => value

(spaces around the C<=E<gt>> are optional).

=cut

sub insertFile {
    my ($dbname, $factfile) = @_;
    my $rdb = $DBMS{$dbname};

    if (open(IN, $factfile)) {
	my ($good, $total);

	lock $rdb, LOCK_EX;
	while(<IN>) {
	    chomp;
	    my ($k, $v) = split(/\s*=>\s*/, $_, 2);
	    if ($k and $v) {
		$rdb->[F_HASH]{$k} = $v;
		$good++;
	    }
	    $total++;
	}
	lock $rdb, LOCK_UN;
	close(IN);
	status "loaded $factfile into $dbname ($good/$total good items)";
    } else {
	status "FAILED to load $factfile into $dbname";
    }
}

=item closeDBM $dbname

Close the database.

=cut

sub closeDBM {
   if (@_) {
	my ($dbname, $rdb, $no_delete);
	$no_delete = shift if $_[0] eq '_no_delete';
	foreach $dbname (@_) {
	    my $rdb = $DBMS{$dbname};
	    delete $DBMS{$dbname} unless $no_delete;
	    status untie(%{ $rdb->[F_HASH] })
		    ? "closed db $dbname"
		    : "Error closing db $dbname ($!)";
	}
    } else {
	status "No dbs specified; none closed";
    }
}

=item closeDBMAll

Close all databases.

=cut

sub closeDBMAll {
    closeDBM keys %DBMS;
}

=item set $dbname, $key, $val

Set a key/value pair in the database.

=cut

sub set {
    my ($dbname, $key, $val, $no_locking) = @_;

    if (!$key) {
	($dbname, $key, $val) = split(/\s+/, $dbname);
    }

    # this is a hack to keep set param consistant.. overloaded
    if ($dbname eq 'param') {
	my $was = $param{$key};
	$param{$key} = $val;
	return $was;
    }

    if (!$key) {
	return 'NULLKEY';
    }

    my $rdb = $DBMS{$dbname};
    my $rhash = $rdb->[F_HASH];
    lock $rdb, LOCK_EX unless $no_locking;
    my $was = $rhash->{$key};
    $rhash->{$key} = $val;
    lock $rdb, LOCK_UN unless $no_locking;

    return $was;
}

=item get $dbname, $key

Return the value corresponding to the $key in the database.

=cut

sub get {
    my ($dbname, $key, $no_locking) =@_;

    if (!$key) {
	($dbname, $key) = split(/\s+/, $dbname);
    }

    my $rdb = $DBMS{$dbname};
    lock $rdb, LOCK_SH unless $no_locking;
    my $val = $rdb->[F_HASH]{$key};
    lock $rdb, LOCK_UN unless $no_locking;
    return $val;
}

=item postInc $dbname, $key

Increment the value of $key in the database, return the old value.

=cut

sub postInc {
    my ($dbname, $key) = @_;

    my $rdb = $DBMS{$dbname};
    lock $rdb, LOCK_EX;
    set $dbname, $key, 1 + get($dbname, $key, 1), 1;
    lock $rdb, LOCK_UN;
}

=item postDec $dbname, $key

Decrement the value of $key in the database, return the old value.

=cut

sub postDec {
    my ($dbname, $key) = @_;

    my $rdb = $DBMS{$dbname};
    lock $rdb, LOCK_EX;
    set $dbname, $key, -1 + get($dbname, $key, 1), 1;
    lock $rdb, LOCK_UN;
}

sub whatdbs {
    my @result;
    foreach (keys %DBMS) {
	push @result, "$_ => $DBMS{$_}[F_FILE]";
    }
    return @result;
}

sub showdb {
    my ($dbname, $regex) = @_;
    my @result;

    if (!$regex) {
	($dbname, $regex) = split(/\s+/, $dbname, 2);
    }

    my @whichdbs;

    if (!$dbname) {
	status "no db given";
	status "try showdb <db> <regex>";
	# @whichdbs = (keys %DBMS);
    } else {
	@whichdbs = ($dbname);
    }

    foreach $dbname (@whichdbs) {
	my $rdb = $DBMS{$dbname};
	if (!$rdb) {
	    status "the database $dbname is not open.";
	    status "try showdb <db> <regex>";
	    return();
	}
	lock $rdb, LOCK_SH;
	my $rhash = $rdb->[F_HASH];
	my ($key, $val);
	if (!$regex) {
	     status "showing all of $dbname";
	    while (($key, $val) = each %$rhash) {
		push @result, "$key => $val";
	    }
	} else {
	    status "searching $dbname for /$regex/";
	    while (($key, $val) = each %$rhash) {
		push @result, "$key => $val"
		    if $key =~ /$regex/ || $val =~ /$regex/;
	    }
	}
	lock $rdb, LOCK_UN;
    }

    return @result;
}

sub forget {
    clear @_;
    return '';
}

=item clear $dbname, $key

Delete a key from the database.

=cut

sub clear {
    my ($dbname, $key) =@_;

    if (!$key) {
	($dbname, $key) = split(/\s+/, $dbname);
    }

    my $rdb = $DBMS{$dbname};
    lock $rdb, LOCK_EX;
    my $was = get $dbname, $key, 1;

    print "DELETING $dbname $key\n";
    delete $DBMS{$dbname}[F_HASH]{$key};
    print "DELETED\n";

    lock $rdb, LOCK_UN;
    return $was;
}

=item clearAll $dbname

Empty the database.

=cut

sub clearAll {
    my ($dbname) = @_;

    my $rdb = $DBMS{$dbname};
    lock $rdb, LOCK_EX;
    %{ $rdb->[F_HASH] } = ();
    lock $rdb, LOCK_UN;
}

=item getDBMKeys $dbname

Return all the keys in the database.

=cut

sub getDBMKeys {
    my ($dbname) = @_;

    my $rdb = $DBMS{$dbname};
    lock $rdb, LOCK_SH;
    my @k = keys %{ $rdb->[F_HASH] };
    lock $rdb, LOCK_UN;
    return @k;
}

if (!$Init_done) {
    $^W = $Old_warnings;
    $Init_done = 1;
}

1

__END__

=back

=head1 AUTHOR

Kevin Lenzo, expanded by Roderick Schertler <F<roderick@argon.org>>

=head1 SEE ALSO

infobot(1), perl(1).

=cut
