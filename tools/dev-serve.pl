#!/usr/bin/perl
# Minimal static file server for local preview of the exported web build.
# Usage: perl tools/dev-serve.pl [port] [docroot] [bind]
# Serves the public/ directory with the MIME types Godot's HTML5 shell needs
# (wasm/pck). If a "<file>.gz" sibling exists and the client accepts gzip
# (wasm/pck are pre-compressed for the phone playtest), it is served
# Content-Encoding: gzip. No caching.
#   bind 127.0.0.1 (default) = this machine only
#   bind 0.0.0.0             = LAN, so a phone on the same wifi can playtest

use strict;
use warnings;
use IO::Socket::INET;

my $port    = $ARGV[0] || 8080;
my $docroot = $ARGV[1] || 'public';
my $bind    = $ARGV[2] || '127.0.0.1';

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
    LocalAddr => $bind,
    LocalPort => $port,
    Proto     => 'tcp',
    Listen    => 16,
    Reuse     => 1,
) or die "cannot listen on $bind:$port: $!";

print "dev-serve: serving $docroot at http://$bind:$port/\n";
$| = 1;

while (my $client = $server->accept) {
    # Chromium speculatively preconnects without sending data; a blocking
    # read here would freeze the whole accept loop. Time the read out.
    $client->timeout(5);
    my $req = <$client>;
    unless (defined $req) { close $client; next; }
    # Drain the rest of the request headers, remembering gzip support.
    my $accepts_gzip = 0;
    while (my $line = <$client>) {
        last if $line =~ /^\r?\n$/;
        $accepts_gzip = 1 if $line =~ /^\s*Accept-Encoding:.*\bgzip\b/i;
    }

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
    my $gz_ok = -f "$file.gz" ? 1 : 0;
    print STDERR "req $path accepts_gzip=$accepts_gzip gz_ok=$gz_ok\n";
    my $gz = $accepts_gzip && $gz_ok ? "$file.gz" : '';
    my $size = -s ($gz || $file);

    print $client "HTTP/1.1 200 OK\r\nContent-Type: $mime\r\nContent-Length: $size\r\nCache-Control: no-cache\r\nAccess-Control-Allow-Origin: *\r\n";
    print $client "Content-Encoding: gzip\r\nVary: Accept-Encoding\r\n" if $gz;
    print $client "Connection: close\r\n\r\n";

    if ($method eq 'GET') {
        if (open my $fh, '<:raw', ($gz || $file)) {
            my $chunk;
            while (read($fh, $chunk, 65536)) { print $client $chunk; }
            close $fh;
        }
    }
    close $client;
}
