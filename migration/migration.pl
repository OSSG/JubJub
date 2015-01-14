#!/usr/bin/perl

use strict;
use warnings;

use DBI;

my $config = {
    'driver' => 'mysql',
    'name' => 'jubjub',
    'host' => 'mysql.internal',
    'user' => '',
    'passwd' => ''
};

my $options = {
    'RaiseError' => 1,
    'ChopBlanks' => 1,
    'mysql_enable_utf8' => 1
};

# establishing database connection
my $dbh = DBI->connect( 'dbi:' . $config->{'driver'} .
                        ':dbname=' . $config->{'name'} .
                        ';host=' . $config->{'host'},
                        $config->{'user'},
                        $config->{'passwd'},
                        $options )
    || die "Can't connect to database server: $DBI::errstr";

# to prevent automated disconnect after timeout by 'smart' mysql (so called 'morning bug')
$dbh->{'mysql_auto_reconnect'} = 1;

my $requests = [
    $dbh->prepare('select * from jubjub_messages'),
    $dbh->prepare('select jid from jubjub_participants where id = ?'),
    $dbh->prepare('update jubjub_messages set sender_jid = ?, rcpt_jid where id = ?')
];

$requests->[0]->execute();
while (my $message = $requests->[0]->fetchrow_hashref()) {
    my ($sender, $rcpt);
    $requests->[1]->execute($message->{'sender'});
    unless ($sender = $requests->[1]->fetchrow_hashref()) {
        warn 'Bad sender in message ' . $message->{'id'} . ' . Skipped.';
        next;
    }
    $requests->[1]->execute($message->{'rcpt'});
    unless ($rcpt = $requests->[1]->fetchrow_hashref()) {
        warn 'Bad recepient in message ' . $message->{'id'} . ' . Skipped.';
        next;
    }
    unless ($requests->[2]->execute($sender->{'jid'}, $rcpt->{'jid'}, $message->{'id'})) {
        warn 'Failed to set JIDs for message ' . $message->{'id'} . ' : ' . $DBI::errstr;
    }
}
