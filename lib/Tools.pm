package Tools;

##
# Tools.pm
# Generic standalone tools library
# Author: Joseph Huckaby <jhuckaby@effectgames.com>
##

use vars qw/$VERSION/;
$VERSION = sprintf("%s", q$Revision: 1.4 $ =~ /([\d\.]+)/);

use strict;
use Config;
use Digest::MD5 qw(md5_hex);
use FileHandle;
use File::Basename;
use Cwd qw/cwd abs_path/;
use DirHandle;
use Time::HiRes qw/time/;
use Time::Local;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common qw/POST PUT/;
use HTTP::Response;
use Date::Parse;
use URI::Escape;
use Socket;
use DBI;
use MIME::Lite;
use Data::Dumper;
use UNIVERSAL qw(isa);

BEGIN
{
    use Exporter   ();
    use vars qw(@ISA @EXPORT @EXPORT_OK);

    @ISA		= qw(Exporter);
    @EXPORT		= qw(XMLalwaysarray load_file save_file get_hostname get_bytes_from_text get_text_from_bytes short_float commify pct pluralize alphanum ascii_table file_copy file_move generate_unique_id memory_substitute memory_lookup find_files ipv4_to_hostname hostname_to_ipv4 wget xml_to_javascript escape_js normalize_midnight yyyy_mm_dd mm_dd_yyyy yyyy get_nice_date follow_symlinks get_remote_ip get_user_agent strip_high merge_hashes xml_post parse_query compose_query parse_xml compose_xml decode_entities encode_entities encode_attrib_entities xpath_lookup db_query parse_cookies touch probably rand_array find_elem_idx dumper serialize_object deep_copy trim file_get_contents file_put_contents preg_match preg_replace make_dirs_for find_bin);
	@EXPORT_OK	= qw();
}

my $months = [
	'January', 'February', 'March', 'April', 'May', 'June', 
	'July', 'August', 'September', 'October', 'November', 'December'
];

my $entities = {
	'amp' => '&',
	'lt' => '<',
	'gt' => '>',
	'apos' => "'",
	'quot' => '"'
};

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

sub XMLalwaysarray {
	my $args={@_};

	if (!defined($args->{xml}) || !defined($args->{element})) {return 0;}

	if (defined($args->{xml}->{$args->{element}}) && ref($args->{xml}->{$args->{element}}) !~ /ARRAY/) {
		my $temp=$args->{xml}->{$args->{element}};
		undef $args->{xml}->{$args->{element}};
		(@{$args->{xml}->{$args->{element}}})=($temp);
		return 1;
	}
	return 0;
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
	
	return $contents;
}

sub save_file {
	##
	# Save file contents, create if necessary
	##
	my $file = shift;
	my $contents = shift;

	my $fh = new FileHandle ">$file";
	if (defined($fh)) {
		$fh->print( $contents );
		$fh->close();
	}
}

sub get_hostname {
	##
	# Get machine's hostname in any way possible
	# This may shell out to /bin/hostname ! ! !
	##
	my $hostname;
	
	if ($ENV{'HOST'} || $ENV{'HOSTNAME'}) {
		$hostname = $ENV{'HOST'} || $ENV{'HOSTNAME'};
	} elsif (defined($ENV{'SERVER_ADDR'})) {
		($hostname, undef, undef, undef, undef) = (gethostbyaddr(pack("C4", split(/\./, $ENV{'SERVER_ADDR'} || '127.0.0.1')), 2));
	} else {
		$hostname = `/bin/hostname`;
		chomp $hostname;
	}
	
	return $hostname || 'localhost';
}

sub get_bytes_from_text {
	##
	# Given text string such as '5.6 MB' or '79K', return actual byte value.
	##
	my $text = shift;
	my $bytes = $text;
	
	if ($text =~ /(\d+(\.\d+)?)\s*([A-Za-z]+)/) {
		$bytes = $1;
		my $code = $3;
		if ($code =~ /^b/i) { $bytes *= 1; }
		elsif ($code =~ /^k/i) { $bytes *= 1024; }
		elsif ($code =~ /^m/i) { $bytes *= 1024 * 1024; }
		elsif ($code =~ /^g/i) { $bytes *= 1024 * 1024 * 1024; }
		elsif ($code =~ /^t/i) { $bytes *= 1024 * 1024 * 1024 * 1024; }
	}
	
	return $bytes;
}

sub get_text_from_bytes {
	##
	# Given raw byte value, return text string such as '5.6 MB' or '79 K'
	##
	my $bytes = shift;
	
	if ($bytes < 1024) { return $bytes . ' bytes'; }
	else {
		$bytes /= 1024;
		if ($bytes < 1024) { return short_float($bytes) . ' K'; }
		else {
			$bytes /= 1024;
			if ($bytes < 1024) { return short_float($bytes) . ' MB'; }
			else {
				$bytes /= 1024;
				if ($bytes < 1024) { return short_float($bytes) . ' GB'; }
				else {
					$bytes /= 1024;
					return short_float($bytes) . ' TB';
				}
			}
		}
	}
}

sub short_float {
	##
	# Shorten floating-point decimal to 2 places, unless they are zeros.
	##
	my $f = shift;
	
	$f =~ s/^(\-?\d+\.[0]*\d{2}).*$/$1/;
	return $f;
}

sub commify {
	##
	# Add commas to numbers over 999 (US Number Format only)
	##
	my $num = short_float(shift || 0); 
	while ($num =~ s/^(-?\d+)(\d{3})/$1,$2/) {} 
	return $num; 
}

sub pct {
	##
	# Calculate percent from two values, return display version
	# pct(1, 4) == '25%'
	##
	my ($count, $max) = @_; 
	my $pct = ($count * 100) / ($max || 1);
	if ($pct !~ /^\d+(\.\d+)?$/) { $pct = 0; }
	return short_float( $pct ) . '%';
}

sub pluralize {
	##
	# Add 's' after word if number is not 1
	##
	my ($word, $num) = @_;
	return ($num == 1) ? $word : ($word.'s');
}

sub alphanum {
	##
	# strip non-alphanumerics and return
	##
	my $str = shift;
	$str =~ s/\W+//g;
	return $str;
}

sub ascii_table {
	##
	# Render pretty ASCII table
	##
	my $args = (scalar @_ == 1) ? { rows => $_[0] } : {@_};
	my $table = '';

	$args->{indent} ||= '';
	if (!defined($args->{hspace})) { $args->{hspace} ||= ' | '; }
	if (!defined($args->{header_divider})) { $args->{header_divider} = '-'; }

	my $max_col_widths = [];
	foreach my $row (@{$args->{rows}}) {
		my $idx = 0;
		foreach my $col (@$row) {
			if (!$max_col_widths->[$idx] || (length($col) > $max_col_widths->[$idx])) {
				$max_col_widths->[$idx] = length($col);
			}
			$idx++;
		}
	}
	my $num_cols = scalar @$max_col_widths;
	my $num_rows = scalar @{$args->{rows}};

	my $fmt_string = $args->{indent} . join( $args->{hspace}, map { '%-'.$_.'s'; } @$max_col_widths );
	$table .= sprintf( "$fmt_string\n", @{$args->{rows}->[0]} );

	if ($args->{header_divider}) {
		my $divider_length = length($args->{hspace}) * ($num_cols - 1);
		map { $divider_length += $_; } @$max_col_widths;
		$table .= $args->{indent} . ($args->{header_divider} x $divider_length) . "\n";
	}

	for (my $idx = 1; $idx < $num_rows; $idx++) {
		$table .= sprintf( "$fmt_string\n", @{$args->{rows}->[$idx]} );
	}

	return $table;
}

