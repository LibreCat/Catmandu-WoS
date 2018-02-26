package Catmandu::WoS::Base;

use Catmandu::Sane;

our $VERSION = '0.02';

use Moo::Role;
use URI::Escape qw(uri_escape);
use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::LibXML::Simple qw(XMLin);
use namespace::clean;

with 'Catmandu::Importer';

has username   => (is => 'ro');
has password   => (is => 'ro');
has session_id => (is => 'lazy');

requires '_search';

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

sub _retrieve_content {
    my ($self, $query_id, $start, $limit) = @_;

    $query_id = xml_escape($query_id);

    <<EOF;
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
  <ns2:retrieve xmlns:ns2="http://woksearch.v3.wokmws.thomsonreuters.com">
    <queryId>$query_id</queryId>
    <retrieveParameters>
       <firstRecord>$start</firstRecord>
       <count>$limit</count>
    </retrieveParameters>
  </ns2:retrieve>
</soap:Body>
</soap:Envelope>
EOF
}

sub _retrieve {
    my ($self, $query_id, $start, $limit) = @_;

    my $xpc = $self->_soap_request(
        $self->_search_url,
        $self->_search_ns,
        $self->_retrieve_content($query_id, $start, $limit),
        $self->session_id
    );

    my $recs_xml = $xpc->findvalue('/soap:Envelope/soap:Body/ns2:retrieveResponse/return/records');
    my $recs = $self->_parse_recs($recs_xml);

    return $recs;
}

sub _parse_recs {
    my ($self, $xml) = @_;

    XMLin($xml, ForceArray => 1)->{REC};
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

sub generator {
    my ($self) = @_;

    sub {
        state $recs = [];
        state $query_id;
        state $start = 1;
        state $limit = 100;
        state $total;

        unless (@$recs) {
            return if defined $total && $start > $total;

            if (defined $query_id) {
                $recs = $self->_retrieve($query_id, $start, $limit);
            }
            else {
                ($recs, $total, $query_id) = $self->_search($start, $limit);
                $total || return;
            }

            $start += $limit;
        }

        shift @$recs;
    };
}

1;
