#!/usr/bin/perl -w

use strict;

use Net::Jabber;
use Data::Dumper;
use XML::Simple;
use Encode qw(_utf8_off);
use Getopt::Long qw(:config no_ignore_case bundling no_auto_abbrev);
use POSIX;

use JubJub::DB;

my $config;
my $options = {};
GetOptions(
    $options, 'help|?', 'config=s'
) or die "For usage information try: \t$0 --help\n";

if ($options->{'help'}) {
    print <<HELP
ejabberd logger script
Usage: $0 [--config=<file>]
HELP
;

    exit;
}

$options->{'config'} ||= 'config.xml';
unless (-f $options->{'config'}) {
    print STDERR "Can't find configuration file $options->{'config'}: $!\n";
    exit;
}

$config = XMLin($options->{'config'}, 'ForceArray' => ['processor'], 'KeyAttr' => ['type'], 'ContentKey' => '-content');

if (-f $config->{'service'}->{'pid_file'}) {
    print STDERR "Found pid file $config->{'service'}->{'pid_file'}. JubJub already running?\n";
    exit;
}

my $pid = fork();
if ($pid) {
    if (open(OUT, '>' . $config->{'service'}->{'pid_file'})) {
	print OUT $pid;
	close OUT;
    }
    else {
	print STDERR "Can't open pid file: $!\n";
    }
    exit;
}
elsif (!defined $pid) {
    print STDERR "Can't fork: $!\n";
    exit;
}


for my $handle (*STDIN, *STDOUT) {
    unless (open($handle, '+<', '/dev/null')) {
	print STDERR "Can't reopen $handle to /dev/null : $!\n";
	exit;
    }
}

unless (open(*STDERR, '>>', $config->{'service'}->{'error_log'})) {
    print STDERR "Can't reopen STDERR to $config->{'service'}->{'error_log'} : $!\n";
    exit;
}

unless (POSIX::setsid()) {
    print STDERR "Can't start a new session: $!\n";
    exit;
}

my $db;
unless ($db = JubJub::DB->new($config->{'database_connection'})) {
    print STDERR "Can't open database connection: $DBI::errstr\n";
    exit;
}

$SIG{HUP} = $SIG{KILL} = $SIG{TERM} = $SIG{INT} = \&_disconnect;
$SIG{PIPE} = 'IGNORE';

my $jab_conn = new Net::Jabber::Component();
$jab_conn->SetCallBacks( 'receive' => \&processor );

my $procs = {};

$jab_conn->Execute(	'hostname' 	=> $config->{'jabber_connection'}->{'host'},
			'componentname'	=> $config->{'jabber_connection'}->{'component'},
			'secret'	=> $config->{'jabber_connection'}->{'secret'},
			'connectiontype'=> 'tcpip',
			'port'		=> $config->{'jabber_connection'}->{'port'}
);

_disconnect();

sub processor {
    my $sid = shift;
    my $xml = shift;
    my $data = XMLin($xml, 'SuppressEmpty' => '');

#    if ($data->{'from'} eq $config->{'jabber_connection'}->{'hostname'}) {
	foreach (keys(%{$data})) {
	    if (exists $config->{'processors'}->{'processor'}->{$_}) {
	        eval 'require ' . $config->{'processors'}->{'processor'}->{$_} . ';';
		if ($@) {
		    print STDERR "Error when switching on $_ processor: $@\n";
		}
		else {
		    eval {
			$procs->{$_} ||= $config->{'processors'}->{'processor'}->{$_}->new(\$db);
			$procs->{$_}->action($data->{$_});
		    };
		    if ($@) {
			print STDERR "Got error when used $_ processor: $@\n";
		    }
		}
	    }
	}
#    }

}

sub _disconnect {
    undef $db if defined $db;
    $jab_conn->Disconnect() if defined $jab_conn;
    unlink($config->{'service'}->{'pid_file'}) if (-f $config->{'service'}->{'pid_file'});
    exit;
}
