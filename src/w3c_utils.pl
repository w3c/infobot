# w3c_utils for infobot Ted Guild 2007

use DB_File;
use Fcntl;

#$nick_msgdb="/tmp/messages_infobot.db";
#print getparam('plusplus');
#$nick_msgdb=getparam('messagefile');


sub checkNickMessages {
    my $w3c_qnick=lc(shift);
    my $nick_msgdb=getparam('informdb');
    dbmopen(%DB, $nick_msgdb, 0644 );
    my $msg=$DB{$w3c_qnick};
    delete $DB{$w3c_qnick};
    dbmclose(%DB );
    return $msg;
}

sub setNickMessage {
    my $nick_msgdb=getparam('informdb');
    dbmopen(%DB, $nick_msgdb, 0644 );
    my $w3c_qnick=lc(shift);
    my $w3c_qmsg=shift;
    $DB{$w3c_qnick}.=(($DB{$w3c_qnick})?" and ":"").$w3c_qmsg;
    dbmclose(%DB );
}

sub getGMTtimestamp {
    my ($sec,$min,$hours,$mday,$month,$year,$wday,$yday) = gmtime;
    my $isotime = sprintf("%04d-%02d-%02d %02d:%02d UTC",
        ($year+1900), ($month+1), $mday, $hours, $min );
    return $isotime;
}

1;
