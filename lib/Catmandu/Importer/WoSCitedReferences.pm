package Catmandu::Importer::WoSCitedReferences;

use Catmandu::Sane;

our $VERSION = '0.02';

use Moo;
use Catmandu::Util qw(is_string xml_escape);
use namespace::clean;

with 'Catmandu::WoS::Base';

has uid => (is => 'ro', required => 1);

sub _cited_references_content {
    my ($self, $start, $limit) = @_;

    my $uid = xml_escape($self->uid);

    <<EOF;
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
   xmlns:woksearch="http://woksearch.v3.wokmws.thomsonreuters.com">
   <soapenv:Header/>
   <soapenv:Body>
      <woksearch:citedReferences>
         <databaseId>WOS</databaseId>
         <uid>$uid</uid>
         <queryLanguage>en</queryLanguage>
         <retrieveParameters>
            <firstRecord>$start</firstRecord>
            <count>$limit</count>
            <option>
              <key>Hot</key>
              <value>On</value>
            </option>
         </retrieveParameters>
      </woksearch:citedReferences>
   </soapenv:Body>
</soapenv:Envelope>
EOF
}

sub _cited_references_retrieve_content {
    my ($self, $query_id, $start, $limit) = @_;

    $query_id = xml_escape($query_id);

    <<EOF;
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
   <soap:Header/>
   <soap:Body>
      <woksearch:citedReferencesRetrieve xmlns:woksearch="http://woksearch.v3.wokmws.thomsonreuters.com">
         <queryId>$query_id</queryId>
         <retrieveParameters>
            <firstRecord>$start</firstRecord>
            <count>$limit</count>
         </retrieveParameters>
      </woksearch:citedReferencesRetrieve>
   </soap:Body>
</soap:Envelope>
EOF
}

sub _find_references {
    my ($self, $xpc, $path) = @_;
    my @nodes = $xpc->findnodes($path);
    [
        map {
            my $node = $_;
            my $ref  = {};
            for my $key (
                qw(uid docid articleId citedAuthor timesCited year page volume citedTitle citedWork hot)
                )
            {
                my $val = $node->findvalue($key);
                $ref->{$key} = $val if is_string($val);
            }
            $ref;
        } @nodes
    ];
}

sub _search {
    my ($self, $start, $limit) = @_;

    my $xpc
        = $self->_soap_request($self->_search_url, $self->_search_ns,
        $self->_cited_references_content($start, $limit),
        $self->session_id);

    my $references = $self->_find_references($xpc,
        '/soap:Envelope/soap:Body/ns2:citedReferencesResponse/return/references'
    );
    my @reference_nodes
        = $xpc->findnodes(
        '/soap:Envelope/soap:Body/ns2:citedReferencesResponse/return/references'
        );
    my $total
        = $xpc->findvalue(
        '/soap:Envelope/soap:Body/ns2:citedReferencesResponse/return/recordsFound'
        );
    my $query_id
        = $xpc->findvalue(
        '/soap:Envelope/soap:Body/ns2:citedReferencesResponse/return/queryId'
        );

    return $references, $total, $query_id;
}

sub _retrieve {
    my ($self, $query_id, $start, $limit) = @_;

    my $xpc = $self->_soap_request(
        $self->_search_url,
        $self->_search_ns,
        $self->_cited_references_retrieve_content($query_id, $start, $limit),
        $self->session_id
    );

    $self->_find_references($xpc,
        '/soap:Envelope/soap:Body/ns2:citedReferencesRetrieveResponse/return/references'
    );
}

1;

1;

__END__

=encoding utf-8

=head1 NAME

Catmandu::Importer::WoSCitedReferences - Import Web of Science cited references for a given record

=head1 SYNOPSIS

    # On the command line

    $ catmandu convert WoSCitedReferences --username XXX --password XXX --uid 'WOS:000413520000001' to YAML

    # In perl

    use Catmandu::Importer::WoS;
    
    my $wos = Catmandu::Importer::WoSCitedReferences->new(username => 'XXX', password => 'XXX', uid => 'WOS:000413520000001');
    $wos->each(sub {
        my $cite = shift;
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
