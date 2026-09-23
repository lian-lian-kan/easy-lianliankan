#!/usr/bin/perl
# 函数级测试覆盖对账（无 python 开发机用的启发式审计，非行覆盖率）：
#   1) 扫 godot/scripts/**/*.gd 的全部 func/static func 名（按模块归组）；
#   2) 扫 godot/tests/**/*.gd 得到「被引用名」集合——直接调用、假体方法、
#      connect 字符串、witness 断言里出现过的名字都算被测面；
#   3) 输出每个模块的未引用函数清单。
# 注意：这是必要条件审计（名字没出现过 = 肯定没测），不是充分条件（出现过 ≠ 断言对了）。
# game.gd（编排根，全部经探针）与 *_ui/视图构建类由场景探针覆盖，单独归类，不进硬缺口。
#
# 用法： perl tools/func_coverage_audit.pl   （仓库根运行）
# 退出码：0 = 纯逻辑域无缺口；1 = 有未引用函数。

use strict;
use warnings;
use File::Find;

binmode(STDOUT, ':encoding(UTF-8)');

my %funcs;    # module => { name => 1 }
my %referenced;

my %ext_gd = (".gd" => 1);

find({
    wanted => sub {
        return unless -f $_;
        return unless /\.gd$/;
        my $path = $File::Find::name;
        if ($path =~ /[\\\/]scripts[\\\/]/) {
            (my $rel = $path) =~ s/^.*[\\\/]scripts[\\\/]//;
            $rel =~ s/\.gd$//;
            open my $fh, '<:utf8', $path or return;
            while (my $line = <$fh>) {
                if ($line =~ /^\s*(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)/) {
                    $funcs{$rel}{$1} = 1;
                }
            }
            close $fh;
        } elsif ($path =~ /[\\\/]tests[\\\/]/) {
            open my $fh, '<:utf8', $path or return;
            while (my $line = <$fh>) {
                while ($line =~ /([A-Za-z_][A-Za-z0-9_]*)/g) {
                    $referenced{$1} = 1;
                }
            }
            close $fh;
        }
    },
    no_chdir => 1,
}, "godot");

# 视图/编排/动态分发类：由场景探针覆盖（policy 见 docs/quality-report.md 已知边界）。
# interactions/* 的 on_press 等入口经 interaction_manager 动态分发（game_input_test
# 真实驱动 pair_select/memory_pick/power_target/drag_link），名字不静态出现在测试里；
# economy/page_router/ui_* 的构建与动线由 panels_probe/page_probe/startup_probe/
# start_screen_probe/power_ups_probe 真场景驱动并断言。
my %probe_covered = map { $_ => 1 } qw(
    game board_view path_overlay ui_hud ui_panels home_screen stats_hud fx_layer
    start_screen page_router page_ui page_records page_events ui_preferences
    level_editor_ui interaction_manager audio_manager web_http_bridge migration_sync
    drag_link memory_pick pair_select power_target economy
);

my $gaps = 0;
for my $module (sort keys %funcs) {
    (my $base = $module) =~ s/^.*\///;
    my @uncovered;
    for my $fn (sort keys %{$funcs{$module}}) {
        next if $referenced{$fn};
        next if $fn =~ /^_/;   # 私有助手：经公共入口覆盖，不单列
        push @uncovered, $fn;
    }
    next if !@uncovered;
    my $tag = ($probe_covered{$module} || $probe_covered{$base}) ? "probe-covered" : "GAP";
    print "[$tag] $module: @uncovered\n";
    $gaps++ unless ($probe_covered{$module} || $probe_covered{$base});
}

my $total = 0;
$total += scalar keys %{$funcs{$_}} for keys %funcs;
print "modules=" . scalar(keys %funcs) . " funcs=$total unreferenced_gaps=$gaps\n";
exit($gaps ? 1 : 0);
