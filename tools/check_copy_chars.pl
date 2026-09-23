#!/usr/bin/perl
# 本地字体子集字符覆盖对拍（无 python 开发机用，与 godot/tools/subset_fonts.py 互注同步）。
# 取材对齐 subset_fonts.py（扫描 .gd/.json/.godot），但按「整文件」收集非 ASCII 字符——
# 比 python 版的字面量扫描更严格：这里命中即保证字形已在子集里；这里不命中的一律改写文案，
# 宁可保守也不上线豆腐块。python 版重新生成子集后，以 python 版为准。
#
# 用法： perl tools/check_copy_chars.pl <godot_dir> <待检文案文件>
#   文案文件为 UTF-8，每行一条（空行与 # 开头的注释行忽略）。Windows 下 argv 传
#   中文会被本地代码页搅碎，所以走文件不走参数。
# 退出码：0 = 全覆盖；1 = 有缺字（逐个列出 字符 U+码点）。

use strict;
use warnings;
use File::Find;

my $godot_dir = shift @ARGV or die "usage: check_copy_chars.pl <godot_dir> <strings-file>\n";
my $strings_file = shift @ARGV or die "usage: check_copy_chars.pl <godot_dir> <strings-file>\n";
die "no such dir: $godot_dir\n" unless -d $godot_dir;
die "no such file: $strings_file\n" unless -f $strings_file;

my @texts;
open my $sf, '<:utf8', $strings_file or die "cannot read $strings_file: $!\n";
while (my $line = <$sf>) {
	$line =~ s/[\r\n]+$//;
	next if $line eq '' or $line =~ /^#/;
	push @texts, $line;
}
close $sf;
die "no strings to check\n" unless @texts;

my %have;
my %ext = map { $_ => 1 } qw(.gd .json .godot);

binmode(STDOUT, ':encoding(UTF-8)');

# no_chdir：File::Find 默认 chdir 进子目录，会让相对路径的 open 失效（只在
# 顶层目录碰巧可读，池子小得像缺字泛滥——这里的坑踩过一次）。
find({ wanted => sub {
	return unless -f $_;
	my ($ext) = $File::Find::name =~ /(\.[^.]+)$/;
	return unless $ext && $ext{$ext};
	open my $fh, '<:utf8', $File::Find::name or return;
	while (my $line = <$fh>) {
		for my $ch (split //, $line) {
			$have{$ch} = 1 if ord($ch) > 127;
		}
	}
	close $fh;
}, no_chdir => 1 }, $godot_dir);

my $missing = 0;
for my $text (@texts) {
	for my $ch (split //, $text) {
		next if ord($ch) <= 127;    # ASCII 走主字体，恒有字形
		next if $have{$ch};
		printf "MISSING '%s' U+%04X in: %s\n", $ch, ord($ch), $text;
		$missing++;
	}
}
if ($missing) {
	print "NOT COVERED: $missing char(s)\n";
	exit 1;
}
print "ALL COVERED (subset pool: " . scalar(keys %have) . " non-ASCII chars)\n";
exit 0;
