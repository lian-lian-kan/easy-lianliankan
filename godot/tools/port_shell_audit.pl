#!/usr/bin/perl
# Perl port of tools/shell_audit.py — local counterpart for machines without
# python3 (e.g. the Windows dev box). Check semantics mirror the python file
# 1:1 (all 8 checks, same ERROR/WARN levels, same exit codes); keep the two
# in sync when either side changes. Run from godot/:  perl tools/port_shell_audit.pl
use strict;
use warnings;
use File::Spec;

my @errors;
my @warnings;

sub read_file {
    my ($path) = @_;
    open(my $fh, '<', $path) or die "cannot read $path: $!";
    local $/;
    my $src = <$fh>;
    close $fh;
    return $src;
}

sub report {
    my ($level, $msg) = @_;
    if ($level eq 'ERROR') { push @errors, $msg; }
    else { push @warnings, $msg; }
    print "  $level  $msg\n";
}

sub list_gd {
    my ($dir) = @_;
    my @out;
    my @stack = ($dir);
    while (@stack) {
        my $d = pop @stack;
        opendir(my $dh, $d) or next;
        while (my $e = readdir $dh) {
            next if $e eq '.' || $e eq '..';
            my $p = File::Spec->catfile($d, $e);
            if (-d $p) { push @stack, $p; }
            elsif ($e =~ /\.gd$/) { push @out, $p; }
        }
        closedir $dh;
    }
    return sort @out;
}

