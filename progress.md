Original prompt: 哎，继续完善我们的 GoDota 框架开发的 连连看游戏。

## 2026-03-20 (current turn)
- Context: Continue improving the Godot-based Lianliankan after fixing gray-screen startup crash.
- Working goal: Add quality-of-life controls and interaction polish (pause/resume + keyboard shortcuts + fullscreen toggle) with end-to-end validation.
- Notes:
  - Must keep stage-state transitions stable (playing/cleared/failed/completed).
  - Must re-run godot:check, build, and browser automation after edits.
- Implemented:
  - Added stage pause status and pause/resume flow (button + `P` shortcut).
  - Added keyboard shortcuts: `H` hint, `A` auto, `S` shuffle, `R` reset, `F` fullscreen, `Esc` exit fullscreen.
  - Added paused status chip style and control-button state sync.
  - Added per-level quick hint text showing hotkeys on level start.

## 2026-03-21 (current turn)
- Context: Continue H5 Lianliankan development and quantify current completion.
- Working goal: Improve H5 board presentation on wide screens (remove left-leaning board + increase board usage) and verify with export/build/browser checks.
- Implemented:
  - Updated `godot/scripts/game.gd` to introduce a centered board container (`CenterContainer`) and place `board_grid` inside it.
  - Reworked responsive layout logic:
    - Increased board vertical allocation (`_update_layout_for_screen_size`) for mobile and desktop.
    - Removed fixed offset anchoring from board grid and kept spacing adaptive.
  - Reworked tile-size calculation (`_update_tile_sizes`):
    - Added minimum available area guards.
    - Raised tile clamp ranges to mobile 28-72 and desktop 34-110 for better H5 visual occupancy.
- Validation:
  - `npm run godot:check` passed.
  - `npm run godot:export` passed.
  - `npm run build` passed (includes export + tsc + vite build).
  - `npm run test -- --run` passed (48 tests passed; known stderr warnings remain test-expected).
  - Playwright game loop captures:
    - Baseline: `output/web-game-baseline/shot-0.png`, `shot-1.png`
    - After layout export: `output/web-game-after-export/shot-0.png`, `shot-1.png`
    - Result: board is centered and more prominent in H5 viewport after export.
- TODO / Next suggestions:
  - Add player progression persistence for H5 (current level/high score/best combo) in `user://` save.
  - Add portrait-mode specific layout profile (compact stat cards + larger board height ratio).
  - Consider optional “auto-zoom board” toggle for low-width devices.

## 2026-03-21 (current turn, Superpulse continuation)
- Context: User requested to continue full-system Lianliankan development based on existing direction.
- Working goal: Land persistent campaign progression in Godot Web (current checkpoint level + best total score + best combo), and verify end-to-end.
- Implemented:
  - Added new persistence logic module `godot/scripts/progression.gd`:
    - `normalize_progress` for robust clamp and compatibility handling.
    - `apply_update` for controlled progress/state patching.
    - `same_progress` for change detection before disk writes.
  - Added headless regression script `godot/tests/progression_test.gd` covering:
    - default state,
    - clamp behavior on invalid values,
    - non-regression for best score/combo records.
  - Integrated persistence into `godot/scripts/game.gd`:
    - load/save path: `user://campaign_progress.json`.
    - startup resume from saved `current_level_index`.
    - automatic updates on level start, combo scoring, level clear, and time-up failure.
    - unlock progression update after stage clear.
  - Added UI visibility for persisted records:
    - new stat cards: `历史高分` and `历史连击`.
    - subtitle now shows unlocked progress (`已解锁x/y`).
- Validation:
  - Red step (before implementation): `godot --headless --path godot --script res://tests/progression_test.gd` failed because `res://scripts/progression.gd` was missing.
  - Green step (after implementation): same command passed.
  - `npm run godot:check` passed.
  - `npm run build` passed (includes Godot export + TypeScript build + Vite build).
  - `npm run test -- --run` passed (48 tests, existing stderr warnings remain baseline).
- TODO / Next suggestions:
  - Add an explicit level-select UI gated by `highest_unlocked_level_index`.
  - Add a one-click “clear local progress” control for QA/debugging.
  - Add a portrait-focused compact stats row to avoid subtitle overflow on narrow screens.

## 2026-03-21 (current turn, Superpulse continuation phase-2)
- Working goal: execute next planned phase continuously with three items:
  - level-select UI gated by unlock progress,
  - one-click local progress reset,
  - portrait-mode compact header/stat layout.
- TDD (red -> green):
  - Red: extended godot/tests/progression_test.gd to assert level unlock checks; initially failed with:
    - Invalid call. Nonexistent function 'is_level_unlocked' in base 'GDScript'.
  - Green: added is_level_unlocked in godot/scripts/progression.gd; test passed.
- Implemented:
  - godot/scripts/game.gd
    - Added progression controls:
      - level_select_option (关卡下拉)
      - jump_level_button (跳转关卡)
      - clear_progress_button (清除进度)
    - Added unlock-gated option population with disabled locked levels.
    - Added jump action to restart from selected unlocked level.
    - Added clear-progress action:
      - reset to default progression state,
      - persist to user://campaign_progress.json,
      - restart from level 1.
    - Added responsive compact behavior for mobile portrait:
      - tighter stat card sizes + reduced value/title font sizes,
      - smaller control button footprint,
      - portrait board area ratio increased,
      - description line hidden in portrait to reduce header crowding.
    - Added progression-aware level selector synchronization after state patch/update.
  - godot/scripts/progression.gd
    - Added is_level_unlocked(state, level_index, level_count).
