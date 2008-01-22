# JubJub - XMPP packages logger - database interaction module
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

package JubJub::DB;

use strict;

use DBI;

# constructor method
# returns object with database (connection params sets in config)
sub new {
    my $package = shift;
    my $config = shift;
    my $self = {};

# prepare cache for database requests
    $self->{'requests'} = {};

    my $options = { 'RaiseError' => 1,
		    'ChopBlanks' => 1 };

# to prevent troubles with mysql when using Unicode
    $options->{'mysql_enable_utf8'} = 1 if ($config->{'driver'} eq 'mysql');

# establishing database connection
    unless (${$self->{'database'}} = DBI->connect('dbi:' . $config->{'driver'} .
					    ':dbname=' . $config->{'name'} .
					    ';host=' . $config->{'host'},
					    $config->{'user'},
					    $config->{'passwd'},
					    $options)) {
	print STDERR "Cann't connect to database server: $DBI::errstr";
        ${$self->{'database'}} = undef;
	exit;
    }

# to prevent automated disconnect after timeout by 'smart' mysql (so called 'morning bug')
    ${$self->{'database'}}->{'mysql_auto_reconnect'} = 1 if ($config->{'driver'} eq 'mysql');

    $self = bless($self, $package);

    return $self;
}

# method for execution a database request that should not provide any data selection
# (update / insert / delete и т.д.)
# args: first (optional) - flag to cache the request (in the form of one element array)
# (by default request is caching)
# next - request and data array for placeholders substitution
# examples: $database->sql_exec([0], 'select 1');
# returns 0 on error, or 1 on success
sub sql_exec {
    my $self = shift;
    my $request = shift;
# should request to be cached?
    my $cache = 1;
    if (ref($request) eq 'ARRAY') {
	$cache = $request->[0];
	$request = shift;
    }
    my @args = @_;
# internal method call (for direct request execution)
    my $res = $self->_request($request, @args);
# do not cache request if specified
    if ((defined $cache) && ($cache == 0)) {
	$self->{'requests'}->{$request}->finish();
	delete $self->{'requests'}->{$request};
    }

    return $res;

}

# method for execution a database request that should provide some data selection
# args: first (optional) - flag to cache the request (in the form of one element array)
# (by default request is caching)
# next - request and data array for placeholders substitution
# returns array of hashes, one hash for one resulting data selection string
sub sql_select {
    my $self = shift;
    my $request = shift;
# should request to be cached?
    my $cache = 1;
    if (ref($request) eq 'ARRAY') {
	$cache = $request->[0];
	$request = shift;
    }
    my @args = @_;
    my $res = [];
# database request execution
    if ($self->_request($request, @args)) {
# making resulting array
	while (my $temp = $self->{'requests'}->{$request}->fetchrow_hashref()) {
	    push (@$res, $temp);
	}
    }
# do not cache request if specified
    if ((defined $cache) && ($cache == 0)) {
	$self->{'requests'}->{$request}->finish();
	delete $self->{'requests'}->{$request};
    }
    return $res;
}

# internal method for arbitrary database request execution
# args: request, data array for placeholders substitution
# returns 1 on success, 0 on error
sub _request {
    my $self = shift;
    my $request = shift;
    my @args = @_;

# check for database connection existance
    return 0 unless defined ${$self->{'database'}};

# prepare request
    $self->{'requests'}->{$request} = ${$self->{'database'}}->prepare($request)
				unless (defined $self->{'requests'}->{$request});

# execute request
    return $self->{'requests'}->{$request}->execute(@args) ? 1 : 0;

}

# destructor method
# it's called when object destroying
# correctly (using corresponding object method) closes database connection
sub DESTROY {
    my $self = shift;

# check for connection existance
    if (defined $self->{'database'}) {
# check for cached database requests existance
	if (defined $self->{'requests'}) {
# closing all cached database requests
	    foreach (keys %{$self->{'requests'}}) {
		$self->{'requests'}->{$_}->finish();
	    }
	    delete $self->{'requests'};
	}
#	$self->{'database'}->disconnect();
	delete $self->{'database'};
	return 1;
    }
    else {
# connection doesn't exists
	return 0;
    }

}

1;
