requires 'perl', '5.008005';

requires 'Catmandu', '1.0507';
requires 'namespace::clean', '0';
requires 'URI::Escape', '0';
requires 'XML::LibXML', '0';

on test => sub {
    requires 'Test::More', '0.96';
};