- Validation:
  - godot --headless --path godot --script res://tests/progression_test.gd passed.
  - npm run godot:check passed.
  - npm run build passed.
  - npm run test -- --run passed (48 tests).
  - Runtime screenshots:
    - Desktop: screenshot.png
    - Mobile portrait: output/mobile-portrait.png
    - Observation: level-select/reset controls render correctly in both; portrait layout is compact and functional.
- Next suggestions:
  - Add level-select quick hotkeys ([ / ] switch, Enter jump).
  - Add progress checksum/version migration to keep future save-compatibility explicit.
  - Add a tiny onboarding tip for first-time users explaining unlock rules.

## 2026-03-21 (current turn, Superpulse continuation phase-3)
- Working goal: continue without pause by adding level-select hotkeys for faster progression workflow.
- TDD (red -> green):
  - Red: added unlock-navigation assertions in `godot/tests/progression_test.gd` for `find_next_unlocked`; failed with missing function error.
  - Green: implemented `find_next_unlocked` in `godot/scripts/progression.gd`; test passed.
- Implemented:
  - `godot/scripts/progression.gd`
    - Added `find_next_unlocked(state, from_index, step, level_count)` for cyclic unlocked-level navigation.
  - `godot/scripts/game.gd`
    - Added hotkeys:
      - `[` => previous unlocked level in selector.
      - `]` => next unlocked level in selector.
      - `Enter` / `Numpad Enter` => jump to selected unlocked level.
    - Added `_cycle_level_selection(step)` helper and expanded in-game hint text with new shortcuts.
- Validation:
  - `godot --headless --path godot --script res://tests/progression_test.gd` passed.
  - `npm run godot:check` passed.
  - `npm run build` passed.
  - `npm run test -- --run` passed (48 tests).
- Next suggestions:
  - Add focused Godot headless integration script for hotkey flow (selector index change + jump action assertion).
  - Add lightweight visual highlight when selector hotkey changes target level.

## 2026-03-22 (current turn, Teams mode - phase 14)
- Working goal: Add combo-based sound effects.
- Implemented:
  - Extended `godot/scripts/audio_manager.gd`:
    - Added `play_eliminate_combo(combo)` function with tiered sound effects
    - Base (0-2): Standard C5+E5 chord
    - 3+ combo: D5+F#5 (higher pitch)
    - 5+ combo: E5+G#5+B5 (three-note chord)
    - 7+ combo: G5+B5+D6 (higher three-note)
    - 10+ combo: C6+E6+G6+C7 arpeggio (four-note cascade)
  - Modified `godot/scripts/game.gd`:
    - Changed `AudioManager.play_eliminate()` to `AudioManager.play_eliminate_combo(combo)`
  - Each tier has progressively higher pitch and complexity
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 13)
- Working goal: Enhance pause menu with dedicated panel.
- Implemented:
  - Extended `godot/scripts/game.gd`:
    - Added `pause_panel` variable
    - Created `_build_pause_panel()` to build pause menu UI
    - Added `_show_pause_panel()` and `_hide_pause_panel()` functions
    - Added `_on_restart_current_level()` and `_on_back_to_first_level()` handlers
    - Modified `_pause_stage()` and `_resume_stage()` to use new panel
  - Pause menu features:
    - Shows current level name
    - "▶️ 继续游戏 (P)" button
    - "🔄 重新开始" button - restart current level
    - "🏠 返回第1关" button - go back to level 1
    - Glass morphism styling matching other panels
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 12)
- Working goal: Add elimination particle effects based on combo level.
- Implemented:
  - Extended `godot/scripts/game.gd`:
    - Modified `_play_eliminate_effects()` to use combo-based particle colors and amounts
    - Added `_spawn_combo_particle_burst()` for enhanced particle effects
  - Particle effect tiers:
    - Base (0-2 combo): White particles, 6-10 count
    - 3+ combo: Green particles, 12 count, ✦ shape
    - 5+ combo: Blue particles, 18 count, ★ shape
    - 7+ combo: Purple particles, 24 count, ◆ shape
    - 10+ combo: Gold particles, 30 count, all shapes with rotation
  - Features:
    - Particles fly farther with higher combos
    - Particle size increases with combo level
    - Particles rotate during flight for high combos
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 11)
- Working goal: Add achievements view panel.
- Implemented:
  - Extended `godot/scripts/game.gd`:
    - Added `achievements_panel` variable
    - Added "🏆 成就" button next to settings button
    - Created `_build_achievements_panel()` to build achievements UI
    - Created `_create_achievement_item()` to display each achievement with icon, name, description
    - Added `_on_achievements_pressed()` and `_on_achievements_close()` handlers
  - Features:
    - Shows all 6 achievements in a scrollable list
    - Unlocked achievements show 🏆 with green text
    - Locked achievements show 🔒 with gray text
    - Panel pauses game when open, resumes when closed
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 10)
- Working goal: Extend levels from 10 to 15.
- Implemented:
  - Extended `godot/data/campaign.json`:
    - Level 11: 极限挑战 (rush, 14x10, 150s)
    - Level 12: 记忆大师 (classic, 12x12, 180s)
    - Level 13: 闪电战 (rush, 10x10, 90s)
    - Level 14: 连击风暴 (combo, 12x10, 160s)
    - Level 15: 终极试炼 (endurance, 14x12, 200s)
  - Each new level has increasing difficulty and score multipliers
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 9)
- Working goal: Add leaderboard system for level best times.
- Implemented:
  - Extended `godot/scripts/progression.gd`:
    - Added `level_best_times` dictionary to store best times per level
    - Added time update logic in `apply_update()` function
  - Extended `godot/scripts/game.gd`:
    - Added `_format_time_seconds()` for time display with milliseconds
    - Modified `_check_achievements_on_clear()` to record and notify new records
    - Modified `_populate_level_select_options()` to show best times in level selector
  - Features:
    - Records completion time when level cleared
    - Shows "🎉 新纪录！" notification when beating previous best
    - Displays best time (⏱️MM:SS.MS) in level dropdown
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 8)
- Working goal: Add new icon themes for visual variety.
- Implemented:
  - Extended `godot/data/icon_sets.json`:
    - Added "十二星座" theme: ♈♉♊♋♌♍♎♏♐♑♒♓🔯✡️⭐ with constellation colors
    - Added "天气预报" theme: ☀️🌤️⛅🌥️☁️🌦️🌧️⛈️🌩️🌨️❄️🌬️💨🌫️🌈 with weather-appropriate colors
  - Total themes now: 14 (fruit, car, people, cosmetic, animal, food, sport, nature, anime, maruko, sea, space, zodiac, weather)
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 7)
- Working goal: Add power-ups UI display and upgrade combo system.
- Implemented:
  - Extended `godot/scripts/game.gd`:
    - Added `power_ups_container` and `power_up_labels` for displaying power-ups
    - Created `_create_power_up_label()` to build UI for each power-up (icon + count + shortcut)
    - Created `_update_power_ups_display()` to refresh power-up counts with visual feedback
    - Modified `_apply_combo_gain()` with new formula: base 1.5x, +0.5x per combo level
      - 3 combo = 2.0x, 5 combo = 3.5x, 10 combo = 6.0x
    - Enhanced `_show_combo_burst()` with dynamic colors and font sizes based on combo level:
      - 3+ combo: Green, 20px
      - 5+ combo: Blue, 22px
      - 7+ combo: Purple, 24px
      - 10+ combo: Red, 28px
