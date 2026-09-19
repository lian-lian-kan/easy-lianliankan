#!/usr/bin/perl
# Minimal static file server for local preview of the exported web build.
# Usage: perl tools/dev-serve.pl [port] [docroot]
# Serves the public/ directory at http://localhost:<port>/ with the MIME
# types Godot's HTML5 shell needs (wasm/pck). No compression, no caching.

use strict;
use warnings;
use IO::Socket::INET;

my $port    = $ARGV[0] || 8080;
my $docroot = $ARGV[1] || 'public';

my %MIME = (
    html => 'text/html',
    js   => 'application/javascript',
    wasm => 'application/wasm',
    pck  => 'application/octet-stream',
    png  => 'image/png',
    svg  => 'image/svg+xml',
    css  => 'text/css',
    json => 'application/json',
    ico  => 'image/x-icon',
);

my $server = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => $port,
    Proto     => 'tcp',
    Listen    => 16,
    Reuse     => 1,
) or die "cannot listen on $port: $!";

print "dev-serve: serving $docroot at http://localhost:$port/\n";
$| = 1;

while (my $client = $server->accept) {
    # Chromium speculatively preconnects without sending data; a blocking
    # read here would freeze the whole accept loop. Time the read out.
    $client->timeout(5);
    my $req = <$client>;
    unless (defined $req) { close $client; next; }
    # Drain the rest of the request headers.
    while (my $line = <$client>) { last if $line =~ /^\r?\n$/; }

    my ($method, $target) = $req =~ m{^(\w+)\s+(\S+)};
    unless ($method && $target) { close $client; next; }
    $target =~ s/\?.*$//;

    my $path = $target eq '/' ? '/index.html' : $target;
    $path =~ s{/\.\.(/|$)}{/}g;      # flatten traversal attempts
    $path = "/index.html" if $path =~ /\.\./;

    my $file = "$docroot$path";
    if (-d $file) { $file .= '/index.html'; }

    if ($method ne 'GET' && $method ne 'HEAD') {
        print $client "HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
        close $client; next;
    }

    if (!-f $file) {
        print $client "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\nNot Found: $path";
        close $client; next;
    }

    my ($ext) = $file =~ /\.([a-zA-Z0-9]+)$/;
    my $mime = $MIME{lc($ext // '')} || 'application/octet-stream';
    my $size = -s $file;

    print $client "HTTP/1.1 200 OK\r\nContent-Type: $mime\r\nContent-Length: $size\r\nCache-Control: no-cache\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n";

    if ($method eq 'GET') {
        if (open my $fh, '<:raw', $file) {
            my $chunk;
            while (read($fh, $chunk, 65536)) { print $client $chunk; }
            close $fh;
        }
    }
    close $client;
}
