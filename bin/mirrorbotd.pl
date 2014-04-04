#!/usr/bin/perl

##
# MirrorBot 1.0
# Copyright (c) 2011 - 2014 by Joseph Huckaby
# Source Code released under the MIT License: 
# http://www.opensource.org/licenses/mit-license.php
##

use strict;
use File::Basename;
use Bot::BasicBot;
use Data::Dumper;
use Cwd qw/abs_path/;
use Carp ();
use POSIX qw/:sys_wait_h setsid/;
use POE;

$| = 1;

# figure out our base dir and cd into it
my $base_dir = dirname(dirname(abs_path($0)));
chdir( $base_dir );

# load our modules
push @INC, "$base_dir/lib";
eval "use VersionInfo;";
eval "use Tools;";
eval "use Mirror;";

$| = 1;

my $config = {};
my @orig_argv = @ARGV;

# load config from xml file
if (@ARGV && ($ARGV[0] =~ /\.xml$/i)) {
	my $config_file = shift @ARGV;
	$config = parse_xml( $config_file );
	if (!ref($config)) { die $config; }
}
else {
	die "Usage: ./mirror_bot.pl CONFIGFILE\n";
}

my $cmdline_args = new Args();
$config->{Common} ||= {};
foreach my $key (keys %$cmdline_args) {
	$config->{Common}->{$key} = $cmdline_args->{$key};
}

if ($cmdline_args->{debug}) {
	# debug mode, catch all crashes and emit stack trace
	$SIG{'__DIE__'} = sub { Carp::cluck("Stack Trace: "); };
}
else {
	# not running in cmd-line debug mode, so fork daemon process, write pid file
	become_daemon();
	
	# write pid file
	save_file( 'logs/pid.txt', $$ );
}

my $bots = [];

# setup left and right sides of mirror
foreach my $params ($config->{Left}, $config->{Right}) {
	# copy in common params
	foreach my $key (keys %{$config->{Common}}) { $params->{$key} = $config->{Common}->{$key}; }
	
	# setup ignore list
	my $ignore = {};
	if ($params->{ignore}) {
		$ignore = { map { $_ => 1; } split(/\W+/, $params->{ignore} || '') };
	}
	
	# detect justin.tv server which enables special behavior
	$params->{jtv} = ($params->{server} =~ /\.(jtvirc|twitch)\./) ? 1 : 0;

	# with all known options
	my $bot = Bot::BasicBot::Mirror->new(
	
		params => $params,

		server => $params->{server},
		port	 => $params->{port},
		password => $params->{server_password} || undef,
		channels => [ split(/\s+/, $params->{channel}) ],
	
		nick			=> $params->{nick},
		# alt_nicks => ["bbot", "simplebot"],
		username	=> $params->{username} || $params->{nick},
		name			=> $params->{name} || $params->{nick},
	
		# ignore_list => [qw(dipsy dadadodo laotse)],

		charset => "utf-8", # charset the bot assumes the channel is using	
		
		no_run => 1, # do not call POE::Kernel->run automatically
		
		ignore => $ignore,
				
		# send messages to IRC at FULL SPEED
		flood => $params->{flood} || 0,
		
		# throttle control, dupe control
		last_say_str => '',
		last_say_time => 0,
		say_queue => []
	);
	
	push @$bots, $bot;
}

# only one bot needs to run daily maintenance
$bots->[0]->{maint_enabled} = 1;

# each bot ignores the other
$bots->[0]->{ignore}->{ lc($bots->[1]->{nick}) } = 1;
$bots->[1]->{ignore}->{ lc($bots->[0]->{nick}) } = 1;

# connect the bots together
$bots->[0]->{mirror} = $bots->[1];
$bots->[1]->{mirror} = $bots->[0];

$SIG{'INT'} = $SIG{'TERM'} = sub {
	# catch termination signal or ctrl-c and perform clean shutdown
	local $SIG{ALRM} = sub { die "Shutdown Timeout\n" };
	alarm 5;
	foreach my $bot (@$bots) {
		if (!$bot->{_shutdown_flag}) {
			$bot->{_shutdown_flag} = 1;
			$bot->shutdown( $bot->quit_message() ); 
		}
	}
	alarm 0;
};

# run bots
foreach my $bot (@$bots) { $bot->run(); }

POE::Kernel->run();

$SIG{'__DIE__'} = undef;
unlink('logs/pid.txt');

# check for reload flag
foreach my $bot (@$bots) {
	if ($bot->{request_reload}) {
		sleep 1;
		exec( $0, @orig_argv );
		exit();
	}
}

exit;

sub become_daemon {
	##
	# Fork daemon process and disassociate from terminal
	##
	my $pid = fork();
	if (!defined($pid)) { die "Error: Cannot fork daemon process: $!\n"; }
	if ($pid) { exit(0); }
	
	setsid();
	open( STDIN, "</dev/null" );
	open( STDOUT, ">/dev/null" );
	umask( 0 );
	
	return $$;
}

1;
