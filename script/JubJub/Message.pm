# JubJub - XMPP packages logger - messages handler
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

package JubJub::Message;

use strict;
use Data::Dumper;
use JubJub::Service;

sub new {
    my $package = shift;
    my $db = shift;
    my $self = {};

    $self->{'db'} = $db;

    $self->{'service'} = new JubJub::Service;

    $self->{'last_message'} = '';

    $self = bless($self, $package);

    return $self;
}

sub action {
    my $self = shift;
    my $message = shift;

# check for valuable information in the message - it can be just empty message like <composing/>
    return unless $message->{'body'} || $message->{'subject'};

    my $current_message = Dumper($message);
    return if ($current_message eq $self->{'last_message'});

    my $participants = { 'from' => $self->{'service'}->get_jid($message->{'from'}),
		    	 'to' => $self->{'service'}->get_jid($message->{'to'}) };

    $message->{'type'} ||= 'normal';

    foreach ('from', 'to') {
# check if we really need to log this message
	my $jid = ${$self->{'db'}}->sql_select('select * from jubjub_jids where jid=?', $participants->{$_}->{'jid'})->[0];
	if (defined $jid->{'id'}) {
	    return 0 unless $jid->{'log_messages'};
	}
	else {
	    ${$self->{'db'}}->sql_exec('insert into jubjub_jids(jid, jid_type) values (?, (select id from jubjub_jid_types where name=?))',
			$participants->{$_}->{'jid'}, 'user');
	    $jid = ${$self->{'db'}}->sql_select('select * from jubjub_jids where jid=?', $participants->{$_}->{'jid'})->[0];
	    return -1 unless defined $jid->{'id'};
	}
# resource check
	my $resource = ${$self->{'db'}}->sql_select('select * from jubjub_resources where resource=?', $participants->{$_}->{'resource'})->[0];
	unless (defined $resource->{'id'}) {
	    ${$self->{'db'}}->sql_exec('insert into jubjub_resources(resource) values (?)', $participants->{$_}->{'resource'});
	    $resource = ${$self->{'db'}}->sql_select('select * from jubjub_resources where resource=?', $participants->{$_}->{'resource'})->[0];
	    return -2 unless defined $resource->{'id'};
	}
# participant check (by jid and by resource)
	my $participant = ${$self->{'db'}}->sql_select('select * from jubjub_participants where resource=? and jid=?', $resource->{'id'}, $jid->{'id'})->[0];
	unless (defined $participant->{'id'}) {
	    ${$self->{'db'}}->sql_exec('insert into jubjub_participants(resource, jid) values (?, ?)', $resource->{'id'}, $jid->{'id'});
	    $participant = ${$self->{'db'}}->sql_select('select * from jubjub_participants where resource=? and jid=?', $resource->{'id'}, $jid->{'id'})->[0];
	    return -3 unless defined $participant->{'id'};
	}
	$participants->{$_}->{'id'} = $participant->{'id'};
    }

    my $error = undef;
    if (($message->{'type'} eq 'error') && (defined $message->{'error'})) {
	my $condition = '';
	foreach (keys %{$message->{'error'}}) {
	    next if (($_ eq 'code') || ($_ eq 'type') || ($_ eq 'text'));
	    $condition = $_;
	}
	$error = ${$self->{'db'}}->sql_select('select id from jubjub_errors where code=? and error_condition=?', $message->{'error'}->{'code'}, $condition)->[0]->{'id'};
	unless (defined $error) {
	    ${$self->{'db'}}->sql_exec('insert into jubjub_errors(code, error_condition) values (?, ?)', $message->{'error'}->{'code'}, $condition);
	    $error = ${$self->{'db'}}->sql_select('select id from jubjub_errors where code=? and error_condition=?', $message->{'error'}->{'code'}, $condition)->[0]->{'id'};
	    return -4 unless defined $error;
	}
    }

    ${$self->{'db'}}->sql_exec('insert into jubjub_messages(sender, rcpt, subject, body, message_id, message_time, message_type, thread, error) values (?, ?, ?, ?, ?, now(),
				    (select coalesce((select id from jubjub_message_types where name=?), (select id from jubjub_message_types where name=?))), ?, ?)',
				    $participants->{'from'}->{'id'}, $participants->{'to'}->{'id'}, $message->{'subject'} || '', $message->{'body'} || '', $message->{'id'} || '',
					$message->{'type'}, 'unknown', $message->{'thread'} || '', $error);

    $self->{'last_message'} = $current_message;	

    return 1;
}

1;
