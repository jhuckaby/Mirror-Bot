#!/usr/bin/perl

# MirrorBot Installer Phase 2
# Invoked by install-latest-BRANCH.txt (remote-install.sh)
# by Joseph Huckaby
# Copyright (c) 2011-2014 PixlCore.com

use strict;
use FileHandle;
use File::Basename;
use DirHandle;
use Cwd 'abs_path';
use English qw( -no_match_vars ) ;
use Digest::MD5 qw/md5_hex/;
use Time::HiRes qw/time/;
use IO::Socket::INET;

BEGIN {
	push @INC, dirname(dirname(abs_path($0))) . "/lib";
}
use VersionInfo;

if ($UID != 0) { die "Error: Must be root to install MirrorBot.  Exiting.\n"; }

my $base_dir = abs_path( dirname( dirname($0) ) );
chdir( $base_dir );

my $version = get_version();

my $standard_binary_paths = {
	'/bin' => 1,
	'/usr/bin' => 1,
	'/usr/local/bin' => 1,
	'/sbin' => 1,
	'/usr/sbin' => 1,
	'/usr/local/sbin' => 1,
	'/opt/bin' => 1,
	'/opt/local/bin' => 1
};
foreach my $temp_bin_path (split(/\:/, $ENV{'PATH'} || '')) {
	if ($temp_bin_path) { $standard_binary_paths->{$temp_bin_path} = 1; }
}

print "\nInstalling MirrorBot " . $version->{Major} . '-' . $version->{Minor} . " (" . $version->{Branch} . ")...\n\n";

# Have cpanm install all our required modules, if we need them
foreach my $module (split(/\n/, load_file("$base_dir/install/perl-modules.txt"))) {
	if ($module =~ /\S/) {
		my $cmd = "/usr/bin/perl -M$module -e ';' >/dev/null 2>\&1";
		my $result = system($cmd);
		if ($result == 0) {
			print "Perl module $module is installed.\n";
		}
		else {
			my $cpanm_bin = find_bin("cpanm");
			if (!$cpanm_bin) {
				die "\nERROR: Could not locate 'cpanm' binary in the usual places.  Installer cannot continue.\n\n";
			}
			system("$cpanm_bin -n --configure-timeout=3600 $module");
			my $result = system($cmd);
			if ($result != 0) {
				die "\nERROR: Failed to install Perl module: $module.  Please try to install it manually, then run this installer again.\n\n";
			}
		}
	}
}

exec_shell( "chmod 775 $base_dir/bin/*" );

# init.d script (+perms)
exec_shell( "cp $base_dir/install/mirrorbotd.init /etc/init.d/mirrorbotd" );
exec_shell( "chmod 775 /etc/init.d/mirrorbotd" );

# activate service for startup
if (system("which chkconfig >/dev/null 2>\&1") == 0) {
	# redhat
	exec_shell( "chkconfig mirrorbotd on" );
}
elsif (system("which update-rc.d >/dev/null 2>\&1") == 0) {
	# ubuntu
	exec_shell( "update-rc.d mirrorbotd defaults" );
}

print "\nCONFIGURATION INSTRUCTIONS:\n";
print "Edit the '/opt/mirrorbot/conf/mirror-config.xml' file to set params such as the\n";
print "servers and ports to connect to, as well as the bot's identities.  Then start\n";
print "the bot with this command: /etc/init.d/mirrorbotd start\n";

print "\nMirrorBot Installation complete.\n\n";

exit();

sub get_xml_element {
	# extract simple xml element given raw XML and element name
	my ($xml_raw, $elem_name) = @_;
	if ($xml_raw =~ m@<$elem_name>(.*?)</$elem_name>@s) { return $1; }
	return undef;
}

sub generate_unique_id {
	##
	# Generate MD5 hash using HiRes time, PID and random number
	##
	my $len = shift || 32;
	
	return substr(md5_hex(time() . $$ . rand(1)), 0, $len);
}

sub trim {
	##
	# Trim whitespace from beginning and end of string
	##
	my $text = shift;
	
	$text =~ s@^\s+@@; # beginning of string
	$text =~ s@\s+$@@; # end of string
	
	return $text;
}

sub ascii_box {
	# simple ascii box
	my $text = shift;
	my $border = shift || '*';
	my $indent = shift || '';
	my $horiz_space = shift || '';
	
	my $output = '';
	my $lines = [];
	my $longest_line = 0;
	
	foreach my $line (split("\n", $text)) {
		$line = $horiz_space . $line . $horiz_space;
		if (length($line) > $longest_line) { $longest_line = length($line); }
		push @$lines, $line;
	}
	
	$output .= $indent . ($border x ($longest_line + 4)) . "\n";
	$output .= $indent . $border . (' ' x ($longest_line + 2)) . $border . "\n";
	
	foreach my $line (@$lines) {
		$output .= $indent . $border . ' ' . $line . (' ' x ($longest_line - length($line))) . ' ' . $border . "\n";
	}
	
	$output .= $indent . $border . (' ' x ($longest_line + 2)) . $border . "\n";
	$output .= $indent . ($border x ($longest_line + 4)) . "\n";
	
	return $output;
}

sub safe_copy_dir {
	# recursively copy dir and files, but only if they don't already exist in the destination
	my ($source_dir, $dest_dir) = @_;
	
	my $dirh = new DirHandle $source_dir;
	unless (defined($dirh)) { return; }
	
	my $filename;
	while (defined($filename = $dirh->read())) {
		if (($filename ne '.') && ($filename ne '..')) {
			if (-d "$source_dir/$filename") {
				if (!(-d "$dest_dir/$filename")) { mkdir "$dest_dir/$filename", 0775; }
				safe_copy_dir( "$source_dir/$filename", "$dest_dir/$filename" );
			}
			elsif (!(-e "$dest_dir/$filename")) {
				exec_shell( "cp $source_dir/$filename $dest_dir/$filename", 'quiet' );
			}
		} # don't process . and ..
	}
	undef $dirh;
}

sub exec_shell {
	my $cmd = shift;
	my $quiet = shift || 0;
	if (!$quiet) { print "Executing command: $cmd\n"; }
	print `$cmd 2>&1`;
}

sub find_bin {
	# locate binary executable on filesystem
	# look in the usual places, also PATH
	my $bin_name = shift;
	
	foreach my $parent_path (keys %$standard_binary_paths) {
		my $bin_path = $parent_path . '/' . $bin_name;
		if ((-e $bin_path) && (-x $bin_path)) {
			return $bin_path;
		}
	}
	
	return '';
}

sub load_file {
	##
	# Loads file into memory and returns contents as scalar.
	##
	my $file = shift;
	my $contents = undef;
	
	my $fh = new FileHandle "<$file";
	if (defined($fh)) {
		$fh->read( $contents, (stat($fh))[7] );
		$fh->close();
	}
	
	##
	# Return contents of file as scalar.
	##
	return $contents;
}

sub save_file {
	my $file = shift;
	my $contents = shift;

	my $fh = new FileHandle ">$file";
	if (defined($fh)) {
		$fh->print( $contents );
		$fh->close();
		return 1;
	}
	
	return 0;
}

1;
