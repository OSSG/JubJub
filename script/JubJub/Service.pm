package JubJub::Service;

use strict;

sub new {
    my $package = shift;
    my $self = {};

    $self = bless($self, $package);

    return $self;
}

sub get_jid {
    my $self = shift;
    my $jid = shift;
    $jid =~ s/(\/.*)$//;
    return {'jid' => $jid, 'resource' => $1 || ''};
}

1;