sub file_copy {
	##
	# Simple file copy routine using FileHandles.
	##
	my ($source, $dest) = @_;
	my ($source_fh, $dest_fh);
	
	##
	# Accept open FileHandles or filenames as parameters
	##
	if (ref($source)) { $source_fh = $source; }
	else { $source_fh = new FileHandle "<$source"; }

	if (ref($dest)) { $dest_fh = $dest; }
	else { $dest_fh = new FileHandle ">$dest"; }
	
	if (!defined($source_fh)) { return 0; }
	if (!defined($dest_fh)) { return 0; }
	
	my ($size, $buffer, $total_size) = (0, undef, 0);
	while ($size = read($source_fh, $buffer, 32768)) {
		$dest_fh->print($buffer);
		$total_size += $size;
	}
	
	##
	# Only close FileHandles if we opened them.
	##
	if (!ref($source)) { $source_fh->close(); }
	if (!ref($dest)) { $dest_fh->close(); }
	
	return $total_size;
}

sub file_move {
	##
	# Tries rename() first, then falls back to file_copy()/unlink()
	##
	my ($source_file, $dest_file) = @_;

	if (rename($source_file, $dest_file)) { return 1; }
	else {
		if (file_copy($source_file, $dest_file)) {
			if (unlink($source_file)) { return 1; }
		}
	}
	return 0;
}

sub generate_unique_id {
	##
	# Generate MD5 hash using HiRes time, PID and random number
	##
	my $len = shift || 32;
	
	return substr(md5_hex(time() . $$ . rand(1)), 0, $len);
}

sub memory_substitute {
	##
	# Substitute inline [] tags with values from memory location,
	# looked up with virtual directory syntax
	##
	my ($content, $args) = @_;
	
	while ($content =~ m/\[([\w\/\-\:]+)\s*\]/) {
		my $param_name = $1;
		$content =~ s/\[([\w\/\-\:]+)\s*\]/ memory_lookup($param_name, $args) /e;
	} # foreach simple tag
	
	return $content;
}

