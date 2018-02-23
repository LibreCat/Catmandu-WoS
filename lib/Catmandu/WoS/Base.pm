package Catmandu::WoS::Base;

use Catmandu::Sane;

our $VERSION = '0.02';

use Moo::Role;
use URI::Escape qw(uri_escape);
use XML::LibXML;
use XML::LibXML::XPathContext;
use namespace::clean;

with 'Catmandu::Importer';

has username   => (is => 'ro');
has password   => (is => 'ro');
has session_id => (is => 'lazy');

sub _auth_url {
    my ($self) = @_;

    my $username = uri_escape($self->username);
    my $password = uri_escape($self->password);
    'http://'.uri_escape($self->username).':'.uri_escape($self->password).
        '@search.webofknowledge.com/esti/wokmws/ws/WOKMWSAuthenticate';
}

sub _auth_ns {
    state $ns = {
        'soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
        'ns2'  => 'http://auth.cxf.wokmws.thomsonreuters.com',
    };
}

sub _auth_content {
    state $content = <<EOF;
<soapenv:Envelope
xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
xmlns:auth="http://auth.cxf.wokmws.thomsonreuters.com">
  <soapenv:Header/>
  <soapenv:Body>
    <auth:authenticate/>
  </soapenv:Body>
</soapenv:Envelope>
EOF
}

sub _search_url {
    state $url = 'http://search.webofknowledge.com/esti/wokmws/ws/WokSearch';
}

sub _search_ns {
    state $ns = {
        'soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
        'ns2'  => 'http://woksearch.v3.wokmws.thomsonreuters.com',
    };
}

sub _soap_request {
    my ($self, $url, $ns, $content, $session_id) = @_;

    my $headers = ['Content-Type' => "text/xml; charset=UTF-8"];

    if ($session_id) {
        push @$headers, 'Cookie', qq|SID="$session_id"|;
    }

    my $res_content = $self->_http_request(
        'POST',
        $url,
        $headers,
        $content,
        $self->_http_timing_tries,
    );

    my $doc = XML::LibXML->new(huge => 1)->load_xml(string => $res_content);
    my $xpc = XML::LibXML::XPathContext->new($doc);
    $xpc->registerNs($_ => $ns->{$_}) for keys %$ns;
    $xpc;
}

sub _build_session_id {
    my ($self) = @_;

    my $xpc = $self->_soap_request(
        $self->_auth_url,
        $self->_auth_ns,
        $self->_auth_content,
    );

    my $session_id = $xpc->findvalue('/soap:Envelope/soap:Body/ns2:authenticateResponse/return');

    return $session_id;
}

1;
