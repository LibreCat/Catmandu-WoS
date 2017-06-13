requires 'perl', '5.008005';

requires 'Catmandu', '1.0507';
requires 'File::Share', '0';
requires 'Path::Tiny', '0';
requires 'XML::Compile::WSDL', '3.21';

on test => sub {
    requires 'Test::More', '0.96';
};
