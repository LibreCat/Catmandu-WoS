package Catmandu::Importer::WoS;

use Catmandu::Sane;

our $VERSION = '0.01';

use File::Share qw(dist_file);
use Path::Tiny qw(path);
use Moo;
use namespace::clean;

with 'Catmandu::Importer';

sub generator {

}

sub wok_wsdl {
    state $wsdl = path(dist_file('Catmandu-WoS', 'wok.wsdl'))->slurp_utf8;
}

sub wok_auth_wsdl {
    state $wsdl = path(dist_file('Catmandu-WoS', 'wok_auth.wsdl'))->slurp_utf8;
}

1;
__END__

=encoding utf-8

=head1 NAME

Catmandu::Importer::WoS - Blah blah blah

=head1 SYNOPSIS

  use Catmandu::Importer::WoS;

=head1 DESCRIPTION

Catmandu::Importer::WoS is

=head1 AUTHOR

Nicolas Steenlant E<lt>nicolas.steenlant@ugent.beE<gt>

=head1 COPYRIGHT

Copyright 2017- Nicolas Steenlant

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