- Power-ups UI shows: ⏱️[1] 🎯[2] 🔄[3] with counts and keyboard shortcuts
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 6)
- Working goal: Optimize gameplay with power-up system.
- Implemented:
  - Extended `godot/scripts/game.gd`:
    - Added power-ups system with 3 types: time_freeze, auto_match, reshuffle
    - Added `_init_power_ups()` to grant power-ups based on level difficulty
    - Added `_use_power_up()`, `_activate_time_freeze()`, `_activate_auto_match()`, `_activate_reshuffle()`
    - Modified `_on_second_tick()` to support time freeze mechanic
    - Added keyboard shortcuts: 1 (time freeze), 2 (auto match), 3 (reshuffle)
    - Added `time_freeze_timer` for managing freeze duration (5 seconds)
  - Power-up distribution logic:
    - All levels: 1 time_freeze + 1 reshuffle
    - Level 3+: +1 auto_match
    - Level 5+: +1 time_freeze
    - Rush mode: +1 time_freeze
    - Endurance mode: +1 reshuffle
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 5)
- Working goal: Add volume control UI with settings panel.
- Implemented:
  - Extended `godot/scripts/game.gd`:
    - Added `settings_button` and `settings_panel` variables.
    - Created `_build_settings_panel()` to construct settings UI.
    - Added `_create_volume_row()` and `_create_toggle_row()` helper functions.
    - Added `_on_settings_pressed()`, `_on_settings_close()` handlers.
    - Added `_on_master_volume_changed()`, `_on_effects_toggled()`, `_on_music_toggled()`, `_on_mute_toggled()` callbacks.
  - Settings panel features:
    - Master volume slider (0-100%)
    - Sound effects toggle
    - Background music toggle
    - Mute all toggle
    - Glass morphism styling matching other UI
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 4)
- Working goal: Add achievement system with 6 unlockable achievements.
- Implemented:
  - Extended `godot/scripts/progression.gd`:
    - Added `ACHIEVEMENTS` constant with 6 achievement definitions.
    - Extended progress data structure with `achievements` array.
    - Added `has_achievement()`, `unlock_achievement()`, `get_achievement_info()`, `get_unlocked_achievements()`, `get_all_achievements()` functions.
  - Extended `godot/scripts/game.gd`:
    - Added achievement tracking variables: `level_start_time`, `level_hints_used`, `level_auto_used`.
    - Track hint/auto usage in `_on_hint_pressed()` and `_on_auto_pressed()`.
    - Added `_check_achievements_on_clear()` to detect all achievements on level clear.
    - Added `_show_achievement_notification()` to display unlock toast with animation.
