package JubJub::Presence;

use strict;
use Data::Dumper;
use JubJub::Service;

sub new {
    my $package = shift;
    my $db = shift;
    my $self = {};

    $self->{'db'} = $db;

    $self->{'service'} = new JubJub::Service;

    $self = bless($self, $package);

    return $self;
}

sub action { return 1; }

1;



