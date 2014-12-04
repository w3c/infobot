#!/usr/bin/perl

# exchange.pl - currency exchange "module"
#
# Last update: 990818 08:30:10, bobby@bofh.dk
#

BEGIN {
    eval qq{
	use LWP::UserAgent;
	use HTTP::Request::Common qw(POST GET);
    };

    $no_exchange++ if($@);
}

sub exchange {
    my($From, $To, $Amount) = @_;

    return "exchange.pl: not configured. needs LWP::UserAgent and HTTP::Request::Common" 
	if( $no_exchange );

    my $retval = '';

    my $ua = new LWP::UserAgent;
    $ua->agent("Mozilla/4.5 " . $ua->agent);        # Let's pretend
    if (my $proxy = main::getparam('httpproxy')) { $ua->proxy('http', $proxy) };
    $ua->timeout(10);

    my $Referer = 'http://www.xe.net/ucc/full.shtml';
    my $Converter='http://www.xe.net/ucc/convert.cgi';

    # Get a list of currency abbreviations...
    my $grab = GET $Referer;
    my $reply = $ua->request($grab);
    if (!$reply->is_success) {
	return "EXCHANGE: ".$reply->status_line;
    }
    my $html = $reply->as_string;
    my %Currencies = (grep /\S+/,
	    ($html =~ /option value="([^"]+)">.*?,\s*([^<]+)</gi)
	);

    my %CurrLookup = reverse ($html =~ /option value="([^"]+)">([^<]+)</gi);

    %tld2country = &GetTlds;
    if( $From =~ /^\.(\w\w)$/ ){	# Probably a tld
	$From = $tld2country{uc $1};
    }
    if( $To =~ /^\.(\w\w)$/ ){	# Probably a tld
	$To = $tld2country{uc $1};
    }

    if($#_ == 0){
	# Country lookup
	# crysflame++ for the space fix. 
	$retval = '';
	foreach my $Found (grep /$From/i, keys %CurrLookup){
	    $Found =~ s/,/ uses/g;
	    $retval .= "$Found, ";
	}
	$retval =~ s/(?:, )?\|?$//;
	return substr($retval, 0, 510);
    }else{

	# Make sure that $Amount is of the form \d+(\.\d\d)?
	$Amount =~ s/[,.](\d\d)$/\01$1/;
	$Amount =~ s/[,.]//g;
	$Amount =~ s/\01/./;

	# Get the exact currency abbreviations
	my $newFrom = &GetAbb($From, %CurrLookup);
	my $newTo = &GetAbb($To, %CurrLookup);

	$From = $newFrom if $newFrom;
	$To   = $newTo   if $newTo;

	if( exists $Currencies{$From} and exists $Currencies{$To} ){

	    my $req = POST $Converter,
			[   timezone    => 'UTC',
			    From	=> $From,
			    To		=> $To,
			    Amount	=> $Amount,
			];

	    # Falsify where we came from
	    $req->referer($Referer);

	    my $res = $ua->request($req);                   # Submit request

	    if ($res->is_success) {                         # Went through ok
		my $html = $res->as_string;

		my ($When, $Cfrom, $Cto) =
		    grep /\S+/, ($html =~ m/Rates as of (\d{4}\.\d\d.\d\d\s\d\d:\d\d:\d\d\s\S+)|([\d,.]+)\s*$From|([\d,.]+)\s* $To/gi);

		if ($When) {
		    return "$Cfrom ($Currencies{$From}) makes ".
			"$Cto ($Currencies{$To})"; # ." ($When)\n";
		} else {
		    return "i got some error trying that";
		}
	    } else {                                        # Oh dear.
		return "EXCHANGE: ". $res->status_line;
	    }
	}else{
	    return "Don't know about \"$From\" as a currency" if( ! exists $Currencies{$From} );
	    return "Don't know about \"$To\" as a currency" if( ! exists $Currencies{$To} );
	}
    }
}

sub GetAbb {
    my($LookFor,%Hash) = @_;

    my $Found = (grep /$LookFor/i, keys %Hash)[0];
    $Found =~ m/\((\w\w\w)\)/;
    return $1;
}