- Achievement list:
  1. first_clear: Complete level 1
  2. combo_novice: Reach 3+ combo
  3. combo_master: Reach 10+ combo
  4. speed_star: Clear level in 30 seconds
  5. perfect_clear: No hints/auto used
  6. completionist: All levels cleared
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 3)
- Working goal: Enhance audio system with background music and failure sound effect.
- Implemented:
  - Extended `godot/scripts/audio_manager.gd`:
    - Added BGM (background music) with procedural melody generation.
    - Added `BGM_MELODY` constant with cheerful 14-note loop sequence.
    - Added `start_bgm()`, `stop_bgm()`, `_play_next_bgm_note()` functions.
    - Added `play_fail()` sound effect with descending sad tones.
    - Added `set_music_enabled()` for music toggle control.
  - Integrated into `godot/scripts/game.gd`:
    - Call `AudioManager.start_bgm()` in `_ready()` to begin background music.
    - Call `AudioManager.play_fail()` when stage fails (time runs out).
- Audio capabilities now complete:
  - SFX: eliminate, combo, error, hint, win, shuffle, button, time_warning, fail
  - BGM: Procedural looping melody
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 2)
- Working goal: Add first-time user onboarding tutorial panel.
- Implemented:
  - Added `onboarding_panel` UI component with glass morphism styling.
  - Added `ONBOARDING_SEEN_KEY` for tracking onboarding completion state.
  - Created `_build_onboarding_panel()` to construct the tutorial UI with:
    - Welcome title with game icon
    - Gameplay explanation (connect matching icons, max 2 turns)
    - Unlock rules explanation (complete level to unlock next)
    - Hotkey reference (H/A/S/R/P and [ ] brackets)
    - "Got it" dismiss button
  - Added `_show_onboarding_if_needed()` to detect first launch and show panel.
  - Added `_on_onboarding_dismissed()` to save state and resume game timer.
- Behavior:
  - Panel auto-shows on first launch (when no save or onboarding_seen is false).
  - Game timer pauses while onboarding is visible.
  - State persists to save file; clearing progress resets it.
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.

## 2026-03-22 (current turn, Teams mode - phase 1)
- Working goal: Use Agent Teams mode to continue development; first task: add visual highlight feedback for level selector.
- Implemented:
  - Added `level_highlight_timer` timer for managing highlight duration.
  - Added highlight color constants (`LEVEL_HIGHLIGHT_COLOR` amber and `LEVEL_NORMAL_COLOR`).
  - Modified `_cycle_level_selection()` to call `_trigger_level_highlight()` after selection change.
  - Added `_trigger_level_highlight()` to apply amber modulate color to the OptionButton.
  - Added `_on_level_highlight_timeout()` to restore normal color after 0.4s.
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.
  - Feature works: when pressing `[` or `]` to cycle levels, the selector flashes amber briefly.
- Next suggestions:
  - Add new user onboarding tip explaining unlock rules.
  - Add progress checksum/version migration for save compatibility.
  - Evaluate canvas stretch policy for mobile scaling if needed.


- Working goal: keep continuous iteration by improving portrait board readability after seeing runtime capture.
- Implemented:
  - Updated portrait tile sizing strategy in `godot/scripts/game.gd`:
    - portrait-specific lower padding in `_update_tile_sizes`.
    - portrait-specific tile clamp range increased to 34-86.
  - Re-exported and rebuilt web bundle.
- Validation:
  - `npm run godot:check` passed.
  - `npm run build` passed.
  - Runtime portrait recapture: `output/mobile-portrait-v2.png`.
- Observation:
  - Board readability improved, but final mobile scale behavior still appears constrained by Godot Web canvas resize policy (`canvasResizePolicy`) rather than tile clamp alone.
- Next suggestions:
  - If further mobile upscaling is required, evaluate export-side canvas/stretch policy tuning in Godot project settings and generated web bootstrap config.

## 2026-09-06 (mobile-rescue + CI 修复)
- Context: 项目评估发现 HEAD 源码是 Godot 3 / Godot 4 API 混合体，无法编译；此前导出产物(3/23)已过期且被 gitignore；CI(deploy.yml) 仍引用已删除的 npm 构建，5/30 起 Pages 部署持续失败，线上是 1 月旧版。
- Working goal: 让源码在 Godot 3.6.2 下可编译可导出、修复核心玩法 bug、恢复移动端优先的部署链路。
- 修复清单:
  - game.gd: 清除约 120 处 Godot 4 API（custom_minimum_size/is_empty/horizontal_alignment/Time.get_ticks_msec/offset_*/set_anchors_preset/Control.size 等），统一为 Godot 3 等价写法。
  - 关键玩法 bug: _find_any_hint 中寻路代码被错误缩进进 `if...continue` 分支内成为死代码 → 提示永远找不到可消对、每次消除后整盘强制重排。已修复并新增回归测试。
  - 运行时崩溃: Array.reverse() → invert()（消除一对即崩）；DynamicFontData 直接当字体用 → 正确包 DynamicFont + add_fallback(NotoColorEmoji)；show_percentage → percent_visible；button_pressed → pressed；rotation_degrees → rect_rotation。
  - 特效系统重写: 9 个特效函数中 Tween 从未 start()/节点永不释放/缩进断裂/参数错乱（残留 "interval skipped" 等半成品转换痕迹），新增 _make_fx_tween 工厂统一管理创建与释放，洗牌波/粒子/圆环/连击爆字全部恢复并支持 delay 分步动画。
  - 字号: 方块 emoji 字号随方块尺寸缩放（tile*0.52, clamp 14-44），手机上更易读；连击爆字/关卡横幅按等级字号。
  - export_presets.cfg: platform="Web" → "HTML5"（Godot 3 平台名）；挂载自定义 HTML shell（res://shell/mobile_shell.html），把原先只存在于 gitignore 产物里的移动端增强（DPR 封顶/视觉视口同步/加载看门狗/WebGL 上下文丢失恢复/safe-area）固化为仓库模板。
  - CLI: Godot 3 没有 --export-release（G4 参数，传入会被静默忽略并直接运行游戏），正确为 --export。
  - CI: deploy.yml 重写为纯 Godot 流水线（无 npm）：安装 3.6.2 headless + Web 模板（带缓存）→ headless 测试 → import → export → 发布 public/ 到 Pages。
  - server.js: 增加 gzip（wasm/pck 压缩率约 75%）+ query string 剥离 + Cache-Control；入口页 public/index.html 去掉 1.5s 人工延迟改为立即跳转。
