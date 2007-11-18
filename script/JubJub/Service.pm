# JubJub - XMPP packages logger - service functions module
# Copyright (C) 2007 Fedor A. Fetisov <faf@ossg.ru>. All Rights Reserved
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
