#!/usr/bin/perl
use File::Basename; use Cwd qw(abs_path);
# Regenerate godot/scripts/modes/campaign_levels.gd from the LIVE table in
# godot/data/campaign.json, so the headless mirror can never drift again.
use strict; use warnings;
use JSON::PP;

my $ROOT = File::Spec->catdir(dirname(abs_path($0)), "..");
open my $fh, '<:raw', "$ROOT/godot/data/campaign.json" or die $!;
local $/; my $raw = <$fh>; close $fh;
my $data = decode_json($raw);
my @levels = @{$data->{levels}};
die "expected 15 levels, got " . scalar(@levels) unless @levels == 15;

my @keys = qw(id name mode description rows cols kinds time_limit
	time_bonus_multiplier score_multiplier effect_intensity);

sub fmt {
	my ($v) = @_;
	if (!defined $v) { die "missing field value"; }
	if ($v =~ /^-?\d+$/) { return $v; }          # int stays int (matches JSON text)
	if ($v =~ /^-?\d*\.\d+$/) { return $v; }      # float literal as-is
	return '"' . $v . '"';                        # strings
}

my $out = <<"HEADER";
extends Reference

# Campaign level table extracted from game.gd: pure data plus one accessor,
# so the progression can be asserted headless (tests/campaign_levels_test.gd).
# This is a generated MIRROR of the live table in data/campaign.json -
# difficulty_curve_test's mirror gate fails CI if the two drift apart.
# Regenerate with: perl tools/gen_campaign_mirror.pl (do not hand-edit
# numbers; CI gates the mirror against the live table).

const LEVELS = [
HEADER

for my $i (0 .. $#levels) {
	my $lv = $levels[$i];
	$out .= "\t{\n";
	for my $k (@keys) {
		die "level $i missing key $k" unless exists $lv->{$k};
		$out .= "\t\t\"$k\": " . fmt($lv->{$k}) . ",\n";
	}
	$out .= "\t}" . ($i < $#levels ? "," : "") . "\n";
}
$out .= <<'FOOTER';
]

static func default_campaign_levels() -> Array:
	return LEVELS.duplicate(true)
FOOTER

open my $ofh, '>:raw', "$ROOT/godot/scripts/modes/campaign_levels.gd" or die $!;
print $ofh $out; close $ofh;
print "campaign_levels.gd regenerated with " . scalar(@levels) . " levels\n";