- 新增测试: godot/tests/board_logic_test.gd（寻路 0/1/2 转弯/封死判定/hint/洗牌保持牌集/开局可解）。
- Validation:
  - board_logic_test / progression_test / path_overlay_input_passthrough_test 全部通过（Godot 3.6.2 headless）。
  - progression_test.gd 修复了 G4 的 `Variant` 类型注解（此前从未在 G3 下运行过）。
  - Web 导出产物见 public/godot/（本 worktree）。
- Next suggestions:
  - 移动端真机验证（iOS Safari 内存上限、低性能设备帧率）。
  - 主题切换/商店/体力等管理器有 UI 无入口（coins/energy/daily_reward/shop/leaderboard 已实现但 game.gd 未接入），考虑按休闲定位取舍。
  - pck 体积 25MB：字体 26MB 占大头，可评估子集化 NotoSansSC（只打包常用汉字+emoji 图标改用图片图集）。

## 2026-09-06 (字体子集化减体积)
- Context: pck 27.3MB 中约 27MB 是全量字体（NotoSansSC 16.4MB + NotoColorEmoji 10.7MB），手机端首次加载慢；而游戏实际只渲染 692 个不同字符（376 汉字 + 216 emoji 区符号 + 127 拉丁）。
- 方案: 新增 godot/tools/subset_fonts.py（fontTools/pyftsubset），扫描 godot 下全部 .gd/.json/project.godot 提取实际字符集生成两个子集字体：
  - NotoSansSC-Regular.ttf: 16.4MB → 0.22MB（覆盖全部源字符 + ASCII + CJK 标点 + 全角 + 符号区块兜底）。
  - NotoColorEmoji.ttf: 10.7MB → 2.26MB（icon_sets.json 全部 emoji + VS16/ZWJ/键帽连接符 + 肤色修饰符 + 区域指示符；CBDT/CBLC 彩色位图表保留并校验）。
  - 覆盖率断言：源字符若未被任一子集覆盖则脚本报错退出，防止上线豆腐块；符号区块字符同时进两个子集互为兜底。
  - 全量字体保留在 godot/fonts/full/（.gdignore 挡在 res:// 外不参与导入打包，gitignore 只提交 .gdignore 占位），加新文案/图标后重跑脚本即可再生成。
- Validation:
  - pck 27.3MB → 2.66MB（-90%）；本地 gzip 传输 2.4MB。
  - 3 个 headless 测试全绿；--export "Web" 无报错。
  - 390×844 移动视口浏览器实测：欢迎弹窗/顶栏/统计卡/提示文案（请先选择相同图案、自动消除 +15）/按钮/设置入口文字全部正常渲染无缺字，emoji 方块彩色显示，点击选中-配对-消除-计分-倒计时流程可玩。
- Next suggestions:
  - 阶段横幅「第X关 XXX」在竖屏布局下与倒计时卡片重叠，可考虑上移或缩短显示时长。
  - wasm 19.8MB（gzip 后 5.3MB）来自官方模板无法裁剪；如需进一步提速可评估 Godot 4.3+ 的单线程 wasm 体积优化或 CDN/Service Worker 预缓存。

## 2026-09-06 (玩法扩展：每日挑战 / 限时挑战 / 无尽模式)
- Context: data/game_modes.json 定义了限时挑战/无尽/盲盒三模式但 game.gd 零接入，也没有每日挑战；玩法只有 15 关战役。本次接入其中两个+新增每日挑战（H5 移动端优先）。
- 新增 special_modes.gd（纯逻辑、可 headless 测试）：
  - 每日挑战：按日期 seed（hash("lianliankan-daily-YYYY-MM-DD")）确定性生成棋盘，全网同一天同一副；rows 10-14 偶数、kinds 8-12、限时 150-180s；连胜按"昨日→+1、断签→1、同日重记→保持"结算。
  - 限时挑战：开局 60s，每次消除 +3s、连击≥5 狂热再加 1s 且得分 ×1.5（数据全读 game_modes.json 可调）。
  - 无尽模式：不限时（计时卡显示 ∞），每轮清盘后棋盘 +2 行列、kinds 递增（上限 16×14/20 种），总分跨轮累计。
  - 解锁：每日挑战始终开放；限时挑战第 5 关解锁、无尽第 8 关解锁（读配置）。
