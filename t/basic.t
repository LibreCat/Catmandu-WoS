use strict;
use Test::More;
use Test::Exception;
use Catmandu::Util qw(is_string is_hash_ref);

my $pkg = 'Catmandu::Importer::WoS';

require_ok $pkg;

my $importer = $pkg->new(username => $ENV{WOK_USERNAME}, password => $ENV{WOK_PASSWORD}, query => 'TS=(cadmium OR lead)');

lives_ok { $importer->wsdl };
lives_ok { $importer->auth_wsdl };

like $importer->wsdl, qr/^<\?xml /;
like $importer->auth_wsdl, qr/^<\?xml /;

ok is_string($importer->session_id);

my $rec = $importer->first;

ok is_hash_ref($rec);
ok is_string($rec->{UID});

done_testing;
