require 5.001;
    
%attributes = ('clear'      => 0,
               'reset'      => 0,
	       'bold'       => 1,
               'underline'  => 4,
	       'underscore' => 4,
	       'blink'      => 5,
	       'reverse'    => 7,
	       'concealed'  => 8,
	       'black'      => 30,   'on_black'   => 40, 
	       'red'        => 31,   'on_red'     => 41, 
	       'green'      => 32,   'on_green'   => 42, 
	       'yellow'     => 33,   'on_yellow'  => 43, 
	       'blue'       => 34,   'on_blue'    => 44, 
	       'magenta'    => 35,   'on_magenta' => 45, 
	       'cyan'       => 36,   'on_cyan'    => 46, 
	       'white'      => 37,   'on_white'   => 47);

$b_black 	= cl('bold black');	$_black		= cl('black');
$b_red 		= cl('bold red');	$_red		= cl('red');
$b_green 	= cl('bold green');	$_green		= cl('green');
$b_yellow 	= cl('bold yellow');	$_yellow	= cl('yellow');
$b_blue		= cl('bold blue');	$_blue		= cl('blue');
$b_magenta	= cl('bold magenta');	$_magenta	= cl('magenta');
$b_cyan		= cl('bold cyan');	$_cyan		= cl('cyan');
$b_white	= cl('bold white');	$_white		= cl('white');
$_reset		= cl('reset');		$_bold		= cl('bold');
$ob		= cl('reset');		$b		= cl('bold');

############################################################################
# Implementation (attribute string form)
############################################################################

# Return the escape code for a given set of color attributes.
sub cl {
    my @codes = map { split } @_;
    my $attribute = '';
    foreach (@codes) {
	$_ = lc $_;
	unless (defined $attributes{$_}) { die "Invalid attribute name $_" }
	$attribute .= $attributes{$_} . ';';
    }
    chop $attribute;
    ($attribute ne '') ? "\e[${attribute}m" : undef;
}

# Given a string and a set of attributes, returns the string surrounded by
# escape codes to set those attributes and then clear them at the end of the
# string.  If $EACHLINE is set, insert a reset before each occurrence of the
# string $EACHLINE and the starting attribute code after the string
# $EACHLINE, so that no attribute crosses line delimiters (this is often
# desirable if the output is to be piped to a pager or some other program).
sub c {
    my $string = shift;
    if (defined $EACHLINE) {
	my $attr = cl (@_);
	join $EACHLINE,
	    map { $_ ne "" ? $attr . $_ . "\e[0m" : "" }
	        split ($EACHLINE, $string);
    } else {
	cl (@_) . $string . "\e[0m";
    }
}

1;
