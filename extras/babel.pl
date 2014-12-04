#!/usr/bin/perl
# This program is copyright Jonathan Feinberg 1999.

# This program is distributed under the same terms as infobot.

# Jonathan Feinberg   
# jdf@pobox.com
# http://pobox.com/~jdf/

# Version 1.0
# First public release.
# 
# hacked by Tim@Rikers.org to handle new URL and layout

package babel;
use strict;

my $no_babel;

BEGIN {
    eval "use URI::Escape";    # utility functions for encoding the 
    if ($@) { $no_babel++};    # babelfish request
    eval "use LWP::UserAgent";
    if ($@) { $no_babel++};
}

BEGIN {
  # Translate some feasible abbreviations into the ones babelfish
  # expects.
    use vars qw!%lang_code $lang_regex!;
    %lang_code = (
                fr => 'fr',
                sp => 'es',
                po => 'pt',
                pt => 'pt',
                it => 'it',
                ge => 'de',
                de => 'de',
                gr => 'de',
                en => 'en'
               );
  
  # Here's how we recognize the language you're asking for.  It looks
  # like RTSL saves you a few keystrokes in #perl, huh?
  $lang_regex = join '|', keys %lang_code;
}


sub forking_babelfish {
    return '' if $no_babel;
   my ($direction, $lang, $phrase, $callback) = @_;
   $SIG{CHLD} = 'IGNORE';
   my $pid = eval { fork() };   # catch non-forking OSes and other errors
   return if $pid;              # parent does nothing
   $callback->(babelfish($direction, $lang, $phrase));
   exit 0 if defined $pid;      # child exits, non-forking OS returns
}

sub babelfish {
    return '' if $no_babel;
  my ($direction, $lang, $phrase) = @_;
  
  $lang = $lang_code{$lang};

  my $ua = new LWP::UserAgent;
  $ua->timeout(5);

  my $req =  
    #HTTP::Request->new('POST', 'http://babelfish.altavista.digital.com/cgi-bin/translate');
    #HTTP::Request->new('POST', 'http://babelfish.altavista.com/translate.dyn');
    HTTP::Request->new('POST', 'http://babelfish.altavista.com/raging/translate.dyn');
  $req->content_type('application/x-www-form-urlencoded');

  my $tolang = "en_$lang";
  my $toenglish = "${lang}_en";

  if ($direction eq 'to') {
    return translate($phrase, $tolang, $req, $ua);
  }
  elsif ($direction eq 'from') {
    return translate($phrase, $toenglish, $req, $ua);
  }

  my $last_english = $phrase;
  my $last_lang;
  my %results = ();
  my $i = 0;
  while ($i++ < 7) {
    last if $results{$phrase}++;
    $last_lang = $phrase = translate($phrase, $tolang, $req, $ua);
    last if $results{$phrase}++;
    $last_english = $phrase = translate($phrase, $toenglish, $req, $ua);
  }
  return $last_english;
}


sub translate {
    return '' if $no_babel;
  my ($phrase, $languagepair, $req, $ua) = @_;
  
  my $urltext = uri_escape($phrase);
  $req->content("urltext=$urltext&lp=$languagepair");
  
  my $res = $ua->request($req);

  if ($res->is_success) {
      my $html = $res->content;
      # This method subject to change with the whims of Altavista's design
      # staff.
#print "$html\n===============\n";
      # look for the first :< which should be the "To English:<", etc.
      # strip any trailing tags, grab text that follows up to the next tag.
      my (undef,$translated) = ($html =~ m{:(<[^>]*>\s*)+([^<]*)}sx);
#print "$translated\n===============\n";
#      my ($translated) = ($html =~ m{:(<[^>]*>\s*)+([^<]*)}sx);
#print "$translated\n===============\n";
#       ($html =~ m{<textarea[^>]*>
#               \s*
#               ([^<]*)
#               }sx);
#         ($html =~ m{<br>
#                         \s+
#                             <font\ face="arial,\ helvetica">
#                                 \s*
#                                     (?:\*\*\s+time\ out\s+\*\*)?
#                                         \s*
#                                             ([^<]*)
#                                             }sx);
      $translated =~ s/\n/ /g;
      $translated =~ s/\s*$//;
      return $translated;
  } else {
      return ":("; # failure 
  }
}

if (0) {
    if (-t STDIN) {
        my $result = babel::babelfish('to','sp','hello world');
        $result =~ s/; /\n/g;
        print "Babelfish says: $result\n";
    }
}

1;