- game.gd 接线：新增 special session 架构（special_mode/special_level），_current_level()/计时/得分/结算全链路分支；特殊模式分数不写入战役最佳纪录（_patch_progress_state 过滤）；暂停面板新增「返回关卡模式」；进度行首位新增「🎮 玩法」入口 + 居中玩法面板（含各模式个人最佳）。
- progression 存档扩展：daily_challenge{last_date,streak,best_streak,best_score}、endless_best{round,score}、time_attack_best_score，含 normalize/apply_update/same_progress 与单测覆盖。
- 修 bug：弹窗 PRESET_CENTER 在内容尺寸变化后偏出屏幕（引导/设置/成就/暂停/玩法全部中招）→ 所有弹窗改挂全屏 CenterContainer 持有器自动居中。实测 390×844 引导弹窗与玩法面板完美居中。
- 修 bug：subset_fonts.py 自举时会把仓库里的子集字体当"全量源"（fonts/full/ 不随 git）→ 子集的子集缺新字（连胜/最佳/今日 等豆腐块）。已从 git 历史(d93a10c)恢复真全量字体，并加 <5MB 拒绝自举的防护。
- 字体重子集：692→720 字符（含 ∞/📅/🚪/🔥 等），pck 2.69→2.71MB。
- Validation: 4 个 headless 测试全绿（新增 special_modes_test 58 项检查：日期边界/连胜规则/种子确定性/无尽成长上限/解锁边界/存档往返）；headless 探针验证完整玩法链路（每日完成记录 streak=1 ✓ 无尽轮次推进+跨轮总分 ✓ 限时加时+狂热 ✓ 失败/退出 ✓ 特殊分数不污染战役纪录 ✓）；浏览器 390×844 实测玩法面板居中、新字符全部正常渲染、每日挑战副标题「每日挑战 · 9月6日 · 连胜0 · 最佳0 · 今日未完成」正确。
- Next suggestions:
  - 盲盒模式（memory）尚未实现；道具系统（放大镜/时光沙漏）仍只有数据。
  - 特殊模式可加专属成就（如连胜 7 天）。
  - CI 无头浏览器冒烟测试（GameShell 启动 + canvas 截图）可防渲染回归。

## 2026-09-06 (玩法扩展二：盲盒模式 + 道具补全 + 成就扩展)
- Context: game_modes.json 里最后一种未实现的玩法（盲盒/memory）落地，并接入数据里闲置的放大镜/时光沙漏道具，扩展特殊模式专属成就。
- 盲盒模式（解锁门槛：第 10 关）：
  - 开局全图预览 preview 秒（按战役进度分三档 5/4/3 秒），随后全部翻面成 ❓；
  - 点选翻开，配对成功即消除；配错两张短暂同显（face_up 0.5-1.0s 按档位）后自动翻回，期间锁输入；
  - 有限时（60 + 方块数×1.5 秒），提示在盲盒下改为"翻开一组"而非直接选中。
- 道具：放大镜 🔍（快捷键 4，高亮 3 组可消对，盲盒下同时翻开）第 6 关起每关 1 充能；时光沙漏 ⏳（快捷键 5，时间 +15s）第 8 关起每关 1 充能；限时挑战自带沙漏、盲盒自带放大镜；无尽模式使用沙漏会提示且不耗充能。
- 成就新增 4 个：盲盒初体验/七日之约（连胜7天）/无尽探索者（第5轮）/限时高手（单局1000分），在对应特殊模式结算点触发。
- 修严重 bug（影响已上线的 70c7e62）：特殊模式的结算分支没有判断棋盘是否清空，**每消一对就直接完结模式**（无尽/限时/每日全部中招）。原因是 _resolve_after_board_changed 的特殊分支短路了 remaining==0 判断。已修复并加部分消除回归探针（四模式 + 战役均验证消一对后仍在进行中）。
- 修潜在 bug：_path_to_overlay_points/_tile_center_in_effect_layer 调用 Control 不存在的 to_local()（那是 Node2D API），导致消除/提示连接线从未渲染过。改用 get_global_transform().affine_inverse() 做坐标映射。
- 字体：692→732 字符（新增 盲盒/翻面/放大镜/沙漏/❓/🎁/🔍/⏳ 等），pck 2.71→2.73MB。
- Validation: 4 个 headless 测试全绿（special_modes_test 扩到 73 项：档位选择/时间公式/解锁边界/记录与成就）；盲盒探针全链路（预览翻面/配对消除/错配锁 revealing/放大镜/结算/成就/退出）+ 四模式部分消除回归探针全绿；浏览器 390×844 实测新道具栏 5 槽渲染正常。
- Next suggestions:
  - 彩虹链/炸弹/超级洗牌三个道具仍只有数据；盲盒可加"连击翻倍"或"计时暂停"道具协同。
  - CI 可加无头浏览器冒烟截图防渲染回归。

