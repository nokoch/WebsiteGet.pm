package WebsiteGet;

use strict;
use warnings;
use IO::Socket;
use Data::Dumper;

my %options = (timeout => 10, optionalHeaders => { "User-Agent" => "WebsiteGet" });
my %downloadedData = ();

=begin nd
new creates the WebsiteGet-object and accepts a hash. Allows following options:
timeout => $timeout # sets the timeout for the request
"User-Agent" => $userAgent # sets the User-Agent
=cut
sub new {
	my $self = shift;
	my %opts = @_;
	foreach (keys %opts) {
		if($_ eq "User-Agent") {
			$self->userAgent($opts{$_});
		} else {
			$options{$_} = $opts{$_};
		}
	}

	return bless \%opts, $self;
}

=begin nd
userAgent sets the User-Agent thats used in the HTTP-Request
=cut
sub userAgent {
	my $self = shift;
	$options{optionalHeaders}{"User-Agent"} = $_[0] ? shift : $options{optionalHeaders}{"User-Agent"};

	return $options{optionalHeaders}{"User-Agent"};
}

=begin nd
timeout sets the timeout for the HTTP-Request. If set to 0, timeout is disabled.
=cut
sub timeout {
	my $self = shift;
	$options{timeout} = $_[0] ? shift : $options{timeout};

	return $options{timeout};
}

=begin nd
optionalHeaders sets optional headers for the HTTP-Request. A call will look like this:
$wg->optionalHeaders($key => $value, $key2 => $value2)
=cut
sub optionalHeaders {
	my $self = shift;
	my %headers = @_;

	foreach (keys %headers) {
		$options{optionalHeaders}{$_} = $headers{$_};
	}

	if(exists($options{optionalHeaders})) {
		return $options{optionalHeaders};
	} else {
		return undef;
	}
}

=begin nd
getHTTPHeader returns the plaintext header as its returned by the server.
=cut
sub getHTTPHeader {
	my $self = shift;
	
	if(exists($downloadedData{full_request})) {
		my @data = split("\r\n\r\n", $downloadedData{full_request}, 2);
		$downloadedData{header} = $data[0];
		$downloadedData{data} = $data[1];
	} else {
		die "Nothing downloaded yet.";
	}

	return $downloadedData{header};
}

=begin nd
getHTTPHeader returns a hash of the HTTP-Header. It splits key => value by first ":",
which, at some points, might deliver incorrect data. Please check yourself, whether this
returns what you expected or not in your case.
=cut
sub getHTTPHeaderHash {
	my $self = shift;

	my $str = "";

	if(exists($downloadedData{header})) {
		$str = $downloadedData{header};
	} else {
		$str = $self->getHTTPHeader();
	}

	my %hash = ();
	if($str) {
		foreach my $line (split "\r\n", $str) {
			my ($key, $values) = split(": {1,}", $line, 2);
			$hash{$key} = $values;
		}
	} else {
		die;
	}
	$downloadedData{headerHash} = \%hash;
	return $downloadedData{headerHash};
}

=begin nd
getSite returns the website that is given to it as first parameter.
All other Parameters are optional.
Parameters:
$wg->getSite( $url, # the url that will be downloaded
              $port, # the port on the server, optional. If not set or 
	             # undef, it will be set automatically to 80.
              $proto # Protocol, optional. If not set or undef,
                     # it will be automatically set to 'tcp'
             );
=cut
sub getSite {
	my $self = shift;
	my $url = shift;
	die "No URL!" unless $url;
	my $port = shift // 80;
	my $proto = shift // "tcp";
	my ($baseURL, $baseFile) = _getBaseUrl($url);
	eval {
		local $SIG{ALRM} = sub {die "Timeout.\n"};
		alarm $options{timeout};
		my $socket = new IO::Socket::INET(PeerAddr => $baseURL, PeerPort => $port, Proto => $proto);
		unless($socket) {
			warn "Konnte kein Socket erstellen!";
			exit(0);
		} else {
			print $socket "GET $baseFile HTTP/1.0\r\n";
			print $socket "Host: $baseURL\r\n";
			foreach (keys %{$options{optionalHeaders}}) {
				print $socket "$_: $options{optionalHeaders}{$_}\r\n";
			}
			print $socket "\r\n";

			while (<$socket>) {
				$downloadedData{full_request} .= $_;
			}
			close $socket;
		}
		alarm 0;
	};
	if($@) {
		die $@;
	} else {
		return $downloadedData{full_request};
	}
}

=begin nd
_getBaseUrl returns 2 variables: The domain itself and the files in the URL.
Example:

my ($url, $file) = _getBaseUrl("https://github.com/index.php");
# $url is https://github.com, $file is /index.php
=cut
sub _getBaseUrl {
	my $url = shift;
	if($url =~ m#(?:http(?:s)?://)?(.+?)(?:$|/)(.*)#) {
		my $u = $1;
		my $f = $2 ? $2 : "/";
		$f = "/$f" unless $f =~ /^\//;
		return ($u, $f);
	} else {
		die;
	}
}

1;
