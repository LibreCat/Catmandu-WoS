package Catmandu::Importer::WoS;

use Catmandu::Sane;

our $VERSION = '0.02';

use Moo;
use Catmandu::Util qw(xml_escape);
use XML::LibXML::Simple qw(XMLin);
use namespace::clean;

with 'Catmandu::WoS::Base';

has query => (is => 'ro', required => 1);
has symbolic_timespan => (is => 'ro');
has timespan_begin => (is => 'ro');
has timespan_end => (is => 'ro');

sub _search_url {
    state $url = 'http://search.webofknowledge.com/esti/wokmws/ws/WokSearch';
}

sub _search_ns {
    state $ns = {
        'soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
        'ns2'  => 'http://woksearch.v3.wokmws.thomsonreuters.com',
    };
}

sub _search_content {
    my ($self, $start, $limit) = @_;

    my $query = xml_escape($self->query);

    my $symbolic_timespan_xml = '';
    my $timespan_xml = '';

    if (my $ts = $self->symbolic_timespan) {
        $symbolic_timespan_xml = "<symbolicTimeSpan>$ts</symbolicTimeSpan>";
    } elsif ($self->timespan_begin & $self->timespan_end) {
        my $tsb = $self->timespan_begin;
        my $tse = $self->timespan_end;
        $timespan_xml = "<timeSpan><begin>$tsb</begin><end>$tse</end></timeSpan>";
    }

    <<EOF;
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
   xmlns:woksearch="http://woksearch.v3.wokmws.thomsonreuters.com">
   <soapenv:Header/>
   <soapenv:Body>
      <woksearch:search>
         <queryParameters>
            <databaseId>WOS</databaseId>
            <userQuery>$query</userQuery>
            $symbolic_timespan_xml
            $timespan_xml
            <queryLanguage>en</queryLanguage>
         </queryParameters>
         <retrieveParameters>
            <firstRecord>$start</firstRecord>
          <count>$limit</count>
            <option>
               <key>RecordIDs</key>
               <value>On</value>
            </option>
            <option>
               <key>targetNamespace</key>
               <value>http://scientific.thomsonreuters.com/schema/wok5.4/public/FullRecord</value>
            </option>
     </retrieveParameters>
      </woksearch:search>
   </soapenv:Body>
</soapenv:Envelope>
EOF
}

sub _search_retrieve_content {
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

sub _parse_recs {
    my ($self, $xml) = @_;

    XMLin($xml, ForceArray => 1)->{REC};
}

sub _search {
    my ($self, $start, $limit) = @_;

    my $xpc = $self->_soap_request(
        $self->_search_url,
        $self->_search_ns,
        $self->_search_content($start, $limit),
        $self->session_id
    );

    my $recs_xml = $xpc->findvalue('/soap:Envelope/soap:Body/ns2:searchResponse/return/records');
    my $total = $xpc->findvalue('/soap:Envelope/soap:Body/ns2:searchResponse/return/recordsFound');
    my $query_id = $xpc->findvalue('/soap:Envelope/soap:Body/ns2:searchResponse/return/queryId');

    my $recs = $self->_parse_recs($recs_xml);

    return $recs, $total, $query_id;
}

sub _search_retrieve {
    my ($self, $query_id, $start, $limit) = @_;

    my $xpc = $self->_soap_request(
        $self->_search_url,
        $self->_search_ns,
        $self->_search_retrieve_content($query_id, $start, $limit),
        $self->session_id
    );

    my $recs_xml = $xpc->findvalue('/soap:Envelope/soap:Body/ns2:retrieveResponse/return/records');
    my $recs = $self->_parse_recs($recs_xml);

    return $recs;
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
                $recs = $self->_search_retrieve($query_id, $start, $limit);
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

__END__

=encoding utf-8

=head1 NAME

Catmandu::Importer::WoS - Import Web of Science records

=head1 SYNOPSIS

    # On the command line

    $ catmandu convert WoS --username XXX --password XXX --query 'TS=(lead OR cadmium)' to YAML

    # In perl

    use Catmandu::Importer::WoS;
    
    my $wos = Catmandu::Importer::WoS->new(username => 'XXX', password => 'XXX', query => 'TS=(lead OR cadmium)');
    $wos->each(sub {
        my $record = shift;
        # ...
    });

=head1 AUTHOR

Nicolas Steenlant E<lt>nicolas.steenlant@ugent.beE<gt>

=head1 COPYRIGHT

Copyright 2017- Nicolas Steenlant

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