## 2026-09-06 (界面美化：樱花粉主题)
- Context: 产品面向女生，旧配色是紫/蓝/石板灰工程师风。全量换成"樱花粉"：粉白底（#fff0f6）、玫瑰主色（#e64980/#f06ba8/#d6336c）、马卡龙统计卡（粉/紫/蜜桃/薄荷按卡片区分）、胶囊按钮（圆角 20）、面板圆角加大（棋盘 26/卡 16/瓷片 14）、进度条与连击条改粉、消除连线改玫瑰色（#ff6f9c）、提示连线改天蓝（#74c0fc）、盲盒翻面卡改粉（#ffc2d4）。
- 细节：标题改「连连看 🎀」；弹窗按钮（引导/玩法面板/关闭）统一玫瑰圆角白字（新增 _style_dialog_buttons 递归上妆，动态构建的玩法行单独处理）；落地页 public/index.html 渐变与按钮同步粉色化。
- 实现：颜色集中在 game.gd 的 StyleBox/字体覆盖处，全局映射 + 少量上下文替换；无结构性改动，逻辑零变更。
- Validation: 4 个 headless 测试全绿；浏览器 390×844 截图验收（背景/标题/瓷片/统计卡/按钮/弹窗/道具栏 5 槽）全部生效。
- Next suggestions:
  - 可加"轻音乐/音效开关"贴在设置里；统计卡圆角与投影可再细化。
  - 若要更进一步：引入圆体字体文件（如站酷快乐体）替代 NotoSansSC 显示层。

## 2026-09-06 (可爱化第二轮：炸弹/彩虹道具 + 圆体字体 + 樱花动效)
- Context: 继续"玩法迭代 + 面向女生的美观"双线。上轮遗留建议（圆体字体、数据闲置的炸弹/彩虹）本轮落地；设置里的音乐/音效开关经查已存在（主音量/音效/背景音乐/静音四项），无需重做。
- 新道具（快捷键 6/7，第 10/12 关起各 1 充能，特殊模式固定各 1）：
  - 炸弹 💣：武装后点任意瓷片，与同图案伙伴无视路径直接消除（画经棋盘顶的趣味连线）；再按一次收回并退还充能，只有真正炸掉才消耗。
  - 彩虹 🌈：武装后点两枚图案不同的瓷片直接消除（第一次点击复用选中高亮）；同样支持收回退还。
  - 武装期间全棋盘泛暖金（炸弹）/淡紫（彩虹）光晕提示，esc 外任何过关/开关卡会清除武装态。
- 字体：引入站酷快乐体 ZCOOL KuaiLe（OFL，全量 1.5MB，fonts/full/ 存档 + 许可证随仓库）作为显示层主字体，NotoSansSC 兜底生僻字（632/731 字符在快乐体内，99 个回落）、NotoColorEmoji 继续兜底 emoji。subset_fonts.py 改为按字体配置表驱动（守卫阈值按字体分档：快乐体 1MB，避免 <5MB 一刀切误伤）+ 快乐体 best-effort 覆盖率策略（核心 UI 字符硬校验，其余允许回落）。
- 动效：
  - 全局樱花飘落：背景层每 1.1s 生成 🌸/🌺/💗/✨ 花瓣（上限 12），7-13s 下落 + 横向摆动 + 旋转，鼠标穿透；
  - 过关撒花：_play_stage_clear_celebration 增加 22/36 个 🎉🎊🌸💖✨🌟 从顶部撒落（全通关量更大）；
  - 加载壳（shell/mobile_shell.html）粉化：黑底 → 粉紫渐变 + 纯 CSS 六瓣樱花飘落 + 「连连看 🎀」标题 + 圆角粉进度条，隐藏默认 Godot 深色启动图，错误提示/重试按钮同步玫瑰化（逻辑零改动）。
- 手机端适配：道具栏 7 槽在 390px 会溢出——手机隐藏 [n] 快捷键角标（纯键盘功能）+ 间距收紧到 8px，一行放下；桌面保留角标，旋转/缩放时动态切换。中途试过 HFlowContainer 换行方案，Godot 3.6 的 FlowContainer 无 align 属性且 SHRINK_CENTER 会塌缩成最窄子项宽（竖排叠罗汉），已回退 HBox。
- Validation: 6 个 headless 测试全绿（新增 power_ups_probe 27 项：武装/收回退还/执行消耗/炸弹伙伴消除/彩虹异色消除/关卡发放/武装态清理/花瓣与撒花生成）；浏览器 390×844 截图验收（圆体标题与文案、7 道具单行、加载壳粉化+CSS 樱花）。IAB rAF 节流导致游戏内花瓣/撒花的动态画面无法在桥接截图里定格（引擎冻结时淡入 tween 停在 alpha 0），生成逻辑已由无头探针覆盖。
- pck 2.73→2.85MB（快乐体子集 83KB + 新 emoji 字符）。
- Next suggestions:
  - 超级洗牌（保证有解）仍在数据里闲置；盲盒+炸弹/彩虹的协同道具可以再设计。
  - CI 可加无头浏览器冒烟截图防渲染回归；IAB 节流可在验收时用独立 Chrome 窗口规避。

## 2026-09-06 (玩法扩展三：冰雪挑战❄️)
- Context: 继续加玩法。新机制型模式「冰雪挑战」：部分瓷片结冰（淡蓝冰面+冰边框+冷色调），第一次配对只把冰打裂（瓷片留在原位、继续挡路径），第二次配对才消除；位于第 13 关解锁，5 种特殊玩法聚齐。
- 配置（special_modes.gd）：frost 三档难度按战役进度选（1-5 关进度 8×8/22% 结冰/8 种；6-10 进度 10×8/30%/9 种；11+ 进度 10×9/38%/11 种），时限 = 档位 base + 方块数×1s（思考时间充裕）；解锁判定/需求文案复用现有 config 机制。
- 机制实现（game.gd）：
  - board_armor 与棋盘平行的护甲网格，冰绑在"位置"上（洗牌是冰下面的方块在换）；
  - _apply_match_damage/_damage_tile 统一入口：经典点击、盲盒消除、自动消除都走它（非冰雪模式等价于直接清除）；消除类道具炸弹/彩虹直接穿透冰（连冰一起打掉）；
  - 剩余计数天然把裂冰瓷片算在内，清空判定/死局重排无需改动；自动消除的 will_clear 改为伤害后判定；
  - 新道具暖宝宝 🔥（快捷键 8，冰雪专属 3 充能）：武装后点结霜瓷片直接解冻（瓷片保留），点未结冰的不消耗并保持武装；再按收回退还；非冰雪模式使用会提示；道具栏其它模式自动隐藏该槽（8 槽全显时 390px 需要数字缩到 12px、间距收紧）。
