#!env perl
use strict;
use warnings;

use POSIX;
use IPC::Run3;
use JSON::XS;

my $filename = '/tmp/' . strftime('%Y-%m-%d', localtime) . '_' . $$ . '.png';
print $filename, "\n";
my ($err, $out);

run3 [qw/scrot -e/, "mv \$f $filename"], undef, undef, \$err
    or die("scrot error: $? : $err");

my $upload_cmd = [qw{curl -X POST http://deviantsart.com -F}, "file=\@${filename}"];

# print "upload command: ", Dumper($upload_cmd), "\n";
run3 $upload_cmd, undef, \$out, \$err
    or die("curl error: $? : $err");

# print $out, $err;
my $url = decode_json($out)->{url};
print "$filename is available on $url", "\n";

run3 [qw/parcellite/], \$url, undef, undef;
run3 [qw/notify-send -t 5000/, "screenshot upload", "$url (available in buffer)" ];