sub count_lines {    # newlines before offset, 1-based line number
    my ($src, $off) = @_;
    return (substr($src, 0, $off) =~ tr/\n//) + 1;
}

my @SCRIPTS = list_gd('scripts');
my @TESTS   = list_gd('tests');
my @SCENES  = glob('scenes/*.tscn');
my @ALL     = (@SCRIPTS, @TESTS, @SCENES);

my %SRC;
$SRC{$_} = read_file($_) for @SCRIPTS;
my $game_src = $SRC{'scripts/game.gd'} // '';
if ($game_src eq '') {
    report('ERROR', 'scripts/game.gd missing');
    if (@errors) { print "\nshell_audit(port): " . scalar(@errors) . " ERROR(S)\n"; exit 1; }
    print "\nshell_audit(port): clean\n";
    exit 0;
}
my %game_methods = map { $_ => 1 } $game_src =~ /(?m)^(?:static )?func (\w+)\(/g;

# --- 1) thin-shell completeness ---
print "== 1. thin-shell completeness (game._x calls resolve)\n";
my %missing;
for my $path (@SCRIPTS) {
    next if $path =~ /game\.gd$/;
    while ($SRC{$path} =~ /\bgame\.(_\w+)\s*\(/g) {
        my $name = $1;
        push @{ $missing{$name} }, $path unless $game_methods{$name};
    }
}
for my $name (sort keys %missing) {
    report('ERROR', "game.$name() called but not defined in game.gd <- " . join(',', @{ $missing{$name} }));
}
print "  ok  every game._x call resolves\n" unless %missing;

# --- 2) signal connect targets ---
print "== 2. signal connect targets resolve\n";
my @connect_bad;
for my $path (@SCRIPTS) {
    my $src = $SRC{$path};
    while ($src =~ /connect\("[^"]+",\s*game,\s*"(_\w+)"/g) {
        push @connect_bad, [$path, $1] unless $game_methods{$1};
    }
    my %owner = map { $_ => 1 } $src =~ /(?m)^(?:static )?func (\w+)\(/g;
    while ($src =~ /connect\("[^"]+",\s*self,\s*"(_\w+)"/g) {
        push @connect_bad, [$path, $1] unless $owner{$1};
    }
}
for my $bad (sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] } @connect_bad) {
    report('ERROR', "connect target '$bad->[1]' not defined (in $bad->[0])");
}
print "  ok  every connect target exists on its owner\n" unless @connect_bad;

# --- 3) orphan thin shells ---
print "== 3. orphan thin shells (defined, never referenced)\n";
my $all_text = join('', values %SRC);
$all_text .= read_file($_) for grep { /\.(?:tscn|gd)$/ } @ALL;
my @orphan;
my %seen_shell;
for my $name ($game_src =~ /(?m)^func (_\w+)\(/g) {
    next if $seen_shell{$name}++;
    my $count = () = $all_text =~ /\Q$name\E/g;
    push @orphan, $name if $count <= 1;
}
if (@orphan) {
    report('WARN', "orphan shell $_") for sort @orphan;
} else {
    print "  ok  no orphan shells\n";
}

# --- 3.5) orphan member vars ---
print "== 3.5. orphan member vars (declared in game.gd, never referenced)\n";
my $others = '';
for my $path (@SCRIPTS) {
    next if $path =~ /game\.gd$/;
    $others .= $SRC{$path};
}
$others .= read_file($_) for @TESTS, @SCENES;
my @orphan_vars;
my %seen_var;
for my $name ($game_src =~ /(?m)^var (\w+)/g) {
    next if $seen_var{$name}++;
    my $external = () = $others =~ /\b\Q$name\E\b/g;
    my $internal = () = $game_src =~ /\b\Q$name\E\b/g;
    push @orphan_vars, $name if $external == 0 && $internal <= 1;
}
if (@orphan_vars) {
    report('WARN', "orphan member var $_") for sort @orphan_vars;
} else {
    print "  ok  no orphan member vars\n";
}

# --- 4) Godot 4 syntax leakage ---
print "== 4. Godot 4 syntax leakage\n";
my @g4 = (
    [ qr/\bALIGNMENT_CENTER\b/, 'BoxContainer.ALIGN_CENTER is the Godot 3 name' ],
    [ qr/\.offset_top\s*=/,     'Godot 3 Control uses margin_top' ],
    [ qr/\.offset_bottom\s*=/,  'Godot 3 Control uses margin_bottom' ],
);
my @leaks;
for my $path (@SCRIPTS) {
    for my $pat (@g4) {
        while ($SRC{$path} =~ /$pat->[0]/g) {
            my $line = count_lines($SRC{$path}, $-[0]);
            push @leaks, "$path:$line  $pat->[1]";
        }
    }
}
report('ERROR', $_) for @leaks;
print "  ok  no Godot 4 syntax leakage\n" unless @leaks;

# --- 5) cross-module calls resolve ---
print "== 5. cross-module calls resolve\n";
my %module_funcs;
for my $path (@SCRIPTS, @TESTS) {
    my $src = read_file($path);
    $module_funcs{$path} = { map { $_ => 1 } $src =~ /(?m)^(?:static )?func (\w+)\(/g };
}
my %game_preloads;
while ($game_src =~ /(?m)^const (\w+) = preload\("res:\/\/([\w.\/]+)"\)/g) {
    $game_preloads{$1} = $2;
}
my %dangling;
for my $path (@SCRIPTS, @TESTS) {
    my $src = read_file($path);
    # Collect matches before scanning: a nested /g while on the same variable
    # resets pos() when it exhausts, which would loop the outer scan forever.
    my @file_preloads;
    while ($src =~ /(?m)^const (\w+) = preload\("res:\/\/((?:scripts|tests)\/[\w.\/]+)"\)/g) {
        push @file_preloads, [ $1, $2 ];
    }
    for my $pair (@file_preloads) {
        my ($alias, $target) = @$pair;
        next unless $module_funcs{$target};
        while ($src =~ /\b\Q$alias\E\.(\w+)\s*\(/g) {
            my $fn = $1;
            next if $fn eq 'new' || $fn eq 'instance';
            my $line = count_lines($src, $-[0]);
            $dangling{"$path:$line  $alias.$fn() missing in $target"} = 1
                unless $module_funcs{$target}{$fn};
        }
    }
    next if $path =~ /game\.gd$/;
    for my $alias (sort keys %game_preloads) {
        my $target = $game_preloads{$alias};
        next unless $module_funcs{$target};
        while ($src =~ /\bgame\.\Q$alias\E\.(\w+)\s*\(/g) {
            my $fn = $1;
            next if $fn eq 'new' || $fn eq 'instance';
            my $line = count_lines($src, $-[0]);
            $dangling{"$path:$line  game.$alias.$fn() missing in $target"} = 1
                unless $module_funcs{$target}{$fn};
        }
    }
}
report('ERROR', "dangling cross-module call: $_") for sort keys %dangling;
print "  ok  every cross-module call resolves\n" unless %dangling;

# --- 6) scale gates ---
print "== 6. scale gates (function/file length)\n";
my $FUNC_LEN_WARN = 35;
my $FUNC_LEN_MAX  = 45;
my $FILE_LEN_WARN = 650;
my $FILE_LEN_MAX  = 800;
my %FILE_LEN_EXEMPT = ( 'scripts/game.gd' => 1 );
my %FUNC_LEN_RATCHET;    # mirror python FUNC_LEN_RATCHET (currently empty)
my $gate_bad = 0;
for my $path (@SCRIPTS) {
    my @lines = split /\n/, read_file($path);
    if (!defined $FILE_LEN_EXEMPT{$path}) {
        if (@lines > $FILE_LEN_MAX) {
            report('ERROR', "$path is " . scalar(@lines) . " lines (max $FILE_LEN_MAX)");
            $gate_bad++;
        } elsif (@lines > $FILE_LEN_WARN) {
            report('WARN', "$path is " . scalar(@lines) . " lines");
        }
    }
    my ($cur, $cur_start, $cur_indent, $body) = (undef, 0, 0, 0);
    my $close = sub {
        return unless defined $cur;
        my $key = "${path}::$cur";
        if (exists $FUNC_LEN_RATCHET{$key}) {
            if ($body > $FUNC_LEN_RATCHET{$key}) {
                report('ERROR', "$path:$cur_start $cur spans $body lines (ratchet $FUNC_LEN_RATCHET{$key}; split it, never grow it)");
                $gate_bad++;
            }
        } elsif ($body > $FUNC_LEN_MAX) {
            report('ERROR', "$path:$cur_start $cur spans $body lines (max $FUNC_LEN_MAX)");
            $gate_bad++;
        } elsif ($body > $FUNC_LEN_WARN) {
            report('WARN', "$cur in $path spans $body lines");
        }
        $cur = undef;
    };
    for my $i (0 .. $#lines) {
        my $ln = $lines[$i];
        if ($ln =~ /^(\s*)(?:static )?func\s+\w+\(/) {
            $close->();
            my $stripped = $ln;
            $stripped =~ s/^\s+|\s+$//g;
            my ($name) = $stripped =~ /^([^\(]+?)\s*\(/;
            my ($fname) = $name =~ /(\S+)$/;
            ($cur, $cur_start, $cur_indent, $body) = ($fname, $i + 1, length($1), 0);
        } elsif (defined $cur) {
            my $trimmed = $ln;
            $trimmed =~ s/^\s+|\s+$//g;
            next if $trimmed eq '' || $trimmed =~ /^#/;
            my $indent = length($ln) - length($ln);
            $ln =~ /^(\s*)/;
            $indent = length($1);
            if ($indent <= $cur_indent) { $close->(); }
            else { $body++; }
        }
    }
    $close->();
}
print "  ok  all functions <=$FUNC_LEN_WARN lines and files <=$FILE_LEN_WARN lines\n" if $gate_bad == 0;

# --- 7) top-level hygiene ---
print "== 7. top-level hygiene\n";
my @ok_starters = ('extends', 'const ', 'static func ', 'func ', 'var ', 'signal ', 'class ', 'class_name', 'tool', '@', ']', '}');
my $soup = 0;
for my $path (@SCRIPTS) {
    my @lines = split /\n/, read_file($path);
    for my $i (0 .. $#lines) {
        my $ln = $lines[$i];
        next if $ln eq '' || $ln =~ /^[\t #]/ || $ln !~ /\S/;
        my $hit = 0;
        for my $s (@ok_starters) { if (index($ln, $s) == 0) { $hit = 1; last; } }
        unless ($hit) {
            my $stmt = substr($ln, 0, 60);
            $stmt =~ s/^\s+|\s+$//g;
            report('ERROR', "$path:" . ($i + 1) . " statement outside a body: $stmt");
            $soup++;
        }
    }
}
print "  ok  no stray top-level statements\n" if $soup == 0;

# --- 8) test exit honesty ---
print "== 8. test exit honesty (quit(1) is never overridden by quit(0))\n";
my $liars = 0;
for my $path (@TESTS) {
    my @lines = split /\n/, read_file($path);
    my @quits = grep { /^\s*quit\(/ } @lines;
    next unless grep { /\bquit\(1\)/ } @lines;
    if (@quits && $quits[-1] =~ /^\s*quit\(0\)\s*$/) {
        report('ERROR', "$path can fail (quit(1)) but its last quit is a bare quit(0) that overwrites the exit code");
        $liars++;
    }
}
print "  ok  every failing test keeps its failure exit code\n" if $liars == 0;

if (@errors) {
    print "\nshell_audit(port): " . scalar(@errors) . " ERROR(S)\n";
    exit 1;
}
print "\nshell_audit(port): clean\n";
exit 0;