sub GetTlds {
	my %Hash = (
			"AF", "AFGHANISTAN",
			"AL", "ALBANIA",
			"DZ", "ALGERIA",
			"AS", "AMERICAN SAMOA",
			"AD", "ANDORRA",
			"AO", "ANGOLA",
			"AI", "ANGUILLA",
			"AQ", "ANTARCTICA",
			"AG", "ANTIGUA AND BARBUDA",
			"AR", "ARGENTINA",
			"AM", "ARMENIA",
			"AW", "ARUBA",
			"AU", "AUSTRALIA",
			"AT", "AUSTRIA",
			"AZ", "AZERBAIJAN",
			"BS", "BAHAMAS",
			"BH", "BAHRAIN",
			"BD", "BANGLADESH",
			"BB", "BARBADOS",
			"BY", "BELARUS",
			"BE", "BELGIUM",
			"BZ", "BELIZE",
			"BJ", "BENIN",
			"BM", "BERMUDA",
			"BT", "BHUTAN",
			"BO", "BOLIVIA",
			"BA", "BOSNIA AND HERZEGOWINA",
			"BW", "BOTSWANA",
			"BV", "BOUVET ISLAND",
			"BR", "BRAZIL",
			"IO", "BRITISH INDIAN OCEAN TERRITORY",
			"BN", "BRUNEI DARUSSALAM",
			"BG", "BULGARIA",
			"BF", "BURKINA FASO",
			"BI", "BURUNDI",
			"KH", "CAMBODIA",
			"CM", "CAMEROON",
			"CA", "CANADA",
			"CV", "CAPE VERDE",
			"KY", "CAYMAN ISLANDS",
			"CF", "CENTRAL AFRICAN REPUBLIC",
			"TD", "CHAD",
			"CL", "CHILE",
			"CN", "CHINA",
			"CX", "CHRISTMAS ISLAND",
			"CC", "COCOS (KEELING) ISLANDS",
			"CO", "COLOMBIA",
			"KM", "COMOROS",
			"CG", "CONGO",
			"CD", "CONGO, THE DEMOCRATIC REPUBLIC OF THE",
			"CK", "COOK ISLANDS",
			"CR", "COSTA RICA",
			"CI", "COTE D'IVOIRE",
			"HR", "CROATIA (local name: Hrvatska)",
			"CU", "CUBA",
			"CY", "CYPRUS",
			"CZ", "CZECH REPUBLIC",
			"DK", "DENMARK",
			"DJ", "DJIBOUTI",
			"DM", "DOMINICA",
			"DO", "DOMINICAN REPUBLIC",
			"TP", "EAST TIMOR",
			"EC", "ECUADOR",
			"EG", "EGYPT",
			"SV", "EL SALVADOR",
			"GQ", "EQUATORIAL GUINEA",
			"ER", "ERITREA",
			"EE", "ESTONIA",
			"ET", "ETHIOPIA",
			"FK", "FALKLAND ISLANDS (MALVINAS)",
			"FO", "FAROE ISLANDS",
			"FJ", "FIJI",
			"FI", "FINLAND",
			"FR", "FRANCE",
			"FX", "FRANCE, METROPOLITAN",
			"GF", "FRENCH GUIANA",
			"PF", "FRENCH POLYNESIA",
			"TF", "FRENCH SOUTHERN TERRITORIES",
			"GA", "GABON",
			"GM", "GAMBIA",
			"GE", "GEORGIA",
			"DE", "GERMANY",
			"GH", "GHANA",
			"GI", "GIBRALTAR",
			"GR", "GREECE",
			"GL", "GREENLAND",
			"GD", "GRENADA",
			"GP", "GUADELOUPE",
			"GU", "GUAM",
			"GT", "GUATEMALA",
			"GN", "GUINEA",
			"GW", "GUINEA-BISSAU",
			"GY", "GUYANA",
			"HT", "HAITI",
			"HM", "HEARD AND MC DONALD ISLANDS",
			"VA", "HOLY SEE (VATICAN CITY STATE)",
			"HN", "HONDURAS",
			"HK", "HONG KONG",
			"HU", "HUNGARY",
			"IS", "ICELAND",
			"IN", "INDIA",
			"ID", "INDONESIA",
			"IR", "IRAN (ISLAMIC REPUBLIC OF)",
			"IQ", "IRAQ",
			"IE", "IRELAND",
			"IL", "ISRAEL",
			"IT", "ITALY",
			"JM", "JAMAICA",
			"JP", "JAPAN",
			"JO", "JORDAN",
			"KZ", "KAZAKHSTAN",
			"KE", "KENYA",
			"KI", "KIRIBATI",
			"KP", "KOREA, DEMOCRATIC PEOPLE'S REPUBLIC OF",
			"KR", "KOREA, REPUBLIC OF",
			"KW", "KUWAIT",
			"KG", "KYRGYZSTAN",
			"LA", "LAO PEOPLE'S DEMOCRATIC REPUBLIC",
			"LV", "LATVIA",
			"LB", "LEBANON",
			"LS", "LESOTHO",
			"LR", "LIBERIA",
			"LY", "LIBYAN ARAB JAMAHIRIYA",
			"LI", "LIECHTENSTEIN",
			"LT", "LITHUANIA",
			"LU", "LUXEMBOURG",
			"MO", "MACAU",
			"MK", "MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF",
			"MG", "MADAGASCAR",
			"MW", "MALAWI",
			"MY", "MALAYSIA",
			"MV", "MALDIVES",
			"ML", "MALI",
			"MT", "MALTA",
			"MH", "MARSHALL ISLANDS",
			"MQ", "MARTINIQUE",
			"MR", "MAURITANIA",
			"MU", "MAURITIUS",
			"YT", "MAYOTTE",
			"MX", "MEXICO",
			"FM", "MICRONESIA, FEDERATED STATES OF",
			"MD", "MOLDOVA, REPUBLIC OF",
			"MC", "MONACO",
			"MN", "MONGOLIA",
			"MS", "MONTSERRAT",
			"MA", "MOROCCO",
			"MZ", "MOZAMBIQUE",
			"MM", "MYANMAR",
			"NA", "NAMIBIA",
			"NR", "NAURU",
			"NP", "NEPAL",
			"NL", "NETHERLANDS",
			"AN", "NETHERLANDS ANTILLES",
			"NC", "NEW CALEDONIA",
			"NZ", "NEW ZEALAND",
			"NI", "NICARAGUA",
			"NE", "NIGER",
			"NG", "NIGERIA",
			"NU", "NIUE",
			"NF", "NORFOLK ISLAND",
			"MP", "NORTHERN MARIANA ISLANDS",
			"NO", "NORWAY",
			"OM", "OMAN",
			"PK", "PAKISTAN",
			"PW", "PALAU",
			"PA", "PANAMA",
			"PG", "PAPUA NEW GUINEA",
			"PY", "PARAGUAY",
			"PE", "PERU",
			"PH", "PHILIPPINES",
			"PN", "PITCAIRN",
			"PL", "POLAND",
			"PT", "PORTUGAL",
			"PR", "PUERTO RICO",
			"QA", "QATAR",
			"RE", "REUNION",
			"RO", "ROMANIA",
			"RU", "RUSSIAN FEDERATION",
			"RW", "RWANDA",
			"KN", "SAINT KITTS AND NEVIS",
			"LC", "SAINT LUCIA",
			"VC", "SAINT VINCENT AND THE GRENADINES",
			"WS", "SAMOA",
			"SM", "SAN MARINO",
			"ST", "SAO TOME AND PRINCIPE",
			"SA", "SAUDI ARABIA",
			"SN", "SENEGAL",
			"SC", "SEYCHELLES",
			"SL", "SIERRA LEONE",
			"SG", "SINGAPORE",
			"SK", "SLOVAKIA (Slovak Republic)",
			"SI", "SLOVENIA",
			"SB", "SOLOMON ISLANDS",
			"SO", "SOMALIA",
			"ZA", "SOUTH AFRICA",
			"GS", "SOUTH GEORGIA AND THE SOUTH SANDWICH ISLANDS",
			"ES", "SPAIN",
			"LK", "SRI LANKA",
			"SH", "ST. HELENA",
			"PM", "ST. PIERRE AND MIQUELON",
			"SD", "SUDAN",
			"SR", "SURINAME",
			"SJ", "SVALBARD AND JAN MAYEN ISLANDS",
			"SZ", "SWAZILAND",
			"SE", "SWEDEN",
			"CH", "SWITZERLAND",
			"SY", "SYRIAN ARAB REPUBLIC",
			"TW", "TAIWAN, PROVINCE OF CHINA",
			"TJ", "TAJIKISTAN",
			"TZ", "TANZANIA, UNITED REPUBLIC OF",
			"TH", "THAILAND",
			"TG", "TOGO",
			"TK", "TOKELAU",
			"TO", "TONGA",
			"TT", "TRINIDAD AND TOBAGO",
			"TN", "TUNISIA",
			"TR", "TURKEY",
			"TM", "TURKMENISTAN",
			"TC", "TURKS AND CAICOS ISLANDS",
			"TV", "TUVALU",
			"UG", "UGANDA",
			"UA", "UKRAINE",
			"AE", "UNITED ARAB EMIRATES",
			"GB", "UNITED KINGDOM",
			"US", "UNITED STATES",
			"UM", "UNITED STATES MINOR OUTLYING ISLANDS",
			"UY", "URUGUAY",
			"UZ", "UZBEKISTAN",
			"VU", "VANUATU",
			"VE", "VENEZUELA",
			"VN", "VIET NAM",
			"VG", "VIRGIN ISLANDS (BRITISH)",
			"VI", "VIRGIN ISLANDS (U.S.)",
			"WF", "WALLIS AND FUTUNA ISLANDS",
			"EH", "WESTERN SAHARA",
			"YE", "YEMEN",
			"YU", "YUGOSLAVIA",
			"ZM", "ZAMBIA",
			"ZW", "ZIMBABWE",
			);
    return %Hash;
}

"That's all folks ;-)";

__END__

=head1 NAME

exchange.pl - Exchange between currencies

=head1 PREREQUISITES

	LWP::UserAgent
	HTTP::Request::Common

=head1 PARAMETERS

exchange

=head1 PUBLIC INTERFACE

	Exchange <amount> <currency> for|[in]to <currency>

=head1 DESCRIPTION

Contacts C<www.xe.net> and grabs the exchange rates; warning - the
currency code is a bit cranky.

=head1 AUTHORS

Bobby <bobby@bofh.dk>