sub memory_lookup {
	##
	# Walk memory tree using virtual directory syntax and return value found
	##
	my ($param_name, $param) = @_;
	
	while (($param_name =~ s/^\/([\w\-\:]+)//) && ref($param)) {
		if (isa($param, 'HASH')) { $param = $param->{$1}; }
		elsif (isa($param, 'ARRAY')) { $param = ${$param}[$1]; }
	}
	
	return $param;
}

sub find_files {
	##
	# Recursively scan filesystem for wildcard match
	##
	my $dir = shift;
	my $spec = shift || '*';

	$dir =~ s@/$@@;

	##
	# First, convert filespec into regular expression.
	##
	my $reg_exp = $spec;
	$reg_exp =~ s/\./\\\./g; # escape real dots
	$reg_exp =~ s/\*/\.\+/g; # wildcards into .+
	$reg_exp =~ s/\?/\./g; # ? into .
	$reg_exp = '^'.$reg_exp.'$'; # match entire filename
	
	##
	# Now read through directory, checking files against
	# regular expression.  Push matched files onto array.
	##
	my @files = ();
	my $dirh = new DirHandle $dir;
	unless (defined($dirh)) { return @files; }
	
	my $filename;
	while (defined($filename = $dirh->read())) {
		if (($filename ne '.') && ($filename ne '..')) {
			if (-d $dir.'/'.$filename) { push @files, find_files( $dir.'/'.$filename, $spec ); }
			if ($filename =~ m@$reg_exp@) { push @files, $dir.'/'.$filename; }
		} # don't process . and ..
	}
	undef $dirh;
	
	##
	# Return final array.
	##
	return @files;
}

sub ipv4_to_hostname {
	##
	# Resolve IPs to hostnames (CSV format)
	# Also works for single IP
	##
	my $ips = shift;
	my $result = '';
	
	foreach my $ip (split(/\,\s*/, $ips)) {
		my $hostname;
		($hostname, undef, undef, undef, undef) = (gethostbyaddr(pack("C4", split(/\./, $ip)), 2));
		if ($result) { $result .= ', '; }
		$result .= ($hostname || '(unknown host)');
	}
	
	return $result;
}

sub hostname_to_ipv4 {
	##
	# Lookup ipv4s from hostname
	##
	my $hostname = shift;
	my @addresses = gethostbyname($hostname) or return undef;
	@addresses = map { inet_ntoa($_) } @addresses[4 .. $#addresses];
	
	return wantarray ? @addresses : $addresses[0];
}

sub wget {
	##
	# Fetch URL and return HTTP::Response object
	##
	my $url = shift;
	my $timeout = shift || 10;
	my $useragent = shift || '';

	my $ua = LWP::UserAgent->new();
	$ua->timeout( $timeout );
	$useragent && $ua->agent( $useragent );

	return $ua->request( HTTP::Request->new( 'GET', $url ) );
}

sub xml_to_javascript {
	##
	# Convert XML hash tree to JavaScript objects/arrays
	# Does not include trailing semicolon, as in previous incarnations of this function
	##
	my $xml = shift;
	my $indent = shift || 1;
	my $args = {@_};
	my $tabs = "\t" x $indent;
	my $parent_tabs = '';
	my $js = '';
	my $eol = "\n";
	
	if (!defined($args->{lowercase})) { $args->{lowercase} = 1; }
	if (!defined($args->{collapse_attribs})) { $args->{collapse_attribs} = 1; }
	if (!defined($args->{compress})) { $args->{compress} = 0; }

	if ($indent > 1) { $parent_tabs = "\t" x ($indent-1); }
	if ($args->{compress}) { $parent_tabs = ''; $tabs = ''; $eol = ''; }
	
	if (isa($xml, 'HASH')) {
		$js .= "{$eol";
		my @keys = keys %$xml;
		foreach my $key (@keys) {
			if (ref($xml->{$key})) {
				if (($key eq "_Attribs") && $args->{collapse_attribs}) {
					foreach my $attrib_name (keys %{$xml->{'_Attribs'}}) { $xml->{$attrib_name} = $xml->{'_Attribs'}->{$attrib_name}; }
					push @keys, keys %{$xml->{'_Attribs'}};
					next;
				}
				$js .= $tabs . '"' . ($args->{lowercase} ? lc($key) : $key) . '": ' . xml_to_javascript($xml->{$key}, $indent + 1, %$args);
			}
			else {
				my $value = escape_js($xml->{$key});
				$js .= $tabs . '"' . ($args->{lowercase} ? lc($key) : $key) . '": ' . $value . ",$eol";
			}
		}
		$js =~ s/\,$eol$/$eol/;
		$js .= $parent_tabs . "},$eol";
	}
	elsif (isa($xml, 'ARRAY')) {
		$js .= "[$eol";
		foreach my $elem (@$xml) {
			if (ref($elem)) {
				$js .= $tabs . xml_to_javascript($elem, $indent + 1, %$args);
			}
			else {
				my $value = escape_js($elem);
				$js .= $tabs . $value . ",$eol";
			}
		}
		$js =~ s/\,$eol$/$eol/;
		$js .= $parent_tabs . "],$eol";
	}

	if ($indent == 1) {
		$js =~ s/\,$eol$/$eol/;
	}

	return $js;
}

sub escape_js {
	##
	# Escape value for JavaScript eval
	##
	my $value = shift;
	
	if (($value !~ /^\-?\d{1,15}(\.\d{1,15})?$/) || ($value =~ /^0[^\.]/)) {
		$value =~ s/\r\n/\n/sg; # dos2unix
		$value =~ s/\r/\n/sg; # mac2unix
		$value =~ s/\\/\\\\/g; # escape backslashes
		$value =~ s/\"/\\\"/g; # escape quotes
		$value =~ s/\n/\\n/g; # escape EOLs
		$value =~ s/<\/(scr)(ipt)>/<\/$1\" + \"$2>/ig; # escape closing script tags
		$value = '"' . $value . '"';
	}
	
	return $value;
}

sub normalize_midnight {
	##
	# Return epoch of nearest midnight before now
	##
	my $now = shift || time();
	
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime( $now );
	return timelocal( 0, 0, 0, $mday, $mon, $year );
}

sub yyyy_mm_dd {
	##
	# Return date in YYYY-MM-DD format given epoch
	##
	my $epoch = shift || time;
	my $delim = shift || '-';
	
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime( $epoch );
	return sprintf( "%0004d".$delim."%02d".$delim."%02d", $year + 1900, $mon + 1, $mday );
}

sub mm_dd_yyyy {
	##
	# Return date in MM-DD-YYYY format given epoch
	##
	my $epoch = shift || time;
	my $delim = shift || '-';

	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime( $epoch );
	return sprintf( "%02d".$delim."%02d".$delim."%0004d", $mon + 1, $mday, $year + 1900 );	
}

sub yyyy {
	##
	# Return current year as YYYY
	##
	my $epoch = shift || time;
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime( $epoch );
	return sprintf("%0004d", $year + 1900);
}

sub get_nice_date {
	##
	# Given epoch, return pretty-printed date and possibly time too
	##
	my $epoch = shift;
	my $yes_time = shift || 0;
	my $nice = '';

	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime( $epoch );
	my $month_name = $months->[$mon];
	my $yyyy = sprintf( "%0004d", $year + 1900 );
	
	$nice .= "$month_name $mday, $yyyy";

	if ($yes_time) {
		$nice .= ' ';
		my $ampm = 'AM';
		if ($hour >= 12) { $hour -= 12; $ampm = 'PM'; }
		if (!$hour) { $hour += 12; }
		$min = sprintf( "%02d", $min );
		$sec = sprintf( "%02d", $sec );
		$nice .= "$hour:$min:$sec $ampm";
	}

	return $nice;
}

sub follow_symlinks {
	##
	# Recursively resolve all symlinks in file path
	##
	my $file = shift;
	my $old_dir = cwd();

	chdir dirname $file;
	while (my $temp = readlink(basename $file)) {
		$file = $temp; 
		chdir dirname $file;
	}
	chdir $old_dir;

	return abs_path(dirname($file)) . '/' . basename($file);
}

sub get_remote_ip {
	##
	# Return the "true" remote IP address, even if request went through a NetCache
	##
	my $ip = $ENV{'REMOTE_ADDR'};
	
	if ($ENV{'HTTP_X_FORWARDED_FOR'}) {
		$ip .= ', ' . $ENV{'HTTP_X_FORWARDED_FOR'};
	}
	
	return $ip;
}

sub get_user_agent {
	##
	# Get the user agent string, and tack on the NetCache Via header if found.
	# In case NetApp phases out the Via header, also check the X-Flash-Version header
	##
	my $useragent = shift || $ENV{'HTTP_USER_AGENT'} || '';
	
	if ($ENV{'HTTP_VIA'}) { $useragent .= "; " . $ENV{'HTTP_VIA'}; }
	if ($ENV{'HTTP_FORWARDED'}) { $useragent .= "; " . $ENV{'HTTP_FORWARDED'}; }
	if ($ENV{'HTTP_X_FLASH_VERSION'}) { $useragent .= "; Flash Player " . $ENV{'HTTP_X_FLASH_VERSION'}; }
	
	return strip_high($useragent);
}

sub strip_high {
	##
	# Strip all high-ascii, and non-printable low-ascii chars from string
	# Returned stripped string.
	##
	my $text = shift;
	if (!defined($text)) { $text = ""; }
	
	$text =~ s/([\x80-\xFF\x00-\x08\x0B-\x0C\x0E-\x1F])//g;
	return $text;
}

sub merge_hashes {
	##
	# Simple recursive hash merge
	# Arrays are simply copied over
	##
	my ($base_hash, $new_hash, $replace_ok) = @_;
	
	foreach my $key (keys %$new_hash) {
		if (ref($new_hash->{$key})) {
			if (isa($new_hash->{$key}, 'HASH')) {
				if (!defined($base_hash->{$key}) || !isa($base_hash->{$key}, 'HASH')) {
					$base_hash->{$key} = {};
				}
				merge_hashes( $base_hash->{$key}, $new_hash->{$key} );
			}
			elsif ($replace_ok || !defined($base_hash->{$key})) {
				$base_hash->{$key} = $new_hash->{$key};
			}
		}
		elsif ($replace_ok || !defined($base_hash->{$key})) {
			$base_hash->{$key} = $new_hash->{$key};
		}
	}
}

sub xml_post {
	##
	# Send XML request to URL, and parse XML response
	# Multipart-form data, XML stuffed into "input" param
	##
	my $url = shift;
	my $tree = shift;
	my $params = shift || {};
	
	my $doc_name = (keys %$tree)[0];
	my $doc = $tree->{$doc_name};

	my $parser = XML::Lite->new($doc);
	$parser->setDocumentNodeName($doc_name);
	$params->{input} = $parser->compose();

	my $ua = new LWP::UserAgent();

	my $post_time_start = time();
	my $response = undef;
	my $retries = 3;
	
	while ($retries >= 0) {
		my $request = POST ($url, 
			Content_Type => 'form-data',
			Content => [
				%$params
			]
		);
		$response = $ua->request( $request );
		last if $response->is_success();
		
		$retries--;
	}

	##
	# Check for a successful response from Rimfire
	##
	if ($response->is_success()) {
		my $content = $response->content();
				
		$parser = XML::Lite->new(
			text => $content, 
			validation => 0,
			preserveAttributes => 0
		);

		my $error = $parser->getLastError();
		if ($error) {
			return $error;
		}

		my $xml = $parser->getTree();
		return $xml;
	}
	else {
		my $post_time_elapsed = time() - $post_time_start;
		return "HTTP POST ERROR: " . $response->code() . " " . $response->status_line() . 
				" for URL: $url ($post_time_elapsed sec. elapsed)";
	}
}

sub import_param {
	##
	# Import Parameter into hash ref.  Dynamically create arrays for keys
	# with multiple values.
	##
	my ($operator, $key, $value) = @_;

	$value = uri_unescape( $value );
	
	if ($operator->{$key}) {
		if (isa($operator->{$key}, 'ARRAY')) {
			push @{$operator->{$key}}, $value;
		}
		else {
			$operator->{$key} = [ $operator->{$key}, $value ];
		}
	}
	else {
		$operator->{$key} = $value;
	}
}

sub parse_query {
	##
	# Parse query string into hash ref
	##
	my $uri = shift;
	my $query = {};
	
	$uri =~ s@^.*\?@@; # strip off everything before ?
	$uri =~ s/([\w\-\.\/]+)\=([^\&]*)\&?/ import_param($query, $1, $2); ''; /eg;
	
	return $query;
}

sub compose_query {
	##
	# Compose query string
	##
	my $params = shift;
	my $string = shift || '';
	
	foreach my $key (sort keys %$params) {
		if ($string =~ /\?/) { $string .= '&'; } else { $string .= '?'; }
		$string .= $key . '=' . uri_escape($params->{$key});
	}
	
	return $string;
}

sub parse_xml {
	##
	# Parse XML and return tree, or error string
	##
	my $file = shift;
	
	if ($file =~ m@^\w+\:\/\/@) {
		my $resp = wget($file);
		if ($resp->is_success()) { $file = $resp->content(); }
		else { return $resp->status_line(); }
	}
	if (!$file) { return "Not an XML file or string."; }
	
	my $parser = new XML::Lite(
		thingy => $file,
		validation => 0,
		preserveAttributes => 0
	);

	my $error = $parser->getLastError();

	if (!$error) {
		##
		# No errors encountered during parse
		##
		return $parser->getTree();
	}
	else {
		##
		# Error occured, return string
		##
		return $error;
	}
}

sub compose_xml {
	##
	# Render pretty-printed XML from hash tree
	##
	my $tree = shift;
	my $documentNodeName = shift;
	
	my $parser = new XML::Lite( $tree );
	my $sh = new XML::Lite::ScalarHandle();
	$parser->composeNode( $documentNodeName, $tree, $sh, 0 );

	return '<?xml version="1.0"?>' . "\n" . $sh->fetch();
}

sub decode_entities {
	##
	# Convert encoded entities like &amp; to their literal equivalents
	##
	my $text = shift;

	if ($text =~ /\&/) {
		$text =~ s/(\&\#(\d+)\;)/ chr($2); /esg;
		$text =~ s/(\&\#x([0-9A-Fa-f]+)\;)/ chr(hex($2)); /esg;
		$text =~ s/(\&(\w+)\;)/ $entities->{$2} || $1; /esg;
	}

	return $text;
}

sub encode_entities {
	##
	# Encode <, >, & and high-ascii into XML entities
	# Does not include &apos; and &quot;
	##
	my $text = shift;

	$text =~ s/\&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	# $text =~ s/([\x80-\xFF])/ '&#'.ord($1).';'; /eg;

	return $text;
}

sub encode_attrib_entities {
	##
	# Encode ALL entities (used for attributes),
	# including the optional &apos;, &quot; and high/low-ascii
	##
	my $text = shift;

	$text =~ s/\&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/\'/&apos;/g;
	$text =~ s/\"/&quot;/g;
	# $text =~ s/([\x80-\xFF\x00-\x1F])/ '&#'.ord($1).';'; /eg;

	return $text;
}

sub xpath_lookup {
	##
	# Lookup simple XPath in hash tree
	##
	my ($path, $tree) = @_;
	
	my $parser = new XML::Lite( $tree );
	return $parser->lookup( $path );
}

sub db_query {
	##
	# Connect to the database and execute DB query
	##
	my ($db_args, $sql, @execute_args) = @_;
	
	my $connect_string = "dbi:Pg:dbname=" . ($db_args->{'instance'} || $db_args->{'Instance'}) . ';host=' . ($db_args->{'host'} || $db_args->{'Host'});
	my $rows = undef;
	my $retries = 0;
	my $last_error = undef;
	
	while ($retries >= 0) {
		eval {
			# $verbose && warn "\tConnecting to database: $connect_string\n";
			my $dbh = DBI->connect(
				$connect_string,
				$db_args->{'username'} || $db_args->{'Username'},
				$db_args->{'password'} || $db_args->{'Password'},
				{ AutoCommit=>1, RaiseError=>0, PrintError=>1 }
			);
			
			if (!$dbh) { die( "Could not connect to: $connect_string: " . $DBI::errstr ); }
			
			# $verbose && warn "\tExecuting SQL: " . sql_preview($sql, @execute_args) . "\n";
			my $sth = $dbh->prepare($sql);
			if (!$sth) { die( "Could not prepare sql: $sql: " . $DBI::errstr ); }
	
			my $result = $sth->execute( @execute_args );
			if (!$result) { die( "Could not execute sql: $sql: " . $DBI::errstr ); }
			
			$rows = $sth->fetchall_arrayref({});
		}; # eval
		
		if ($@) {
			$last_error = $@;
			$retries--;
			next;
		} # error
		
		last if $rows;
	} # retry loop
	
	if (!$rows) { return $last_error; }
	else { return $rows; }
}

sub parse_cookies {
	##
	# Parse HTTP cookies into hash table
	##
	my $cookie = {};
	my $cookies = $ENV{'HTTP_COOKIE'};
	if ($cookies) {
		foreach my $cookie_raw (split(/\;\s*/, $cookies)) {
			merge_hashes($cookie, parse_query($cookie_raw), 1);
		}
	}
	return $cookie;
}

sub touch {
	##
	# Update file mod date, and create file if nonexistent
	##
	my $file = shift;
	
	unless (-e $file) {
		my $fh = new FileHandle ">>$file";
	}
	
	my $now = int(time());
	utime $now, $now, $file;
}

sub probably {
	##
	# Calculate probability and return true or false
	# 1.0 will always return true
	# 0.5 will return true half the time
	# 0.0 will never return true
	##
	if (!defined($_[0])) { return 1; }
	return ( rand(1) < $_[0] ) ? 1 : 0;
}

sub rand_array {
	##
	# Pick random element from array ref
	##
	my $array = shift;
	return $array->[ int(rand(scalar @$array)) ];
}

sub find_elem_idx {
	##
	# Locate element inside of arrayref by value
	##
	my ($arr, $elem) = @_;
	
	my $idx = 0;
	foreach my $temp (@$arr) {
		if ($temp eq $elem) { return $idx; }
		$idx++;
	}
	
	return -1; # not found
}

sub dumper {
	##
	# Wrapper for Data::Dumper::Dumper
	##
	my $obj = shift;
	
	return Dumper($obj);
}

sub serialize_object {
	##
	# Utility method, uses Data::Dumper to serialize object tree to string
	##
	my $obj = shift;
	local $Data::Dumper::Indent = 0;
	local $Data::Dumper::Terse = 1;
	local $Data::Dumper::Quotekeys = 0;
	return Dumper($obj);
}

sub deep_copy {
	##
	# Deep copy a hash/array tree
	##
	my $in = shift;
	my $VAR1 = undef;
	local $Data::Dumper::Deepcopy = 1;
	return eval( Dumper($in) );
}

##
# Some PHP stuff
##

sub trim {
	##
	# Trim whitespace from beginning and end of string
	##
	my $text = shift;
	
	$text =~ s@^\s+@@; # beginning of string
	$text =~ s@\s+$@@; # end of string
	
	return $text;
}

sub file_get_contents {
	my $file = shift;
	my $contents = undef;
	if ($file =~ m@^\w+\:\/\/@) {
		my $resp = wget($file);
		if ($resp->is_success()) { $contents = $resp->content(); }
	}
	else {
		$contents = load_file($file);
	}
	return $contents;
}

sub file_put_contents {
	return save_file( @_ );
}

sub preg_match {
	my ($regexp, $string, $matches) = @_;
	my $result = '';
	eval '$result = $string =~ m' . $regexp . ';';
	if ($result && defined($matches) && ref($matches)) {
		$matches->[0] = $1;
		$matches->[1] = $2;
		$matches->[2] = $3;
		$matches->[3] = $4;
		$matches->[4] = $5;
		$matches->[5] = $6;
		$matches->[6] = $7;
		$matches->[7] = $8;
		$matches->[8] = $9;
	}
	return $result;
}

sub preg_replace {
	my ($regexp, $replace, $string, $limit) = @_;
	
	if (!defined($limit) || ($limit < 1)) {
		if ($regexp !~ /g$/) { $regexp .= 'g'; }
		$limit = 1;
	}
	
	my $delimiter = substr($string, 0, 1);
	while ($limit--) {
		eval '$string =~ s' . $regexp . $replace . $delimiter . ';';
	}
	
	return $string;
}

sub make_dirs_for {
	##
	# Recursively create directories, given complete path.
	# If incoming path ends in slash, assumes user wants
	# directory there, otherwise assumes path ends in filename,
	# and strips it off.
	##
	my $file = shift;
	my $permissions = shift || 0775;
	
	##
	# if file has ending slash, assume user wants directory there
	##
	if ($file =~ m@/$@) {chop $file;}
	else {
		##
		# otherwise, assume file ends in actual filename, and strip it off
		##
		$file =~ s@^(.+)/[^/]+$@$1@;
	}
	
	##
	# if directories already exist, return immediately
	##
	if (-e $file) {return 1;}
	
	##
	# Assume we're starting from current directory, unless
	# incoming path begins with /
	##
	my $path='.';
	
	##
	# if file starts with slash, remove '.' from path
	# and remove slash from file for proper split operation
	##
	if ($file =~ m@^/@) {
		$path='';
		$file =~ s@^/@@;
	}
	
	##
	# Step through directories, creating as we go.
	##
	foreach my $dir (split(/\//,$file)) {
		##
		# Add current dir onto path
		##
		$path .= '/' . $dir;
		
		##
		# Only create dir if nonexistent.
		# Return 0 if failed to create.
		##
		if (!(-e $path)) {
			if (!mkdir($path,$permissions)) {return 0;}
		}
	}
	
	##
	# Return 1 for success.
	##
	return 1;
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

1;

package XML::Lite;

##
# Lite.pm
#
# Description:
#	Lightweight XML parser and composer module written in pure Perl.
#
# Usage Examples:
#	my $xml = new XML::Lite "my_file.xml";
#	my $tree = $xml->getTree();
#	$tree->{Somthing}->{Other} = "Hello!";
#	$xml->compose( 'my_file.xml' );
#
# Copyright:
#	(c) 2003-2005 Joseph Huckaby.  All Rights Reserved.
##

use strict;
use FileHandle;
use File::Basename;
use UNIVERSAL qw/isa/;
use vars qw/$VERSION/;

my $defaults = {
	compress => 0,
	printErrors => 0,
	indentString => "\t",
	preserveAttributes => 1,
	entities => {
		'amp' => '&',
		'lt' => '<',
		'gt' => '>',
		'apos' => "'",
		'quot' => '"'
	}
};

sub new {
	my $class = shift @_;
	
	##
	# Get named parameters, or filename from argument list.
	##
	my $self;
	if (scalar(@_) > 1) { $self = { %$defaults, @_ }; }
	else { $self = { %$defaults, thingy => shift @_ }; }

	$self->{dtdNodeList} = [];
	$self->{piNodeList} = [];
	$self->{errors} = [];
	$self->{tree} = {};
	
	bless $self, $class;
		
	##
	# Determine what thingy is, and populate correct argument.
	##
	if ($self->{thingy}) {
		$self->importThingy( $self->{thingy} );
		delete $self->{thingy};
	}
	
	##
	# See what args we have, and get to the point of XML text.
	##
	$self->prepareParse();
				
	##
	# Parse XML
	##
	if ($self->{text}) { $self->parse(); }
	
	return $self;
}

sub importThingy {
	##
	# Import text, FileHandle or filename into root hash
	##
	my $self = shift;
	my $thingy = shift;
	
	undef $self->{text};
	undef $self->{fh};
	undef $self->{file};
	
	if (ref($thingy)) {
		if (isa($thingy, 'FileHandle')) {
			$self->{fh} = $thingy;
		}
		else {
			$self->{tree} = $thingy;
		}
	}
	elsif ($thingy =~ m@<.+?>@) {
		$self->{text} = $thingy;
	}
	elsif (-e $thingy) {
		$self->{file} = $thingy;
	}
	else {
		$self->throwError(
			type => 'parse',
			key => 'Thingy not found: ' . $thingy
		);
		return undef;
	}
}

sub prepareParse {
	##
	# Get to the point of XML text to prepare for parsing
	##
	my $self = shift;
	
	if (!$self->{text}) {
		if ($self->{file} && !$self->{fh}) {
			$self->{fh} = new FileHandle $self->{file};
			if (!$self->{fh}) {
				$self->throwError(
					type => 'parse',
					key => 'File not found: ' . $self->{file}
				);
				return undef;
			}
		}
		if ($self->{fh}) {
			my $len = read( $self->{fh}, $self->{text}, 
				(stat($self->{fh}))[7] );
			undef $self->{fh};
			if (!$len) {
				$self->throwError(
					type => 'parse',
					key => 'Zero bytes read'
				);
				return undef;
			} # zero bytes
		}
	}
}

sub reload {
	##
	# Reload file
	##
	my $self = shift;
	
	undef $self->{text};
	$self->{errors} = [];
	$self->{tree} = {};
	
	$self->prepareParse();
	if ($self->{text}) { $self->parse(); }
}

sub parse {
	##
	# Parse one level of nodes and recurse into nested nodes
	##
	my $self = shift;
	my $branch = shift || $self->{tree};
	my $name = shift || undef;
	my $foundClosing = 0;
		
	##
	# Process a single node, and any preceding text
	##
	while ($self->{text} =~ m@([^<]*?)<([^>]+)>@sog) {
		my ($before, $tag) = ($1, $2);
		
		##
		# If there was text preceding the opening tag, insert it now
		##
		if ($before =~ /\S/) {
			$before =~ s@^(\s*)(.+?)(\s*)$@$3@s;
			if ($branch->{content}) { $branch->{content} .= ' '; }
			$branch->{content} .= $self->decodeEntities($2);
		}
		
		##
		# Check if tag is a PI, DTD, CDATA, or Comment tag
		##
		if ($tag =~ /^\s*([\!\?])/o) {
			if    ($tag =~ /^\s*\?/) { 
				$tag = $self->parsePINode( $tag ); }
			elsif ($tag =~ /^\s*\!--/) {
				$tag = $self->parseCommentNode( $tag ); }
			elsif ($tag =~ /^\s*\!DOCTYPE/) { 
				$tag = $self->parseDTDNode( $tag ); }
			elsif ($tag =~ /^\s*\!\s*\[\s*CDATA/) {
				$tag = $self->parseCDATANode( $tag );
				if ($tag) {
					if ($branch->{content}) { $branch->{content} .= ' '; }
					$branch->{content} .= $self->decodeEntities($tag);
					next;
				}
			}
			else {
				$self->throwParseError( "Malformed special tag", $tag );
				last;
			}
			if (!defined($tag)) { last; }
			next;
		}
		else {
			##
			# Tag is standard, so parse name and attributes (if any)
			##
			if ($tag !~ m@^\s*(/?)([\w\-\:\.]+)\s*(.*)$@os) {
				$self->throwParseError( "Malformed tag", $tag );
				last;
			}
			my ($closing, $nodeName, $attribsRaw) = ($1, $2, $3);
			
			##
			# If this is a closing tag, make sure it matches its opening tag
			##
			if ($closing) {
				if ($nodeName eq ($name || '')) {
					$foundClosing = 1;
					last;
				}
				else {
					$self->throwParseError( 
						"Mismatched closing tag (expected </" . 
						$name . ">)", $tag );
					last;
				}
			}
			else {
				##
				# Not a closing tag, so parse attributes into hash.  If tag
				# is self-closing, no recursive parsing is needed.
				##
				my $selfClosing = $attribsRaw =~ s/\/\s*$//;
				my $leaf = {};
				
				if ($attribsRaw) {
					if ($self->{preserveAttributes}) {
						my $attribs = {};
						$attribsRaw =~ s@([\w\-\:\.]+)\s*=\s*([\"\'])([^\2]*?)\2@ $attribs->{$1} = $self->decodeEntities($3); ''; @esg;
						$leaf->{_Attribs} = $attribs;
					}
					else {
						$attribsRaw =~ s@([\w\-\:\.]+)\s*=\s*([\"\'])([^\2]*?)\2@ $leaf->{$1} = $self->decodeEntities($3); ''; @esg;
					}
					
					if ($attribsRaw =~ /\S/) {
						$self->throwParseError( 
							"Malformed attribute list", $tag );
					}
				}

				if (!$selfClosing) {
					##
					# Recurse for nested nodes
					##
					$self->parse( $leaf, $nodeName );
					if ($self->error()) { last; }
				}
				
				##
				# Compress into simple node if text only
				##
				my $num_keys = scalar keys %$leaf;
				if (defined($leaf->{content}) && ($num_keys == 1)) {
					$leaf = $leaf->{content};
				}
				elsif (!$num_keys) {
					$leaf = '';
				}
				
				##
				# Add leaf to parent branch
				##
				if (defined($branch->{$nodeName})) {
					if (isa($branch->{$nodeName}, 'ARRAY')) {
						push @{$branch->{$nodeName}}, $leaf;
					}
					else {
						my $temp = $branch->{$nodeName};
						$branch->{$nodeName} = [ $temp, $leaf ];
					}
				}
				else {
					$branch->{$nodeName} = $leaf;
				}
				
				if ($self->error() || ($branch eq $self->{tree})) { last; }
			} # not closing tag
		} # not comment/DTD/XML tag
	} # while loop

	##
	# Make sure we found the closing tag
	##
	if ($name && !$foundClosing) {
		$self->throwParseError( 
			"Missing closing tag (expected </" . 
			$name . ">)", $name );
	}
	
	##
	# If we are the master node, finish parsing and setup our doc node
	##
	if ($branch eq $self->{tree}) { $self->finishParse(); }
	if (!$self->error()) { $self->{parsed} = 1; }
}

sub finishParse {
	##
	# Grab any loose text/comments after final closing node, and setup docNodeName
	##
	my $self = shift;

	if ($self->{tree}->{content}) { delete $self->{tree}->{content}; }
	
	if (scalar keys %{$self->{tree}} > 1) {
		$self->throwError(
			type => 'parse',
			key => 'Only one top-level node is allowed in document'
		);
		return;
	}
	
	$self->{documentNodeName} = (keys %{$self->{tree}})[0];
	if ($self->{documentNodeName}) {
		$self->{tree} = $self->{tree}->{ $self->{documentNodeName} };
	}
}

sub getTree {
	##
	# Get hash tree representation of parsed XML document
	##
	my $self = shift;

	return $self->{tree};
}

sub parsePINode {
	##
	# Parse Processor Instruction Node, e.g. <?xml version="1.0"?>
	##
	my ($self, $tag) = @_;
	
	if ($tag !~ m@^\s*\?\s*([\w\-\:]+)\s*(.*)$@os) {
		$self->throwParseError( "Malformed PI tag", $tag );
		return undef;
	}
	
	push @{$self->{piNodeList}}, $tag;
	return $tag;
}

sub parseCommentNode {
	##
	# Parse Comment Node, e.g. <!-- hello -->
	##
	my ($self, $tag) = @_;
	
	##
	# Check for nested nodes, and find actual closing tag.
	##
	while ($tag !~ /--$/) {
		if ($self->{text} =~ m@([^>]*?)>@sog) {
			$tag .= '>' . $1;
		} else {
			$self->throwParseError( "Unclosed comment tag", $tag, 
				length($self->{text}) - length($tag) );
			return undef;
		}
	}
	
	return $tag;
}

sub parseDTDNode {
	##
	# Parse Document Type Descriptor Node, e.g. <!DOCTYPE ... >
	##
	my ($self, $tag) = @_;
	
	##
	# Check for external reference tag first
	##
	if ($tag =~ m@^\s*\!DOCTYPE\s+([\w\-\:]+)\s+SYSTEM\s+\"([^\"]+)\"@) {
		push @{$self->{dtdNodeList}}, $tag;
	}
	elsif ($tag =~ m@^\s*\!DOCTYPE\s+([\w\-\:]+)\s+\[@) {
		##
		# Tag is inline, so check for nested nodes.
		##
		while ($tag !~ /\]$/) {
			if ($self->{text} =~ m@([^>]*?)>@sog) {
				$tag .= '>' . $1;
			} else {
				$self->throwParseError( "Unclosed DTD tag", $tag, 
					length($self->{text}) - length($tag) );
				return undef;
			}
		}
		
		##
		# Make sure complete tag is well-formed, and push onto DTD stack.
		##
		if ($tag =~ m@^\s*\!DOCTYPE\s+([\w\-\:]+)\s+\[(.*)\]@s) {
			push @{$self->{dtdNodeList}}, $tag;
		} else {
			$self->throwParseError( "Malformed DTD tag", $tag );
			return undef;
		}
	}
	else {
		$self->throwParseError( "Malformed DTD tag", $tag );
		return undef;
	}
	
	return $tag;
}

sub parseCDATANode {
	##
	# Parse CDATA Node, e.g. <![CDATA[Brooks & Shields]]>
	##
	my ($self, $tag) = @_;
	
	##
	# Check for nested nodes, and find actual closing tag.
	##
	while ($tag !~ /\]\]$/) {
		if ($self->{text} =~ m@([^>]*?)>@sog) {
			$tag .= '>' . $1;
		} else {
			$self->throwParseError( "Unclosed CDATA tag", $tag, 
				length($self->{text}) - length($tag) );
			return undef;
		}
	}
	
	if ($tag =~ m@^\s*\!\s*\[\s*CDATA\s*\[(.*)\]\]@s) {
		return $1;
	} else {
		$self->throwParseError( "Malformed CDATA tag", $tag );
		return undef;
	}
}

sub composeNode {
	##
	# Compose a single node into proper XML, and recurse into
	# child nodes.
	##
	my ($self, $name, $branch, $fh, $indent) = @_;
	my $eol = $self->{compress} ? "" : "\n";
	my $istr = $self->{compress} ? "" : ($self->{indentString} x $indent);
	
	##
	# If branch is a hash reference, create node and walk keys
	##
	if (isa($branch, 'HASH')) {
		##
		# Compose indentation and opening tag
		##
		$fh->print( $istr . "<$name");
		
		my $numKeys = scalar keys %{$branch};
		my $hasAttribs = 0;
		
		##
		# Compose attributes, if any
		##
		if (defined($branch->{_Attribs})) {
			$hasAttribs = 1;
			foreach my $key (sort keys %{$branch->{_Attribs}}) {
				$fh->print( " $key=\"" . $self->encodeAttribEntities($branch->{_Attribs}->{$key}) . "\"" );
			}
		}
		
		##
		# Walk keys if any exist
		##
		if ($numKeys > $hasAttribs) {
			$fh->print( '>' );
			
			if (defined($branch->{content})) {
				##
				# Simple text node
				##
				$fh->print( $self->encodeEntities($branch->{content}) . "</$name>$eol" );
			}
			else {
				$fh->print( "$eol" );
				
				##
				# Step through each key, recursively calling composeNode()
				##
				foreach my $key (sort keys %{$branch}) {
					if ($key ne '_Attribs') {
						$self->composeNode( $key, $branch->{$key}, $fh, $indent + 1 );
					}
				}
				
				##
				# Compose closing tag with indentation
				##
				$fh->print( $istr . "</$name>$eol");
			}
		}
		else {
			##
			# No sub elements or text content, so make this a self-closing tag.
			##
			$fh->print( "/>$eol" );
		}
	}
	elsif (ref($branch) eq "ARRAY") {
		##
		# If branch is an array, recursively call composeNode() for each element,
		# but pass the same indent value as we were given.
		##
		foreach my $node (@{$branch}) {
			$self->composeNode( $name, $node, $fh, $indent );
		}
	}
	else {
		##
		# Branch is neither a hash or array, so it must be a plain text node
		# with no attributes.
		##
		$fh->print( $istr . "<$name>" . $self->encodeEntities($branch) . "</$name>$eol" );
	}
}

sub compose {
	##
	# Recursively compose XML from hash tree.
	##
	my $self = shift;
	my $fh = shift || XML::Lite::ScalarHandle->new();
	my $eol = $self->{compress} ? "" : "\n";

	##
	# If argument was a scalar, treat as path and open FileHandle for writing
	##
	if (!ref($fh)) {
		$fh = new FileHandle ">$fh";
		if (!$fh) { return undef; }
	}
	
	##
	# First print XML PI Node and any DTD nodes from the original xml text
	##
	if (scalar @{$self->{piNodeList}} > 0) {
		foreach my $piNode (@{$self->{piNodeList}}) {
			$fh->print( "<$piNode>$eol" );
		}
	}
	else {
		$fh->print( qq{<?xml version="1.0"?>$eol} );
	}
	
	if (scalar @{$self->{dtdNodeList}} > 0) {
		foreach my $dtdNode (@{$self->{dtdNodeList}}) {
			$fh->print( "<$dtdNode>$eol" );
		}
	}
	
	##
	# Recursively compose all nodes
	##
	$self->composeNode( $self->{documentNodeName}, $self->{tree}, $fh, 0 );

	##
	# Return composed XML if running in scalar mode, or 1 for success
	##
	if (isa($fh, 'XML::Lite::ScalarHandle')) { return $fh->fetch(); }

	return 1;
}

sub save {
	##
	# Write XML back out to original file
	##
	my $self = shift;
	my $atomic = shift || 0;
	
	if ($atomic) {
		my $temp_file = $self->{file} . ".$$." . rand() . ".tmp";
		if (!$self->compose( $temp_file )) {
			return undef;
		}
		if (!rename( $temp_file, $self->{file} )) {
			unlink $temp_file;
			return undef;
		}
	}
	else {
		return $self->compose( $self->{file} );
	}
	
	return 1;
}

sub setDocumentNodeName {
	##
	# Set the root document node name for composing
	##
	my $self = shift;

	$self->{documentNodeName} = shift;
}

sub addDTDNode {
	##
	# Push a new DTD node onto end of stack.  This is only for composing.
	##
	my $self = shift;
	my $node = shift;

	$node =~ s/^<(.+)>/$1/; # strip opening and closing angle brackets
	push @{$self->{dtdNodeList}}, $node;
}

sub error {
	##
	# Returns number of errors that occured, 0 if none
	##
	my $self = shift;

	return scalar @{$self->{errors}};
}

sub getError {
	##
	# Get specified error formatted in plain text
	##
	my $self = shift;
	my $error = shift;
	my $text = '';

	if (!$error) { return ''; }

	$text = ucfirst( $error->{type} || 'general' ) . ' Error';
	if ($error->{code}) { $text .= ' ' . $error->{code}; }
	$text .= ': ' . $error->{key};
	
	if ($error->{line}) { $text .= ' on line ' . $error->{line}; }
	if ($error->{text}) { $text .= ': ' . $error->{text}; }

	return $text;
}

sub getLastError {
	##
	# Get most recently thrown error in plain text format
	##
	my $self = shift;

	if (!$self->error()) { return undef; }
	return $self->getError( $self->{errors}->[-1] );
}

sub printError {
	##
	# Format error in plain text and send to STDERR
	##
	my $self = shift;
	my $error = shift;
	my $text = $self->getError( $error );
	
	warn "$text\n";
}

sub throwError {
	##
	# Push new error onto stack
	##
	my $self = shift;
	my $args = {@_};
	
	$args->{text} ||= '';
	$args->{text} =~ s@^\s+@@s;
	if ($args->{text} =~ /\n/) {
		$args->{text} =~ s@^(.+?)\n.+$@$1...@s;
	}
	
	push @{$self->{errors}}, $args;
	if ($self->{printErrors}) { $self->printError( $args ); }
}

sub throwParseError {
	##
	# Throw new parse error, and track location in original text.
	##
	my $self = shift;
	my $key = shift;
	my $tag = shift;
	
	my $line_num = (substr($self->{text}, 0, shift || 
		pos($self->{text})) =~ tr/\n//) + 1;
	$line_num -= $tag =~ tr/\n//;
	
	$self->throwError(
		type => 'parse',
		key => $key, 
		text => '<' . $tag . '>', 
		line => $line_num
	);
}

sub decodeEntities {
	##
	# Convert encoded entities like &amp; to their literal equivalents
	##
	my $self = shift;
	my $text = shift;

	if ($text =~ /\&/) {
		$text =~ s/(\&\#(\d+)\;)/ chr($2); /esg;
		$text =~ s/(\&\#x([0-9A-Fa-f]+)\;)/ chr(hex($2)); /esg;
		$text =~ s/(\&(\w+)\;)/ $self->{entities}->{$2} || $1; /esg;
	}

	return $text;
}

sub encodeEntities {
	##
	# Encode <, >, & and high-ascii into XML entities
	# Does not include &apos; and &quot;
	##
	my $self = shift;
	my $text = shift;

	$text =~ s/\&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	# $text =~ s/([\x80-\xFF])/ '&#'.ord($1).';'; /eg;

	return $text;
}

sub encodeAttribEntities {
	##
	# Encode ALL entities (used for attributes),
	# including the optional &apos;, &quot; and high/low-ascii
	##
	my $self = shift;
	my $text = shift;

	$text =~ s/\&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/\'/&apos;/g;
	$text =~ s/\"/&quot;/g;
	# $text =~ s/([\x80-\xFF\x00-\x1F])/ '&#'.ord($1).';'; /eg;

	return $text;
}

sub lookup {
	##
	# Run simple XPath query, supporting things like:
	#		/Simple/Path/Here
	#		/ServiceList/Service[2]/@Type
	#		/Parameter[@Name='UsePU2']/@Value
	# Return ref to hash/array, or scalar string
	##
	my ($self, $xpath, $tree) = @_;
	if (!$tree) { $tree = $self->{tree}; }
	
	my $ref = $self->lookup_ref( $xpath, $tree );
	if (defined($ref) && isa($ref, 'SCALAR')) { $ref = $$ref; } # dereference scalars
	return $ref;
}

sub set {
	##
	# Evaluate xpath and set target to supplied value
	# DOES NOT CREATE PARENT NODES
	# Target type (hash, array, scalar) must match supplied type
	##
	my ($self, $xpath, $value, $tree) = @_;
	if (!$tree) { $tree = $self->{tree}; }
	
	my $value_ref = $value;
	if (!ref($value_ref)) { $value_ref = \$value; }
	
	my $ref = $self->lookup_ref( $xpath, $tree );
	if (!defined($ref)) { return undef; } # lookup failed
	if (ref($ref) ne ref($value_ref)) { return undef; } # type mismatch
	
	if (isa($ref, 'HASH')) { %$ref = %$value_ref; }
	elsif (isa($ref, 'ARRAY')) { @$ref = @$value_ref; }
	elsif (isa($ref, 'SCALAR')) { $$ref = $$value_ref; }
	else { return undef; } # unsupported type
	
	return 1;
}

sub lookup_ref {
	##
	# Evaluate xpath query and return reference to node (even if scalar ref)
	##
	my ($self, $xpath, $tree) = @_;
	if (!$tree) { $tree = $self->{tree}; }
		
	while ($xpath =~ /^\/?([^\/]+)/) {
		my $matches = [undef, $1];
		if ($matches->[1] =~ /^([\w\-\:\.]+)\[([^\]]+)\]$/) {
			my $arr_matches = [undef, $1, $2];
			# array index lookup, possibly complex attribute match
			if (defined($tree->{$arr_matches->[1]})) {
				$tree = $tree->{$arr_matches->[1]};
				my $elements = $tree; if (!isa($tree, 'ARRAY')) { $elements = [$tree]; }
				
				if ($arr_matches->[2] =~ /^\d+$/) {
					# simple array index lookup, i.e. /Parameter[2]
					if (defined($elements->[$arr_matches->[2]])) {
						$tree = ref($elements->[$arr_matches->[2]]) ? $elements->[$arr_matches->[2]] : \$elements->[$arr_matches->[2]];
						$xpath =~ s/^\/?([^\/]+)//;
					}
					else {
						return undef;
					}
				}
				elsif ($arr_matches->[2] =~ /^\@([\w\-\:\.]+)\=\'([^\']*)\'$/) {
					my $sub_matches = [undef, $1, $2];
					# complex attrib search query, i.e. /Parameter[@Name='UsePU2']
					my $count = scalar @$elements;
					my $found = 0;

					for (my $k = 0; $k < $count; $k++) {
						my $elem = $elements->[$k];
						if (defined($elem->{$sub_matches->[1]}) && ($elem->{$sub_matches->[1]} eq $sub_matches->[2])) {
							$found = 1;
							$tree = ref($elem) ? $elem : \$elem;
							$k = $count;
						}
						elsif (defined($elem->{'_Attribs'}) && 
								defined($elem->{'_Attribs'}->{$sub_matches->[1]}) && 
								($elem->{'_Attribs'}->{$sub_matches->[1]} eq $sub_matches->[2])) {
							$found = 1;
							$tree = ref($elem) ? $elem : \$elem;
							$k = $count;
						}
					} # foreach element
					
					if ($found) { $xpath =~ s/^\/?([^\/]+)//; }
					else {
						return undef;
					}
				} # attrib search
			} # found basic element name
			else {
				return undef;
			}
		} # array index lookup
		elsif ($matches->[1] =~ /^\@([\w\-\:\.]+)$/) {
			my $sub_matches = [undef, $1];
			# attrib lookup
			if (defined($tree->{'_Attribs'})) { $tree = $tree->{'_Attribs'}; }
			if (defined($tree->{$sub_matches->[1]})) {
				$tree = ref($tree->{$sub_matches->[1]}) ? $tree->{$sub_matches->[1]} : \$tree->{$sub_matches->[1]};
				$xpath =~ s/^\/?([^\/]+)//;
			}
			else {
				return undef;
			}
		} # attrib lookup
		elsif (defined($tree->{$matches->[1]})) {
			$tree = ref($tree->{$matches->[1]}) ? $tree->{$matches->[1]} : \$tree->{$matches->[1]};
			$xpath =~ s/^\/?([^\/]+)//;
		} # simple element lookup
		else {
			return undef;
		} # bad xpath
	} # foreach xpath node

	return $tree;
}

package XML::Lite::ScalarHandle;

##
# Simple scalar accumulation class supporting print() and fetch() methods.
##

sub new {
	my $class = shift;
	return bless { text => shift || '' }, $class;
}

sub print {
	my $self = shift;
	$self->{text} .= shift || '';
}

sub fetch {
	my $self = shift;
	return $self->{text};
}

1;

package Args;

use strict;

sub new {
	##
	# Class constructor method
	##
	my $self = bless {}, shift;
	my @input = @_;
	if (!@input) { @input = @ARGV; }
	
	my $mode = undef;
	my $key = undef;
	
	while (defined($key = shift @input)) {
		if ($key =~ /^\-*(\w+)=(.+)$/) { $self->{$1} = $2; next; }
		
		my $dash = 0;
		if ($key =~ s/^\-+//) { $dash = 1; }

		if (!defined($mode)) {
			$mode = $key;
		}
		else {
			if ($dash) {
				if (!defined($self->{$mode})) { $self->{$mode} = 1; }
				$mode = $key;
			} 
			else {
				if (!defined($self->{$mode})) { $self->{$mode} = $key; }
				else { $self->{$mode} .= ' ' . $key; }
			} # no dash
		} # mode is 1
	} # while loop

	if (defined($mode) && !defined($self->{$mode})) { $self->{$mode} = 1; }

	return $self;
}

1;
