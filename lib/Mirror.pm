package Bot::BasicBot::Mirror;

use strict;
use FileHandle;
use File::Basename;
use Bot::BasicBot;
use Data::Dumper;
use HTTP::Date;
use POE;
use Tools;
use Time::HiRes qw/time sleep/;
use URI::Escape;

use VersionInfo;

# our @ISA = ("Bot::BasicBot");
use base qw( Bot::BasicBot );

sub get_users {
	# get hash of users
	my $self = shift;
	my $channel = nch($self->{params}->{channel});
	my $nicks = $self->channel_data( $channel );
	my $users = {};
	my $irc = $self->pocoirc();
	
	foreach my $nick (keys %$nicks) {
		$users->{ lc($nick) } = {
			%{$nicks->{$nick}},
			half => $irc->_nick_has_channel_mode($channel, $nick, 'h') ? 1 : 0,
			admin => $irc->_nick_has_channel_mode($channel, $nick, 'a') ? 1 : 0,
			founder => $irc->_nick_has_channel_mode($channel, $nick, 'q') ? 1 : 0
		};
	}
	return $users;
}

sub normalize_channel {
	# make sure channel name always starts with a single hashmark
	my $channel = trim( shift @_ );
	if ($channel !~ /^\#/) { $channel = '#' . $channel; }
	return $channel;
}
sub nch { return normalize_channel(@_); }

sub log_debug {
	# print message to debug log
	my $self = shift;
	my $msg = shift;
	
	my $log_file = $self->{params}->{log_file} || 'logs/debug.log';
	my $fh = new FileHandle ">>$log_file";
	my $id = $self->{server};
	
	$msg =~ s/\n/ /g;
	$msg =~ s/\s+/ /g;
	
	my $line = '[' . join('][', 
		time(),
		(scalar localtime()),
		$$,
		$id,
		$self->{nick},
		trim($msg)
	) . "]\n";
	
	$fh->print( $line );
	$fh->close();
	
	if ($self->{params}->{debug}) {
		# echo log to console
		print $line;
	}
}
sub log { my $self = shift; $self->log_debug(@_); }

sub mirror_exit {
	# shut down both bots
	my $self = shift;
	return if $self->{_shutdown_flag};
	$self->{_shutdown_flag} = 1;
	
	$self->log_debug("Shutting down");
	
	if ($self->{mirror}) {
		delete $self->{mirror}->{mirror};
		$self->{mirror}->{_shutdown_flag} = 1;
		$self->{mirror}->shutdown( $self->{mirror}->quit_message() );
		delete $self->{mirror};
	}
	$self->shutdown( $self->quit_message() );
}

sub crash {
	# log crash and exit
	my $self = shift;
	my $msg = shift;
	
	$self->log_debug( "CRASH: $@" ); 
	$self->mirror_exit();
}

sub check_admin {
	# check if user is a bot admin
	my ($self, $username) = @_;
	
	$username = lc($username);
	if ($username eq $self->{params}->{owner}) { return 1; } # bot owner ALWAYS has bot admin privs
		
	my $min_access = $self->{params}->{access} || 'op';
	my $users = $self->get_users();
	my $user = $users->{$username};
	
	if (!$user) { return 0; }
	if ($user->{$min_access}) { return 1; } # exact match on min req.
	if ($user->{founder}) { return 1; } # nothing higher than founder
	
	if ($min_access eq 'op') {
		if ($user->{admin}) { return 1; } # admin is higher than op.
	}
	elsif ($min_access eq 'half') {
		if ($user->{op}) { return 1; } # op is higher than half
		if ($user->{admin}) { return 1; } # admin is higher than op.
	}
	elsif ($min_access eq 'voice') {
		if ($user->{half}) { return 1; } # half is higher than voice
		if ($user->{op}) { return 1; } # op is higher than half
		if ($user->{admin}) { return 1; } # admin is higher than op.
	}
	
	return 0;
}

sub irc_cmd {
	# execute raw irc command (e.g. /nick)
	my $self = shift;
	my $cmd = shift;
	$self->log_debug("Executing IRC command: $cmd (" . join(', ', @_) . ")");
	
	$poe_kernel->post(
        $self->{IRCNAME},
        $cmd,
        $self->charset_encode(@_),
    );
}

sub bot_cmd {
	# execute bot command from text entered
	my ($self, $text, $args) = @_;
	
	# verify user's bot access
	if (!$self->check_admin(lc($args->{who}))) { return undef; } # not enough privs to command ze bot
	
	# some commands may only be requested by the bot owner
	my $is_owner = (lc($args->{who}) eq lc($self->{params}->{owner}));
	
	if (($text =~ /^identify$/i) && $is_owner) {
		# try to identify ourself (should happen automatically on connect)
		$self->log_debug( "Attempting to identify ourselves with NickServ" );
		$self->say(
			who => 'NickServ',
			channel => 'msg',
			body => 'IDENTIFY ' . $self->{params}->{password}
		);
	}
	elsif ($text =~ m@^/?msg\s+(\S+)\s+(.+)$@i) {
		# direct message to someone
		my $who = $1;
		my $body = $2;
		$self->log_debug( "Sending private message to $who: $body");
		# $response = { who => $who, channel => 'msg', body => $body };
		$self->say(
			who => $who,
			channel => 'msg',
			body => $body
		);
	}
	elsif ($text =~ /^say\s+(.+)$/i) {
		# say something
		my $msg = $1;
		$self->log_debug( "Puppet mode: Saying: $msg" );
		$self->say(
			channel => nch( $self->{params}->{channel} ),
			body => $msg
		);
	}
	elsif ($text =~ /^(quit|exit|shutdown|die)$/) {
		# tell bot to go away
		$self->log_debug( "Caught exit command" );
		$self->mirror_exit();
	}
	elsif ($text =~ /^(reload|restart|cycle)/) {
		# shutdown and startup again
		$self->log_debug( "Caught reload command" );
		$self->{request_reload} = 1;
		$self->mirror_exit();
	}
	elsif ($text =~ /^kick\s+(\S+)$/) {
		# kick user
		my $who = $1;
		$self->log_debug( "Kicking user: $who" );
		$self->irc_cmd( 'kick', nch($self->{params}->{channel}), $who );
	}
	elsif ($text =~ /^timeout\s+(\S+)$/) {
		# timeout user (JTV only)
		my $who = $1;
		$self->log_debug( "Performing JTV / Twitch timeout on user: $who" );
		if ($self->{params}->{jtv}) {
			# justin.tv timeout
			$self->say(
				channel => nch( $self->{params}->{channel} ),
				body => '.timeout ' . trim($who)
			);
			#$self->{mirror}->say(
			#	channel => nch( $self->{mirror}->{params}->{channel} ),
			#	body => "Timed out JTV / Twitch user: $who"
			#);
		}
	}
	elsif ($text =~ /^ban\s+(\S+)$/) {
		# ban user (JTV only)
		my $who = $1;
		$self->log_debug( "Performing JTV / Twitch ban on user: $who" );
		if ($self->{params}->{jtv}) {
			# justin.tv ban
			$self->say(
				channel => nch( $self->{params}->{channel} ),
				body => '.ban ' . trim($who)
			);
			#$self->{mirror}->say(
			#	channel => nch( $self->{mirror}->{params}->{channel} ),
			#	body => "Banned JTV / Twitch user: $who"
			#);
		}
	}
	elsif ($text =~ /^unban\s+(\S+)$/) {
		# unban user (JTV only)
		my $who = $1;
		$self->log_debug( "Performing JTV / Twitch unban on user: $who" );
		if ($self->{params}->{jtv}) {
			# justin.tv ban
			$self->say(
				channel => nch( $self->{params}->{channel} ),
				body => '.unban ' . trim($who)
			);
			#$self->{mirror}->say(
			#	channel => nch( $self->{mirror}->{params}->{channel} ),
			#	body => "Unbanned JTV / Twitch user: $who"
			#);
		}
	}
	elsif ($text =~ /^\/(\w+)(.*)$/) {
		# raw irc command
		my $cmd = $1;
		my $cmd_args_raw = trim($2 || '');
		my $cmd_args = [];
		if ($cmd_args_raw =~ /\S/) { $cmd_args = [ split(/\s+/, $cmd_args_raw) ]; }
		$self->log_debug( "Sending raw IRC command: $cmd: $cmd_args_raw" );
		$self->irc_cmd( $cmd, @$cmd_args );
	}
	elsif (($text =~ /^eval\s+(.+)$/i) && $is_owner) {
		# owner command only: raw perl eval (VERY DANGEROUS, FOR DEBUGGING ONLY)
		my $cmd = $1;
		$self->log_debug( "Perl Eval: $cmd" );
		my $result = '';
		eval {
			$result = eval($cmd);
			die $@ if $@;
		};
		if ($@) { $result = "Error: $@"; }
		$result =~ s/\n/ /g; $result =~ s/\s+/ /g;
		$result = trim($result);
		if (length($result)) { $self->say( who => $args->{who}, channel => nch($args->{channel}), body => $result ); }
	}	
}

##
# Bot::BasicBot Hooks:
##

sub init {
	# called when the bot is created, as part of new(). Return a true value for a successful init, or undef if you failed, in which case new() will die.
	my $self = shift;
	
	my $version = $self->{version} = get_version();
	$self->log_debug( 'MirrorBot v' . $version->{Major} . '-' . $version->{Minor} . ' (' . $version->{Branch} . ') starting up');
	$self->log_debug( "Initializing mirror: " . $self->{params}->{mirror_name} );
	$self->log_debug( "Connecting to server: " . $self->{params}->{server} );
	return 1;
}

sub connected {
	# An optional method to override, gets called after we have connected to the server
	my $self = shift;
	
	eval {
		$self->log_debug( "in connected()\n" );
		
		if ($self->{params}->{password}) {
			$self->log_debug( "Trying to idenify ourselves with NickServ (".$self->{params}->{nick}.")\n" );
			$self->say(
				who => 'NickServ',
				channel => 'msg',
				body => 'IDENTIFY ' . $self->{params}->{password}
			);
		}
	};
	if ($@) { $self->crash($@); }
	
	return undef;
}

sub said {
	# called by default whenever someone says anything that we can hear, either in a public channel or to us in private that we shouldn't ignore.
	my $self = shift;
	my $args = shift;
	my $response = undef;
	
	eval {
		$args->{who_disp} = $args->{who}; # save original nick for display purposes
		if ($self->{ignore}->{lc($args->{who})}) { return undef; } # ignore this user
		
		$self->log_debug( "in said(): " . Dumper($args) );
		$self->{last_said} = $args;
		
		my $text = trim($args->{raw_body});
		my $activator = $self->{params}->{activator};
		
		if (substr($text, 0, 1) eq $activator) {
			# first character is activator, so exec bot command
			$text = substr($text, 1);
			
			if (($text =~ s/^(mirror|jtv|twitch)\s+//) || ($text =~ /^(msg|say|kick|timeout|ban|unban)/)) {
				# send cmd thru mirror to bot on other side
				if ($self->{mirror}) {
					$self->{mirror}->bot_cmd( $text, $args );
				}
			}
			else {
				# cmd is for this side of the mirror
				$self->bot_cmd( $text, $args );
			}
		} # command entered
		else {
			# echo jtv private messages (which are really just notices)
			if (($args->{who} eq 'jtv') && ($args->{channel} eq 'msg')) {
				#$self->say(
				#	channel => nch( $self->{params}->{channel} ),
				#	body => 'JTV/Twitch Notice: ' . $args->{raw_body}
				#);
				$self->log_debug( "Received JTV/Twitch Notice: " . $args->{raw_body} );
				
				if ($self->{mirror}) {
					# manually echo notice to mirror, as bot is ignored by mirror (by design)
					$self->{mirror}->say(
						channel => nch( $self->{mirror}->{params}->{channel} ),
						body => 'JTV/Twitch Notice: ' . $args->{raw_body}
					);
				}
				
				return undef;
			} # jtv notice
			
			if ($self->{mirror}) {
				# if private message, do not pass to mirror
				if ($args->{channel} eq 'msg') { return undef; } # ignore
				
				$self->{mirror}->mirror_say( $args );
			} # mirror
		}
	};
	if ($@) { $self->crash($@); }
	
	return $response;
}

sub mirror_say {
	# say passed to us from mirror
	my $self = shift;
	my $args = shift;
	my $who = $args->{who};
	my $chan = nch( $self->{params}->{channel} );
	my $text = trim($args->{raw_body});
	
	if ($self->{ignore}->{lc($who)}) { return undef; } # ignore 
	
	$self->log_debug( "in mirror_said(): " . Dumper($args) );
	
	my $body = '';
	if ($args->{is_emote}) { $body = '*' . $who . ' ' . $text; }
	else { 
		$body = substr($self->{params}->{nick_decoration}, 0, 1) . $who . substr($self->{params}->{nick_decoration}, 1, 1) . ' ' . $text; 
	}
	
	if ($self->{params}->{prevent_dupes}) {
		my $dupe_key = "$chan $body";
		if ($self->{last_say_str} && ($self->{last_say_str} eq $dupe_key)) {
			$self->log_debug( "Dupe protection, skipping: $dupe_key" );
			return;
		}
		$self->{last_say_str} = $dupe_key;
	}
	
	if ($self->{params}->{throttle}) {
		my $queue_len = scalar @{$self->{say_queue}};
		my $min_interval = 1 / $self->{params}->{throttle};
		my $now = time();
		
		if ((!$self->{last_say_time} || ($now - $self->{last_say_time} > $min_interval)) && !$queue_len) {
			$self->{last_say_time} = $now;
		}
		else {
			# too fast, add to queue, will be flushed in tick()
			if (!$self->{params}->{queue_length} || ($queue_len < $self->{params}->{queue_length})) {
				$self->log_debug( "Flood throttle, queuing for next tick: $chan $body" );
				push @{$self->{say_queue}}, {
					channel => $chan,
					body => $body
				};
			}
			else {
				$self->log_debug( "Throttle queue is too long, dropping on floor: $chan $body" );
			}
			return;
		}
	}
	
	$self->say(
		channel => $chan,
		body => $body
	);	
}

sub emoted {
	# someone emoted
	my $self = shift;
	my $args = shift;
	
	$args->{is_emote} = 1;
    return $self->said($args);
}

sub noticed {
	# received notice
    my $self = shift;
	my $args = shift;
	
	$args->{is_notice} = 1;
    return $self->said($args);
}

sub chanjoin {
	# Called when someone joins a channel. It receives a hashref argument similar to the one received by said(). 
	# The key 'who' is the nick of the user who joined, while 'channel' is the channel they joined.
	my $self = shift;
	my $args = shift;
	if ($self->{ignore}->{lc($args->{who})}) { return; } # ignore
	
	eval {
		$self->log_debug( "in chanjoin(): " . Dumper($args) );
		
		$args->{who_disp} = $args->{who}; # save original nick for display purposes
		$args->{who} = lc($args->{who});
		if ($self->{ignore}->{$args->{who}}) { return undef; } # ignore this user
		
		if ($self->{mirror}) {
			$self->{mirror}->mirror_chanjoin($args);
		}
	};
	if ($@) { $self->crash($@); }
	
	return undef;
}

sub mirror_chanjoin {
	# pass chanjoin along to mirror
	my $self = shift;
	my $args = shift;	
	my $who = lc($args->{who});
	if ($self->{ignore}->{$who}) { return; } # ignore
	
	$self->log_debug( "in mirror_chanjoin(): " . Dumper($args) );
	$self->log_debug( $self->{mirror}->{params}->{mirror_name} . ' user "' . $args->{who_disp} . '" has joined.' );
}

sub chanpart {
	# Called when someone parts a channel. It receives a hashref argument similar to the one received by said(). 
	# The key 'who' is the nick of the user who parted, while 'channel' is the channel they parted.
	my $self = shift;
	my $args = shift;
	# if ($self->{ignore}->{lc($args->{who})}) { return; } # ignore
	
	eval {
		$self->log_debug( "in chanpart(): " . Dumper($args) );
		
		$args->{who_disp} = $args->{who}; # save original nick for display purposes
		$args->{who} = lc($args->{who});
		if ($self->{ignore}->{$args->{who}}) { return undef; } # ignore this user
		
		if ($self->{mirror}) {
			$self->{mirror}->mirror_chanpart($args);
		}
	};
	if ($@) { $self->crash($@); }
	
	return undef;
}

sub mirror_chanpart {
	# pass chanpart along to mirror
	my $self = shift;
	my $args = shift;
	my $who = lc($args->{who});
	# if ($self->{ignore}->{$who}) { return; } # ignore
	
	$self->log_debug( "in mirror_chanpart(): " . Dumper($args) );
	$self->log_debug( $self->{mirror}->{params}->{mirror_name} . ' user "' . $args->{who_disp} . '" has left.' );
}

sub got_names {
	# Whenever we have been given a definitive list of 'who is in the channel', this function will be called. It receives a hash reference as an argument. The key 'channel' will be the channel we have information for, 'names' is a hashref where the keys are the nicks of the users, and the values are more hashes, containing the two keys 'op' and 'voice', indicating if the user is a chanop or voiced respectively.
	my $self = shift;
	my $args = shift;
	
	eval {
		$self->log_debug( "in got_names(): " . Dumper($args) );
		
		if ($self->{mirror}) {
			$self->{mirror}->mirror_got_names($args);
		}
	};
	if ($@) { $self->crash($@); }
	
	return undef;
}

sub mirror_got_names {
	# receive list of users from mirror
	my $self = shift;
	my $args = shift;
	my $names = $args->{names} || {};
	
	$self->log_debug( "in mirror_got_names(): " . Dumper($args) );
}

sub topic {
	# Called when the topic of the channel changes. It receives a hashref argument. The key 'channel' is the channel the topic was set in, and 'who' is the nick of the user who changed the channel, 'topic' will be the new topic of the channel.
	my $self = shift;
	my $args = shift;
	
	eval {
		$self->log_debug( "in topic(): " . Dumper($args) );
		
		if ($self->{mirror} && $self->{params}->{sync_topic}) {
			# send topic to mirror
			$self->{mirror}->mirror_topic( $args );
		}
	};
	if ($@) { $self->crash($@); }
	
	return undef;
}

sub mirror_topic {
	# set topic in mirror
	my $self = shift;
	my $args = shift;
	
	if ($self->{params}->{jtv}) {
		# jtv topic
		$self->say(
			channel => nch( $self->{params}->{channel} ),
			body => '.topic ' . $args->{topic}
		);
	}
	else {
		# standard topic
		$self->irc_cmd( 'topic', nch($self->{params}->{channel}), $args->{topic} );
		# $self->say(
		# 	who => 'ChanServ',
		# 	channel => 'msg',
		# 	body => 'TOPIC ' . nch($self->{params}->{channel}) . ' ' . $args->{topic}
		# );
	}
}

sub nick_change {
	# When a user changes nicks, this will be called. It receives a hashref which will look like this:
	# { from => "old_nick", to => "new_nick", }
	my $self = shift;
	my $args = { old_nick => shift @_, new_nick => shift @_ };
	# if ($self->{ignore}->{lc($args->{old_nick})}) { return; } # ignore
	
	eval {
		$self->log_debug( "in nick_change(): " . Dumper($args) );
		
		if ($self->{mirror}) {
			$self->{mirror}->mirror_nick_change($args);
		}
	};
	if ($@) { $self->crash($@); }
	
	return undef;
}

sub mirror_nick_change {
	# someone changed their nick in mirror
	my $self = shift;
	my $args = shift;
	# if ($self->{ignore}->{lc($args->{old_nick})}) { return; } # ignore
	
	$self->log_debug( "in mirror_nick_change(): " . Dumper($args) );
	
	$self->notice(
		channel => nch( $self->{params}->{channel} ),
		body => $self->{mirror}->{params}->{mirror_name} . ' user "' . $args->{old_nick} . '" is now known as "' . $args->{new_nick} . '".'
	);
}

sub kicked {
	# Called when a user is kicked from the channel. It receives a hashref which will look like this:
	# { channel => "#channel", who => "nick", kicked => "kicked", reason => "reason", }
	my $self = shift;
	my $args = shift;
	# if ($self->{ignore}->{lc($args->{kicked})}) { return; } # ignore
	
	eval {
		$self->log_debug( "in kicked(): " . Dumper($args) );
		
		if ($self->{mirror}) {
			$self->{mirror}->mirror_kicked($args);
		}
	};
	if ($@) { $self->crash($@); }
	
	return undef;
}

sub mirror_kicked {
	# pass kick event along to mirror
	my $self = shift;
	my $args = shift;
	# if ($self->{ignore}->{lc($args->{kicked})}) { return; } # ignore
	
	$self->log_debug( "in mirror_kicked(): " . Dumper($args) );
	
	$self->notice(
		channel => nch( $self->{params}->{channel} ),
		body => $self->{mirror}->{params}->{mirror_name} . ' user "' . $args->{kicked} . '" was kicked by ' . $args->{who} . '.'
	);
}

sub tick {
	# This is an event called every regularly. The function should return the amount of time until the tick event should next be called.
	my $self = shift;
	
	eval {
		# $self->log_debug( "in tick()\n" );
		
		if (scalar @{$self->{say_queue}}) {
			my $min_interval = 1 / $self->{params}->{throttle};
			my $now = time();
			if (!$self->{last_say_time} || ($now - $self->{last_say_time} > $min_interval)) {
				$self->{last_say_time} = $now;
				my $say_args = shift @{$self->{say_queue}};
				$self->say( %$say_args );
			}
		} # say queue
		
		# also check for daily maint here
		if ($self->{maint_enabled}) {
			my $day_code = yyyy_mm_dd( time() );
			$self->{last_maint} ||= $day_code;
			if ($day_code ne $self->{last_maint}) {
				$self->run_daily_maintenance();
				$self->{last_maint} = $day_code;
			}
		}
	};
	if ($@) { $self->crash($@); }
	
	return 0.1;
}

sub run_daily_maintenance {
	# rotate logs, etc.
	# runs once a day at midnight
	my $self = shift;
	my $now = time();
	
	$self->log_debug("Starting daily maintenance run");
	
	# rotate logs into daily gzip archives
	$self->log_debug("Rotating logs");
	$self->rotate_logs();
	
	$self->log_debug("Daily maintenance complete");
}

sub rotate_logs {
	# rotate and archive daily logs
	my $self = shift;
	my $yyyy_mm_dd = yyyy_mm_dd( normalize_midnight( normalize_midnight(time()) - 43200 ), '/' );
	my $archive_dir = $self->{params}->{log_archive_dir} || 'logs/archive';
	my $logs = [ glob('logs/*.log') ];
	my $gzip_bin = find_bin('gzip');
	
	foreach my $log_file (@$logs) {
		my $log_category = basename($log_file); $log_category =~ s/\.\w+$//;
		my $log_archive = $archive_dir . '/' . $log_category . '/' . $yyyy_mm_dd . '.log';
		
		$self->log_debug("Maint: Archiving log: $log_file to $log_archive.gz");
		
		# add a message at the bottom of the log, in case someone is live tailing it.
		my $fh = FileHandle->new( ">>$log_file" );
		if ($fh) {
			my $nice_time = scalar localtime;
			$fh->print("\n# Rotating log to $log_archive.gz at $nice_time\n");
		}
		$fh->close();
		
		if (make_dirs_for( $log_archive )) {
			if (rename($log_file, $log_archive)) {
				my $output = `$gzip_bin $log_archive 2>&1`;
				if ($output =~ /\S/) {
					$self->log_debug("Maint Error: Failed to gzip file: $log_archive: $output");
				}
			}
			else {
				$self->log_debug("Maint Error: Failed to move file: $log_file --> $log_archive: $!");
			}
		}
		else {
			$self->log_debug("Maint Error: Failed to create directories for: $log_archive: $!");
		}
	} # foreach log
}

sub help {
	# This is the text that the bot will respond to if someone simply says help to it.
	my $self = shift;
	
	eval {
		$self->log_debug( "in help()\n" );
	};
	if ($@) { $self->crash($@); }
	
	return "This bot mirrors all chat activity to/from another IRC server.  That's it!\n";
}

sub userquit {
	# Receives a hashref which will look like:
	# { who => "nick that quit", body => "quit message", }
	my $self = shift;
	my $args = shift;
	# if ($self->{ignore}->{lc($args->{who})}) { return; } # ignore
	
	eval {
		$self->log_debug( "in userquit(): " . Dumper($args) );
		
		if ($self->{mirror}) {
			$self->{mirror}->mirror_userquit($args);
		}
	};
	if ($@) { $self->crash($@); }
	
	return undef;
}

sub mirror_userquit {
	# pass quit event along to mirror
	my $self = shift;
	my $args = shift;
	if ($self->{ignore}->{lc($args->{who})}) { return; } # ignore
	
	$self->log_debug( "in mirror_userquit(): " . Dumper($args) );
	$self->log_debug( $self->{mirror}->{params}->{mirror_name} . ' user "' . $args->{who} . '" has left (' . $args->{body} . ').' );
}

1;
