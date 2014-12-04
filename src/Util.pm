# $Id: Util.pm,v 1.1 2000/11/01 22:40:50 lenzo Exp $

use strict;

package Util;

=head1 NAME

Util - infobot utility functions

=head1 SYNOPSIS

    export_to_main   qw(func &func2 $scalar @array %hash);
    import_from_main qw(func &func2 $scalar @array %hash);
    import_export $from_pkg, $to_pkg, @symbol;

    process_args \@arg_list, myarg => \$myvar, %more_pairs or die;

=head1 DESCRIPTION

This module provides some utility functions for the B<infobot>.

=cut

use Carp		qw(croak);
use Exporter		();

use vars qw($VERSION @ISA @EXPORT_OK);

$VERSION  = do{my@r=q$Revision: 1.1 $=~/\d+/g;sprintf '%d.'.'%03d'x$#r,@r};

@ISA		= qw(Exporter);
@EXPORT_OK	= qw(
    export_to_main
    import_export
    import_from_main
    process_args
);

=head1 IMPORTABLE SYMBOLS

=over 4

=cut

sub import_export {
    my ($from_pkg, $to_pkg, @symbol) = @_;
    my ($symbol, $type, $name, $code);

    $code = "package $to_pkg;\n";
    for $symbol (@symbol) {
	($type, $name) = $symbol =~ /^([\$\@%&])?(\w+)$/
	    or croak "Invalid symbol `$symbol'";
	$type ||= '&';
	$code .= "*$name = \\$type${from_pkg}::$name;\n";
    }
    print $code if 0;

    {
	no strict 'refs';
	eval $code;
	die if $@;
    }
}

sub export_to_main {
    my @symbol = @_;
    import_export scalar(caller), 'main', @symbol;
}

sub import_from_main {
    my @symbol = @_;
    import_export 'main', scalar(caller), @symbol;
}

#------------------------------------------------------------------------------

BEGIN {
    import_from_main qw(status);
}

sub process_args {
    my ($rarg, %desc) = @_;

    my $caller_sub = (caller 1)[3];
    my $fail = 0;

    while (@$rarg > 1) {
	my ($key, $val) = splice @$rarg, 0, 2;
	if ($desc{$key}) {
	    ${ $desc{$key} } = $val;
	} else {
	    status "$caller_sub: invalid arg `$key'";
	    $fail = 1;
	}
    }

    if (@$rarg) {
	status "$caller_sub: ignoring trailing value-less arg `$rarg->[0]'";
	$fail = 1;
    }

    return !$fail;
}

1

__END__

=back

=head1 AUTHOR

Roderick Schertler <F<roderick@argon.org>>

=head1 SEE ALSO

infobot(1), perl(1).

=cut
