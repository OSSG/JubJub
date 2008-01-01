# JubJub - XMPP packages logger - presence handler
# Copyright (C) 2007, 2008 Fedor A. Fetisov <faf@ossg.ru>. All Rights Reserved
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
