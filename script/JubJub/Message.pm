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

# проверка на наличие полезной информации в сообщении - иначе это пустое сообщение вида <composing/>
    return unless $message->{'body'} || $message->{'subject'};

    my $current_message = Dumper($message);
    return if ($current_message eq $self->{'last_message'});

    my $participants = { 'from' => $self->{'service'}->get_jid($message->{'from'}),
		    	 'to' => $self->{'service'}->get_jid($message->{'to'}) };

    $message->{'type'} ||= 'normal';

    foreach ('from', 'to') {
# проверка на необходимость записи сообщения
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
# проверка ресурса
	my $resource = ${$self->{'db'}}->sql_select('select * from jubjub_resources where resource=?', $participants->{$_}->{'resource'})->[0];
	unless (defined $resource->{'id'}) {
	    ${$self->{'db'}}->sql_exec('insert into jubjub_resources(resource) values (?)', $participants->{$_}->{'resource'});
	    $resource = ${$self->{'db'}}->sql_select('select * from jubjub_resources where resource=?', $participants->{$_}->{'resource'})->[0];
	    return -2 unless defined $resource->{'id'};
	}
# проверка участника (и с jid, и ресурсом)
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

    ${$self->{'db'}}->sql_exec('insert into jubjub_messages(sender, rcpt, subject, body, message_id, message_time, message_type, thread, error) values (?, ?, ?, ?, ?, now(), (select id from jubjub_message_types where name=?), ?, ?)',
				    $participants->{'from'}->{'id'}, $participants->{'to'}->{'id'}, $message->{'subject'} || '', $message->{'body'} || '', $message->{'id'} || '', $message->{'type'}, $message->{'thread'} || '', $error);

    $self->{'last_message'} = $current_message;	

    return 1;
}

1;