- 记录与成就：frost_best_score 入 progression（default/normalize/patch/same_progress 四处）；新成就「冰雪初融」（完成一局）、「寒冰骑士」（不用暖宝宝完成一局，frost_uses 计数）。
- 界面：玩法面板新增「❄️ 冰雪挑战」卡（显示最佳分）；模式 chip/开场 callout（「冰雪挑战 · 33% 方块结了冰」）；
- Validation: 7 项 headless 测试全绿（新增 frost_probe 37 项：配置/档位/解锁边界/会话武装/两段伤害（含双方结冰一起裂的分支）/暖宝宝误点不耗/炸弹穿冰/战役模式等价性）。视觉用 Godot 离屏渲染截图验收（IAB 桥接被用户环境的遮挡+节流挡住）：冰雪棋盘冰面清晰可辨、🔥x3 入栏、玩法面板五卡齐。验收用的临时解锁补丁已还原，正式构建无后门。
- pck 2.85→2.87MB（新增 冰雪挑战/暖宝宝/❄/🔥/寒冰骑士 等字符，快乐体覆盖 648/747）。
- Next suggestions:
  - 极速连闯（3 连微型棋盘计时赛）可作下一个模式；超级洗牌道具仍闲置。
  - 每日签到（daily_reward_manager 已有）接主题解锁（theme_manager 已有）可补齐meta循环。

## 2026-09-06 (玩法扩展四：业内玩法批量集成——休闲/地狱/步数/AI竞速)
- Context: 用户要求联网调研业内连连看玩法并尽量集成。调研结论（来源：水果连连看单机版/宠物连连看/连连看4/阿达连连看等百科与商店页）：业内常见模式为 经典/极速(限时)/休闲/无限(无尽)/地狱/步数限制/挑战/双人合作/双人对战/人机对战/梦魇竞赛/主题/道具/关卡编辑器，消除类还常见障碍机制（冰块/锁链/迷雾）与叠层（羊了个羊式）。对照已有（经典战役/每日/限时/无尽/盲盒/冰雪+道具+主题），本轮补齐**可离线实现的四种**：休闲、地狱、步数挑战、竞速对战；双人/联机类需对战基建、叠层/重力/迷雾/锁链需新棋盘机制，留作后续。
- 休闲模式 🍵（第1关即开）：无时限固定盘（10×8/7种），倒计时显示 ∞；时钟防护泛化为 time_limit<=0（_on_second_tick/_consume_time_cost/_is_time_danger 三处，顺带修掉"无时限模式用道具会立刻判负"的隐患）。
- 地狱模式 🔥（第12关解锁）：12×8 大盘 12 种图案、100 秒极紧；装备削减为冻结1+洗牌1，其余全没收。
- 步数挑战 🧮（第14关解锁）：无时限，40 对给 56 步预算；每次消除一对扣 1 步（点击/自动/炸弹/彩虹统一走 _consume_move，误选不扣）；步数耗尽且未清空即判负；通关按剩余步数 ×20 加分，保留 ≥20% 预算解锁「节步大师」。
- 竞速对战 🤖（第15关解锁）：无时限，机器人按 ai_interval 8.5s 消一对，进度显示在新增的「对手」统计卡（x/y，非对战模式隐藏）；AI 先完成即判负。是"人机对战/竞赛"类玩法的单机实现。
- 配套：4 个新纪录（zen/hell/moves/race_best_score，progression 五处挂点）+ 5 个新成就（闲云野鹤/地狱行者/精打细算/节步大师/初胜机器人）；玩法面板扩到 9 卡（行距/卡高收紧、面板最小高度 440→640、小屏钳制 460→700）；special_modes.gd 新增通用 build_classic_style_level（四模式共用经典规则生成器）。
- Validation: 8 项 headless 测试全绿（新增 variants_probe：解锁边界×4/生成器参数/zen 时钟三防护/地狱装备削减/步数扣减与判负/AI 首消与判负/纪录持久化/成就定义）。视觉用 Godot 离屏渲染截图（九卡面板/步数局/竞速局）。
- 本轮工程备注：ZCode 的 Bash 通道故障（spawn /bin/zsh ENOENT，子代理同病），全部改动以幂等 Python 补丁脚本暂存（/tmp/variants_stage/apply.py，锚点唯一性+计数校验+可重入），经 node 子进程通道执行流水线完成。
- Next suggestions: 叠层（羊了个羊式依赖遮挡）、重力掉落、迷雾/锁链需要新的棋盘选择/遮挡模型；双人联机需 WebRTC/服务端；关卡编辑器是大工具。
