#!/usr/bin/perl

# MirrorBot Uninstaller
# by Joseph Huckaby
# Copyright (c) 2011 - 2014 PixlCore.com

use strict;
use FileHandle;
use File::Basename;
use English qw( -no_match_vars ) ;

if ($UID != 0) { die "Error: Must be root to uninstall MirrorBot.  Exiting.\n"; }

if (yesno("\nAre you sure you want to COMPLETELY DELETE MirrorBot,\nincluding all configuration, data and logs?", "n")) {
	print "Uninstalling MirrorBot...\n";
	
	exec_shell("/etc/init.d/mirrorbotd stop");
	
	exec_shell("rm -f /etc/rc*.d/*mirrorbotd");
	exec_shell("rm -f /etc/init.d/mirrorbotd");
	exec_shell("rm -rf /opt/mirrorbot");
	print "\nUninstall complete.\n\n";
}
else {
	print "Aborted.  Will not uninstall.\n\n";
}

exit(0);

sub exec_shell {
	my $cmd = shift;
	print "Executing command: $cmd\n";
	print `$cmd 2>&1`;
}

sub yesno {
	my $text = shift;
	my $default = shift || '';

	if (prompt("$text (y/n) ", $default) =~ /y/i) { return 1; }
	return 0;
}

sub prompt {
	my $text = shift;
	my $default = shift || '';
		
	print "$text";
	if ($text !~ /(\s|\/)$/) { print ": "; }
	if ($default) { print "[$default] "; }
	my $input = <STDIN>;
	chomp $input;
	return $input || $default;
}

1;
