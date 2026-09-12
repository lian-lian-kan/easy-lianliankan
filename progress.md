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

## 2026-09-07 (玩法扩展六：机制玩法收官——叠层/重力/迷雾/锁链)
- Context: 补齐调研清单里剩下的可离线机制玩法，全部第 15 关解锁（收官内容）。叠层=羊了个羊式遮挡依赖；重力=消除后掉落补位；迷雾=信息遮蔽（边缘 ❓ 不可选，随消除退散）；锁链=相邻依赖（灰链不可选，旁边消除解锁）。至此单机可玩玩法共 14 种（经典战役+13 特殊玩法）。
- 叠层设计：`board` 始终是"可见层"，`board_lower` 存被压住的隐藏层——路径/提示/剩余计数等现有逻辑零改动；生成时按 stack_ratio 25% 抬升捐赠方块盖到别的格子；任意消除若底下有埋层自动顶出（_pop_stack_at，点击/自动/炸弹/彩虹四路都接）；有埋层的格子紫边框提示。不变量：有埋层必有盖，remaining==0 时必然全清。
- 重力设计：_resolve_after_board_changed 顶部挂 _apply_gravity()（返回 moved），列内向下压实；移动后清掉失效的选中/提示并刷新棋盘。
- 迷雾/锁链统一不可选语义 `_is_coord_playable`：点击、提示、自动消除、放大镜（走 _find_any_hint）自动跳过；迷雾层数 = clamp(剩余对数/12, 0, 2)；死局保底——提示为空时迷雾退一层/锁链全部崩解，保证必可通关。炸弹/彩虹可穿锁链，未解锁目标会提示且不浪费充能。
- 配套：4 纪录 + 4 成就（叠层达人/引力达人/拨云见日/斩断锁链）；玩法面板 13 卡并改 ScrollContainer 滚动（行盒可滚，短屏可用；_refresh_modes_panel 取行路径同步改 get_child(1).get_child(0)）；modes 面板 margin 容器补 SIZE_EXPAND_FILL（否则滚动区高度塌成 0）。
- 修复一个潜伏已久的首帧 bug：_reset_level_session 尾部从不调用 _refresh_board_visuals()，开局的机制视觉（迷雾❓/紫框/灰链）要等下一次任意刷新才出现（此前冰雪视觉靠窗口 resize 侥幸触发）。现在 reset 尾部显式刷新一次。
- Validation: 9 项 headless 测试全绿（新增 mechanics_probe：解锁边界×4、叠层盖/弹出一对一致性、重力列压实与 moved、迷雾层数/内外圈可玩性/末期退散、锁链不可选/提示跳过/邻接解锁、纪录持久化、成就定义）。视觉 Godot 离屏截图验收：13 卡滚动面板、叠层紫框、迷雾❓双环、锁链灰框全部生效。
- pck 2.91→2.96MB（新增 叠层/重力/迷雾/锁链/拨云见日/斩断锁链/引力达人 等字符，快乐体覆盖 697/797）。
- Next suggestions: 叠层可加第三层与掉落动画；重力可加补位动画；迷雾可做探照灯变体；双人联机与关卡编辑器需另立项。

## 2026-09-07 (修复：统计卡数值撑爆布局导致页面跳动)
- Context: 用户实测报告——统计卡数值（总分/倒计时等）文本变宽时把卡片最小宽度撑大，统计流重新换行、头部高度变化，下面棋盘跟着上下弹。根因：Godot Label 的最小宽度随文本增长，直接进 VBox 会传导到 PanelContainer 的 min size。
- 修复：_add_stat_card 里数值 Label 改放进固定 88×24 的 Control 裁剪容器（rect_clip_content + PRESET_WIDE 居中锚定），卡片最小尺寸恒定 100×64，文本再长也只是容器内居中/裁切，不影响布局。注意 Godot 3 属性名是 rect_clip_content（clip_contents 是 G4 的）。
- Validation: 10 项测试全绿（新增 stat_probe：注入 7 位分数/超长时间后卡片尺寸与统计流高度不变、短值同样稳定）；离屏截图确认 总分9876543 不改变任何布局。期间排障：clip_contents 属性名（G3/G4 API 差异）；一个 clip 崩溃轮遗留的僵尸 Godot 进程占住项目导致导出静默失败（kill 后恢复）。

## 2026-09-07 (代码质量 Round A：提取 board_engine.gd 纯逻辑模块 + 全局代码审查)
- Context: 质量专项启动（高内聚低耦合、大文件拆分、重构配满测试）。审查报告见 docs/code_review.md：game.gd 4764 行/209 函数为巨石文件；5 个 manager 未接线仍以 autoload 注册；test_game.gd 为死代码；另修复 _create_board 奇数尺寸越界隐患。
- 本轮：从 game.gd 抽出 16 个纯算法函数（路径 BFS 及其 4 个助手、提示查找、重排、洗牌、棋盘生成、可玩棋盘、重力压实、迷雾环、时间格式化、计数）到 scripts/board_engine.gd（静态 Reference、零场景依赖）；game.gd 留同名薄封装（board_logic_test 等外部调用方零改动）。提示/重排/生成的 playable 过滤参数化为 (filter_obj, filter_method)，迷雾/锁链语义保持。create_board 增加奇数尺寸守卫（尾部空格代替越界崩溃）。
- game.gd 4764 → 约 4560 行；新增 board_engine.gd 约 240 行纯逻辑。
- 覆盖：新增 board_engine_test.gd —— 16 个公共函数全分支断言（直连/绕行/围死/异种/空格/越界路径、提示过滤阻塞与放行、重排奇偶与过滤器、生成奇偶尺寸、重力移动与不动、环数、时间格式、洗牌保元素）。
- Validation: 11 项 headless 测试全绿（原 10 项回归 + board_engine_test）。导出成功。
- Next: Round B 抽 UI 面板构建（settings/achievements/modes/pause/onboarding）；Round C 抽特效子系统；Round D 处理 5 个未接线 manager 与 test_game.gd 死代码。

## 2026-09-07 (代码质量 Round B：移除 6 个死 subsystem 与 stub)
- Context: 审计确认 coins/energy/daily_reward/leaderboard/shop/theme 七个 manager（含 theme_manager）为 autoload 注册但全仓库零调用的死代码（启动即实例化，浪费启动时间与内存），test_game.gd 为无引用 stub。
- 移除：上述 6 个 autoload 注册 + 7 个脚本文件（git 历史可找回；未来做签到×主题解锁时从历史恢复再接线）。autoload 只保留 AudioManager。子集字体随之缩小（死代码字符清除）。
- Validation: 10 项 headless 测试全绿 + 导出成功 + web entry 通过。

## 2026-09-07 (代码质量 Round C：提取 fx_layer.gd 特效子系统)
- Context: 继续巨石拆分。樱花飘落/撒花的发射逻辑（PETAL_ICONS + _build_petals/_on_petal_tick/_spawn_petal/_spawn_confetti 四函数）从 game.gd 抽到 scripts/fx_layer.gd（静态、game 依赖参数化：层/字体/补间/树状态由调用方提供）。game.gd 留同名薄封装，mechanics_probe 的层与撒花断言零改动。
- Validation: 11 项 headless 测试全绿；导出成功。

## 2026-09-07 (代码质量 Round D：UI 面板构建抽到 ui_panels.gd)
- Context: P8 整改。onboarding/settings/achievements/pause/modes 五个面板构建函数（约 470 行）从 game.gd 抽到 scripts/ui_panels.gd 静态工厂（每个 build_X(game) 接收游戏节点：信号绑定 game 方法、字体/样式助手/进度状态经 game.<成员> 访问）。game.gd 留同名薄封装 + UI_PANELS preload。缺失标识符用"godot --check-only 解析循环"自动发现并补白名单。
- Validation: panels_probe（新建）断言五面板结构与 modes 13 卡；11+1 项测试全绿；导出成功。

## 2026-09-07 (代码质量 Round E：提取 stats_hud.gd 统计 HUD)
- Context: 继续巨石拆分。统计卡构建/文本设置/倒计时告警样式（_add_stat_card/_set_stat_text/_set_time_card_state/_update_time_warning_pulse 四函数 + PASTEL_BY_KEY 配色表）从 game.gd 抽到 scripts/stats_hud.gd 静态模块；函数设计为显式收参（pulse(game, is_danger, delta) 返回是否施加脉冲），便于直测。game.gd 留同名薄封装。
- 模块保障：卡片最小尺寸恒定（100,64），数值在固定 88x24 裁剪容器内——延续布局抖动修复。
- Validation: 12 项 headless 测试全绿（stat_probe 扩展：直测 add_card 注册与恒定尺寸、set_text 长值、set_card_state 红染/米色返回值、pulse 安全/危险两分支）。导出成功。
- 教训：本轮回合中曾因跨度锚点错误（end 锚用了文件后方的函数、把两函数之间约 2000 行误删）导致 worktree 损坏——依赖"锚点必须在语义上相邻"的核验后重建 worktree 重做，未合入任何损坏版本。

## 2026-09-07 (代码质量 Round F：模式展示元数据下沉 special_modes.gd)
- Context: 模式标签（17 个模式的中文名）与开场文案（8 种特殊模式）原本散在 game.gd 的 match 表与字典里，与展示耦合。下沉为 special_modes.gd 纯函数 mode_label(mode) / intro_text(mode_id)（MODE_LABELS / INTRO_TEXTS 常量表），game.gd 留薄封装；未知模式回落「未知」/「特殊模式开始」。盲盒开场文案因含运行时预览秒数保留在 game.gd 专属分支。
- Validation: 13 项 headless 测试全绿（新增 mode_meta_test：17 标签逐一断言、未知回落、8 种开场文案非默认）。

## 2026-09-07 (代码质量 Round F：模式展示元数据下沉 special_modes.gd)
- Context: 模式标签（17 个模式的中文名）与开场文案（8 种特殊模式）原本散在 game.gd 的 match 表与字典里，与展示耦合。下沉为 special_modes.gd 纯函数 mode_label(mode) / intro_text(mode_id)（MODE_LABELS / INTRO_TEXTS 常量表），game.gd 留薄封装；未知模式回落「未知」/「特殊模式开始」。盲盒开场文案因含运行时预览秒数保留在 game.gd 专属分支。
- Validation: 13 项 headless 测试全绿（新增 mode_meta_test：17 标签逐一断言、未知回落、8 种开场文案非默认）。

## 2026-09-07 (代码质量 Round G：道具槽显示并入 stats_hud + 架构文档)
- Context: 道具槽显示逻辑（_update_power_ups_display 循环体）从 game.gd 委托给 stats_hud.gd 的 update_power_up 静态函数（数量文本/可用性着色/暖宝宝冰雪专属隐藏）。新增 docs/architecture.md 架构总览：模块布局表、提取手法五步、已知债务清单。
- Validation: 12 项 headless 测试全绿；导出成功。

## 2026-09-07 (代码质量 Round H：best 值访问器下沉 progression.gd)
- Context: _progress_best_score/_progress_best_combo 从 game.gd 移为 progression.gd 静态纯函数 best_score(state)/best_combo(state)，game.gd 留薄封装；补 progression 模块访问器覆盖。
- Validation: 12 项 headless 测试全绿；导出成功。

## 2026-09-07 (代码质量 Round I：最后两个纯逻辑助手迁入 board_engine)
- Context: _format_time_seconds（新纪录用时的百分秒格式化）与 _contains_coord（坐标包含判断）迁入 board_engine.gd 静态函数，game.gd 留薄封装；board_engine_test 补百分秒格式化（65.5→01:05.50）与坐标包含正反用例。至此 game.gd 中已无散落的纯算法函数。
- Validation: 12 项 headless 测试全绿；导出成功。

## 2026-09-07 (代码质量 Round J：结算分支收敛为 RECORD_MODES 数据表)
- Context: _record_special_completion 里 10 个特殊模式各写一遍 patch/unlock/文案（约 90 行重复 match 分支），收敛为 special_modes.gd 的 RECORD_MODES 数据表（patch_key/best_key/achievements/label）+ bonus_achievements 条件成就纯函数（frost 免暖宝宝、moves 达标节步大师）。game.gd 结算函数缩为 ~35 行通用路径 + daily/time_attack 专属分支。
- Validation: 13 项 headless 测试全绿（mode_meta_test 扩展：结算表 10 模式 patch/best 键名规范、成就均已在 progression 定义、bonus_achievements 四分支）。导出成功。

## 2026-09-07 (代码质量 Round K：玩法面板行数据下沉 special_modes.gd)
- Context: _refresh_modes_panel 内联的 13 行展示数据（id/title/detail，含各模式最佳分与解锁状态文案）抽为 special_modes.modes_panel_rows(progression_state) 纯函数（OS.get_date 驱动"今日已完成"判断），game.gd 只剩一行委托。展示数据可在无场景环境直测。
- Validation: 12 项 headless 测试全绿（mode_meta_test 新增 modes_panel_rows 覆盖：13 行顺序/最佳分文案/今日完成分支）；web_entry 与导出成功。

## 2026-09-07 (代码质量 Round L：战役关卡表成模块 + 通关成就规则纯函数化)
- Context: ①_default_campaign_levels 的 134 行关卡数据抽为新模块 campaign_levels.gd（LEVELS 常量 + default_campaign_levels() 深拷贝返回，game.gd 留同名薄封装）；②_check_achievements_on_clear 的 6 条通关成就规则抽为 progression.clear_unlocked_ids(state, context) 纯函数（输入 level_index/combo/clear_time/hints_used/auto_used/level_count，返回待解锁 id 列表），game.gd 只留破纪录结算与通知壳。
- Validation: 13 项 headless 测试全绿——新增 campaign_levels_test（10 关序号/棋盘偶数格/kinds≤12 且格数足够/时限为正/模式白名单/文案非空/倍率单调不减/深拷贝防共享变异）+ progression_test 补 clear_unlocked_ids 全分支与边界（combo=3、30s 整、末关、已解锁不重复）；CI 测试清单同步加 campaign_levels_test；导出与 web_entry 通过。

## 2026-09-07 (代码质量 Round M：机制网格助手下沉 board_engine.gd)
- Context: 冰甲/锁链/叠层/迷雾的网格构建与查询从 game.gd 下沉为 board_engine 纯静态（build_frost_armor_grid/build_chain_grid/bury_stack_layer/count_chains/break_chains_around/zero_grid/pop_stack/fog_layers 共 8 个），game.gd 留模式守卫+提示文案薄壳（净减约 125 行逻辑）。shuffle 统一走 board_engine.shuffle_array。
- Validation: 13 项 headless 测试全绿；board_engine_test 新增机制网格全分支覆盖（ratio 0/1/超1、空盘、 burying 跨层守恒、四邻破链不含自身、越界守卫、pop 语义、fog 层数边界）；导出与 web_entry 通过。

## 2026-09-07 (代码质量 Round N：主界面构建迁入 ui_hud.gd 模块)
- Context: _build_ui 的 330 行主界面构建（渐变背景/樱花层/头部面板/道具行/连击条/关卡下拉/棋盘区/特效层）整体迁入新模块 ui_hud.gd 的 build_main_ui(game) 静态工厂（ui_panels.gd 同款 game 参数模式），game.gd 留 3 行壳；panels_probe 新增主界面结构断言（棋盘格/特效层/标签组/HFlowContainer 行/道具注册共 7 项）。
- Validation: 13 项 headless 测试全绿；game.X 全量引用审计（55 个引用逐一核对 game.gd 声明集，拦下 HFlowContainer 类名误前缀）；导出与 web_entry 通过。

## 2026-09-07 (代码质量 Round O：HUD 状态刷新迁入 ui_hud.gd)
- Context: _refresh_ui 的 116 行模式横幅/统计卡/按钮态刷新迁入 ui_hud.gd 的 refresh_ui(game) 静态（与 build_main_ui 同模块：主屏构建+状态同步），game.gd 留 3 行壳；panels_probe 新增行为断言（stage_status 切换 → 暂停按钮文本 继续/暂停 联动）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 15 断言）；game.X 引用审计通过（上下文无关前缀修复运算符场景漏前缀）；导出与 web_entry 通过。修复过程发现并纠正 migrate 脚本 w 模式覆盖 build_main_ui 的事故（git checkout 恢复+重追加）。

## 2026-09-07 (代码质量 Round P：道具域迁入 powerups.gd + 修复 Round D 隐性音量行 bug)
- Context: 道具簇 13 个函数（loadout 规则 _init_power_ups、取用流程 _use_power_up、7 个 _activate_*、3 个 _execute_*）约 290 行迁入新模块 powerups.gd（game 参数静态工厂），game.gd 留同名薄壳。power_ups_probe 新增 9 项断言：level-10 载荷表、rush/地狱/冰雪三种特殊载荷、无尽禁沙漏、非冰雪禁暖宝宝、暂停不可消耗。
- 额外修复：ui_panels.gd 设置面板音量行用 game.AudioManager（autoload 不是节点属性）静默中止，音量/音效/音乐/静音四行自 Round D 起从未渲染——改为裸全局 AudioManager。纠正 architecture.md 提取口诀（autoload 裸用 + Dictionary ==/hash 引用与顺序语义）。
- Validation: 13 项 headless 测试全绿（power_ups_probe 现 34 断言、零脚本错误）；导出与 web_entry 通过。

## 2026-09-08 (修复：3× 屏字体发糊——移动端 DPR cap 2.0 提到 3.0)
- 根因：加载壳 applyDprCapForMobile 把移动端 devicePixelRatio 压到 2.0（7d40326 引入的省电/性能策略），而 Godot 3.6 导出模板按 canvas = innerWidth × devicePixelRatio 生成背衬。3× 屏（iPhone Pro/多数安卓旗舰）被压到 2× 再由浏览器放大 1.5 倍，所有字形都糊。2× 屏不受影响。
- 修复：defaultCap 2.0 → 3.0，3× 屏原生 1:1 渲染；?dpr= 参数保留作低端机救援口。字体链路本身（DynamicFont 1:1 栅格化 + use_filter）无需改动。
- Validation: 13 项 headless 测试全绿；导出物 index.html 含 defaultCap = 3.0；web_entry 通过；CI 绿后线上复验。

## 2026-09-08 (真修复：高分屏全面发糊的根因——allow_hidpi 未开启)
- 用户复测仍糊，复查发现昨日 DPR cap 修复无效：根因是项目设置 display/window/dpi/allow_hidpi 缺省 false，引擎调 godot_js_display_setup_canvas(…, is_hidpi_allowed()?1:0) 把 JS 侧 GodotDisplayScreen.hidpi 恒置 false，getPixelRatio() 恒返 1，canvas 永远按 CSS 1× 渲染，所有高分屏（含 2× 屏）都被合成器放大发糊。昨日改 cap 无效是因为链路源头根本没开。
- 修复：①project.godot 加 window/dpi/allow_hidpi=true（注意：导出流程的 --editor --quit 会重写 project.godot，Godot 3.6 ConfigFile 的注释保留实现会把注释压扁并与下一行粘连——带注释的设置行会被吞进注释失效，必须写无注释的裸行）；②shell DPR 逻辑改为"全端下限 2×、移动端钳制 2~3×、?dpr=N 强制任意倍率"（覆盖谎报 dpr=1 的 webview，如 ZCode IAB）。
- 验收：IAB 实测 canvas 背衬 390×844 → 780×1688（ratio 2.0），游戏正常启动布局正常；13 项测试全绿；web_entry 通过。pck 内确认烘焙 allow_hidpi key。截图工具按 CSS 1× 采样无法体现背衬增益，清晰度以几何映射（2× 背衬 ↔ 2× 物理像素 1:1）+ 真机观感为准。

## 2026-09-08 (高清化第二轮：stretch mode 2d 让布局回归逻辑像素)
- 问题：开启 allow_hidpi 后 canvas 像素宽度翻倍，_viewport_flags 的短边≤768 判定把手机误判成桌面布局（快捷键角标出现、统计卡变小），文字相对尺寸也随之变小。
- 修复：①project.godot 启用 window/stretch/mode="2d" + 基准 390×844（竖屏手机设计基准）——布局坐标回到逻辑像素，任何密度的手机都稳定命中移动布局；文字由字体过采样按设备密度栅格化，高分屏依然锐利；②MOBILE_SHORT_SIDE_MAX 768→860（横屏手机逻辑短边 844 保持移动布局）；③新增 tests/offscreen_font_probe.gd：离屏窗口按手机 canvas 密度启动真实游戏并导出视口纹理，原生分辨率核对字体锐度。
- 验证：离屏探针实测 logical_viewport=(390,844)@window 780×1688，2× 密度下字形锐利、移动布局保持；13 项测试全绿；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round Q：棋盘视觉簇迁入 board_view.gd)
- Context: _refresh_board_visuals/_update_tile_sizes/_apply_tile_style/_icon_for 共约 170 行迁入新模块 board_view.gd（game 参数静态工厂），game.gd 留同名薄壳；panels_probe 补棋盘视觉断言（格子/按钮成对构建、刷新后台面图标非空、tile 尺寸钳制下限）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 18 断言）；迁移复用多函数迁移器（上下文无关前缀 + game.X 全量审计 + get_viewport_rect 类 Node 方法补前缀）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round R：屏幕布局适配迁入 ui_hud.update_layout)
- Context: _update_layout_for_screen_size 的 115 行响应式布局适配（断点旗标/棋盘高度/边距/统计卡与按钮尺寸/竖屏头部压缩）迁入 ui_hud.gd 的 update_layout(game) 静态（主屏模块职责闭环：构建+状态刷新+布局），game.gd 留 3 行壳；panels_probe 补布局行为断言（竖屏紧凑边距/移动端按钮尺寸/非核心统计卡隐藏）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 21 断言）；迁移器 span 终止条件扩展到全部顶层声明（func/const/var），避免吞掉函数后的字体常量声明；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round S：输入处理簇迁入 game_input.gd)
- Context: _on_tile_pressed（选中/配对/待管道具路由）、_on_memory_tile_pressed（盲盒翻牌）、_unhandled_input（键盘快捷键路由 P/H/A/S/R/[/]/Enter/F/1-8/Esc）共约 236 行迁入新模块 game_input.gd（game 参数静态工厂），game.gd 留同名薄壳；panels_probe 补输入行为断言（首按选中/再按取消且不耗步数、键盘 P 暂停/恢复路由）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 27 断言）；game.X 全量审计通过（accept_event 为 Control 方法良性）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round T：消除/连击特效簇迁入 fx_layer.gd)
- Context: 特效发射簇 8 函数（_play_eliminate_effects/_tile_center_in_effect_layer/_spawn_ring_effect/_spawn_particle_burst/_spawn_combo_particle_burst/_spawn_board_particles/_show_combo_burst + 尺寸中心换算）约 198 行迁入 fx_layer.gd（追加模式，不覆盖既有 statics），game.gd 留同名薄壳。_pulse_tile 因含 yield（协程）不能做静态函数，退回 game.gd 实例方法原样保留。
- Validation: 13 项 headless 测试全绿（panels_probe 现 29 断言：消除特效同步生成进特效层、连击爆字标签更新）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round U：会话生命周期编排迁入 session.gd)
- Context: 会话编排簇 6 函数（_reset_level_session/_resolve_after_board_changed/_resolve_special_clear/_fail_moves_exhausted/_start_special_mode/_exit_special_mode）共 232 行迁入新模块 session.gd（game 参数静态工厂），game.gd 留同名薄壳。special session 架构落地：会话重置/胜负结算/模式进出集中在单一模块。panels_probe 补会话行为断言（重置清瞬态、锁定模式拒绝、zen 会话进出）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 32 断言）；迁移修复了带默认值参数被误传为命名实参的壳生成 bug（GDScript 不支持命名实参）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round V：配置装载与进度存取拆分为独立模块)
- Context: 配置装载 8 函数（_load_config/_load_json_file/_load_campaign_levels/_load_tuning/_load_icon_sets/_load_game_mode_configs/_default_tuning/_default_icon_sets）迁入 game_config.gd；进度存取 3 函数（_load/_save/_patch_progress_state）迁入 progress_store.gd，game.gd 留同名薄壳。panels_probe 补 7 项持久化语义断言（配置重载保持关卡表、combo_candidate 提升最佳、落盘文件存在、special 会话过滤 campaign 字段但保留自身纪录）。
- 附带修复：game_input.gd 与 session.gd 残留的 game.AudioManager 误前缀（12 处，Round S/U 迁移引入、此前断言不敏感未暴露）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 36 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round W：样式辅助簇迁入 ui_panels.gd)
- Context: _apply_glass_style/_apply_button_style/_style_dialog_buttons 迁入 ui_panels.gd（追加模式，样式即 UI 构建域），game.gd 留同名薄壳。panels_probe 补 3 项样式行为断言（玻璃面板 stylebox 覆盖、按钮五态覆盖、递归对话框按钮玫瑰白字）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 39 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round X：计时器构建与消息/横幅辅助迁入 ui_hud.gd)
- Context: _build_timers（10 个会话计时器构建）、_show_message/_hide_message（消息横幅）、_show_stage_callout（关卡横幅浮字）共 82 行迁入 ui_hud.gd（主屏基础设施：构建+刷新+布局+计时器+消息），game.gd 留同名薄壳。panels_probe 补 6 项断言（计时器簇构建齐全、秒表运行中、消息横幅显隐、关卡横幅浮字创建）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 45 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round Y：棋盘动画与提示/自动消辅助拆分)
- Context: 棋盘出生/洗牌动画 2 函数（_animate_board_spawn/_animate_shuffle_wave）迁入 board_view.gd；提示/自动消辅助 2 函数（_on_hint_pressed/_on_auto_pressed）迁入 game_input.gd，game.gd 留同名薄壳。panels_probe 补 5 项行为断言（出生动画发射 tween、提示高亮一对、自动消登记并消除被提示的一对）。
- 修复：迁移器把夹在动画函数之间的文件级 const FX 卷入模块并误前缀（const game.FX 非法）——已还原 game.gd；game_input 残留 game.AudioManager 误前缀 8 处一并修正（autoload 恒为裸全局名）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 49 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round Z：控制按钮/关卡下拉/成就通知迁入 ui_hud.gd)
- Context: UI 构建散点 3 函数（_create_control_button 工厂/_populate_level_select_options 关卡下拉/_show_achievement_notification 成就通知浮层）共 88 行迁入 ui_hud.gd（追加模式），game.gd 留同名薄壳。panels_probe 补 3 项断言（工厂按钮带样式、关卡下拉逐关填充、成就通知面板创建）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 42 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AA：道具/角标标签工厂迁入 stats_hud + 架构文档重写)
- Context: _create_power_up_label/_create_chip_label 迁入 stats_hud.gd（HUD 显示构建域），game.gd 留同名薄壳；docs/architecture.md 整体重写为当前 16 模块布局（含每模块测试映射）、提取手法补齐五条已踩实的坑、已知债务更新为编排层收尾状态。
- Validation: 13 项 headless 测试全绿；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AB：计时器回调与按钮/键盘动作归并)
- Context: 计时器回调 10 函数（second/race tick、message/error/combo/level highlight/advance/freeze/memory timeout）迁入 ui_hud.gd；按钮/键盘动作 6 函数（shuffle/reset/jump/pause 按钮与 cycle_level_selection/toggle_fullscreen）迁入 game_input.gd，game.gd 留同名薄壳（信号 connect 目标仍是 game 实例壳）。panels_probe 补 5 项回调行为断言（消息超时隐藏、冻结超时解冻、秒表扣时、洗牌耗时且保持对局）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 47 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AC：特殊模式结算迁入 session.gd + 启动日志收敛)
- Context: _record_special_completion（RECORD_MODES 表结算 + daily/time_attack 分支）迁入 session.gd（与 _resolve_special_clear 同域），game.gd 留同名薄壳；_ready 的 9 条启动 print 收敛为 3 条阶段日志。panels_probe 补 4 项结算断言（zen 纪录与结算面板、daily 落今日戳）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 50 断言）；导出与 web_entry 通过。

## 2026-09-08 (Round AD：落地 CI 无头浏览器冒烟测试)
- Context: architecture.md 债务清单中的 CI 无头浏览器冒烟落地。tools/ci_smoke.sh：本地起 HTTP 服务 + 系统无头 Chrome 加载游戏（?smoke=1 激活信标钩子）+ 轮询 boot beacon 判定引擎真实启动；deploy.yml 在导出后新增 Headless browser smoke 步骤（continue-on-error 观察模式，SMOKE_WAIT=60）。壳的 setStatusMode('hidden') 分支新增信标发送（仅 ?smoke=1 时激活，普通游玩零影响）。
- 已知限制：本机 ZCode/macOS 无头沙箱无法跑起引擎（display 层限制，与 IAB 冻结同源），冒烟的真实判定环境是 CI 的 ubuntu-latest + SwiftShader WebGL；先观察模式收集数据，稳定后再转为门禁。
- Validation: 13 项 headless 测试全绿；导出与 web_entry 通过。

## 2026-09-08 (Round AD 修补：冒烟步骤观察模式生效 + 可执行位)
- 首跑失败原因：①新写文件丢失可执行位（git 记录 100644，CI 直接执行报 126）；②continue-on-error 在一次编辑竞态中丢失。修复：git update-index --chmod=+x + 步骤改为 bash 调用 + 补 continue-on-error: true（观察模式，不阻塞部署）。

## 2026-09-08 (代码质量 Round AE：棋盘重建/连击得分/超时判负归并)
- Context: _render_board 迁入 board_view.gd；_apply_combo_gain（连击窗口/倍率公式/time_attack fever/进度候选补丁）与 _on_time_up（战役与 special 双分支判负）迁入 session.gd，game.gd 留同名薄壳。panels_probe 补 3 项断言（网格重建一致性、连击公式按当前关卡乘数计算、超时判负+重开恢复）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 55 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AF：棋盘动画去协程化迁入 board_view.gd)
- Context: 三个含 yield 的棋盘动画协程（_pulse_tile 双 tween 链/_animate_select 选中方块脉冲+环延迟生成/_shake_tile 抖动）重构为**单 tween 顺序多步序列**（G3 Tween 顺序执行 + 延迟参数，tween_all_completed 回调环生成），彻底去 yield 后迁入 board_view.gd，game.gd 留同名薄壳。panels_probe 补动画行为断言（静止回归/新环面板身份计数）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 55+ 断言）；导出与 web_entry 通过。

## 2026-09-08 (Round AG：修复冒烟步骤的残缺 YAML 并保留观察模式)
- 发现：a95a17d 提交的冒烟步骤 YAML 残缺（run: 块内直接调用无可执行位的脚本，缺 bash 前缀），CI 三连 126 从未真正执行冒烟逻辑。
- 修复：步骤改为 `bash tools/ci_smoke.sh`（免疫可执行位问题，另补 +x），保留 continue-on-error 观察模式——冒烟逻辑首次在 linux 真实执行，待数据稳定后再转硬门禁。
- Validation: 推送后 CI 全绿；冒烟步骤输出留档（SMOKE OK / SMOKE FAILED + beacon 诊断）。

## 2026-09-08 (Round AG：冒烟转硬门禁)
- 依据：linux CI 首跑 SMOKE OK（引擎 4 秒启动、beacon 到达），机制已被目标环境验证；ci_smoke.sh 加装第二次 Chrome 重试进一步降低偶发抖动。
- 变更：deploy.yml 移除 continue-on-error，冒烟失败将阻塞部署（坏启动不该上线）；信标等待升级为两次 Chrome 尝试。

## 2026-09-08 (代码质量 Round AH：棋盘反馈特效迁入 fx_layer.gd)
- Context: 反馈特效簇 4 函数（_flash_error_tiles 错误闪红/_animate_hint_tiles 提示脉冲/_show_path 路径预览/_path_to_overlay_points 坐标映射）迁入 fx_layer.gd，game.gd 留同名薄壳。panels_probe 补 2 项断言（错误闪红登记方块、路径预览显示 overlay）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 50 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AI：设置胶水/模态尺寸/状态标签归并)
- Context: 设置面板胶水 3 函数（_populate_icon_set_options/_on_icon_set_selected/_on_effects_toggled）与模态面板尺寸 2 函数（_update_modal_panel_sizes/_mount_modal_panel）迁入 ui_panels.gd；_status_label 状态文案映射迁入 ui_hud.gd，game.gd 留同名薄壳。panels_probe 补 5 项断言（图标集下拉填充/选择钳制/模态尺寸/状态文案映射与未知回退）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 37 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AJ：盲盒会话辅助与视口旗标归并)
- Context: 盲盒模式会话辅助 5 函数（_memory_key 纯映射/_start_memory_preview/_on_memory_preview_timeout/_memory_schedule_hide/_on_memory_hide_timeout）迁入 session.gd；_viewport_flags（手机/横竖屏/紧凑高度分类）迁入 ui_hud.gd，game.gd 留同名薄壳。panels_probe 补 4 项断言（memory key 纯映射/schedule 记录并加锁/手机竖屏与桌面横屏分类）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 41 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AK：资源消耗与阶段生命周期迁入 session.gd)
- Context: 8 函数迁入 session.gd——资源消耗（_consume_time_cost/_consume_move）、阶段暂停恢复（_pause_stage/_resume_stage）、战役开局（_start_level）、竞速判负（_fail_race_lost）、成就（_unlock_achievements/_check_achievements_on_clear），game.gd 留同名薄壳。panels_probe 补 7 项生命周期断言（时钟消耗/无时钟豁免/moves 外无操作/暂停恢复/开局/成就解锁持久化）。
- Validation: 13 项 headless 测试全绿（panels_probe 现 54 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AL：模态面板生命周期收敛到 ui_panels.gd)
- Context: 五组「打开=暂停+停表、关闭=恢复+启表」重复模式（onboarding/settings/achievements 各自内联 6 行）收敛为 ui_panels.open_modal/close_modal；_refresh_modes_panel 的 30 行模式卡渲染迁入 ui_panels.refresh_modes_rows 并改用构建时注册的 game.modes_content（消除 get_child 链遍历——旧链式断言实际拿到的是 ScrollContainer 内建 HScrollBar，时序脆弱）；_show/_hide_pause_panel 信息刷新迁入 ui_panels（pause/resume 语义仍归 session）。
- 顺手修复三个既有 bug：①progression.apply_update 白名单合并静默丢弃 onboarding_seen 补丁 + same_progress 不比较该字段 → 引导面板从未持久化、每次启动重弹；②_on_achievements_pressed 每次打开只 queue_free 旧面板 children，泄漏整个旧 holder+panel 树 → reopen_achievements 改为释放旧 holder 再重建；③panels_probe 的 modes 链式断言依赖内建滚动条尚未加入的偶然时序 → 改断言注册的 modes_content。
- Validation: 13 项 headless 测试全绿（panels_probe 91→117 断言；progression_test 补 onboarding_seen patch/持久化判定/双向清位 6 断言）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AM：关卡选择簇/连击条迁 ui_hud，开场 callout 数据驱动)
- Context: 关卡选择状态胶水 5 函数（_selected_level_option_index/_sync_level_select_selection/_level_label_by_index/_on_level_select_changed/_trigger_level_highlight）与连击条状态 2 函数（_reset_combo/_update_combo_progress）迁入 ui_hud.gd——主屏控件的交互与状态归并主屏模块；_play_level_intro_animation 的 6 分支 if/else 开场横幅链收敛为 special_modes.stage_callout 纯函数（返回 [text, color]，战役关卡统一格式、daily/endless/frost 内嵌动态上下文），game.gd 全部留同名薄壳。
- Validation: 13 项 headless 测试全绿（panels_probe 117→129 断言：未解锁回弹+消息/已解锁仅刷新不跳关/下拉同步/标签映射/琥珀高亮往返/连击条满格-暂停清零-重置停表/战役 callout 渲染；mode_meta_test 补 stage_callout 8 断言：战役格式与 id 回退/每日日期/无尽轮次/限时静态/盲盒颜色/冰雪百分比）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AN：会话心跳拆出 hud_timers.gd)
- Context: ui_hud.gd 924 行拆分第一步——计时器工厂（10 个 Timer 构建）与其驱动的 8 个通用心跳回调（second/race tick、message/error/combo/highlight/advance/freeze timeout）迁入新模块 hud_timers.gd（127 行），ui_hud 回归「主屏结构：构建/刷新/布局/控件」职责（790 行）。
- 顺手消除 Round AJ 遗留的绕圈调用链：game._on_memory_*_timeout → session 转发壳 → game.UI_HUD 实现——盲盒 preview/hide timeout 实现搬进 session.gd（盲盒会话域归属），转发壳删除。
- Validation: 13 项 headless 测试全绿（panels_probe 129→138 断言：冻结时钟豁免/解冻恢复扣时/错误闪红超时清理/连击超时重置/过关推进跳关/竞速 AI 按间隔步进/盲盒翻面与收牌超时）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AO：屏幕适配拆出 hud_layout.gd)
- Context: ui_hud 拆分第二步——_viewport_flags（手机/竖屏/紧凑分类）与 update_layout（棋盘高度比例/边距/网格间距/统计卡与控件尺寸/竖屏头部压缩，116 行）迁入新模块 hud_layout.gd，ui_hud 回归「构建/刷新/浮层/控件」职责（790→662 行）。game.gd 两个薄壳改向 HUD_LAYOUT，调用方零改动。
- Validation: 13 项 headless 测试全绿（panels_probe 138→139 断言：补 is_compact_height 分支）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AP：棋盘机制状态域收敛为 board_mechanics.gd)
- Context: 五机制（冰甲/叠层/重力/迷雾/锁链）的棋盘状态操作从 game.gd 收敛为新模块 board_mechanics.gd——可选性判定（is_coord_playable/is_fogged/cell_ring）、机制网格构建与解除（build_stack_layers/build_chain_locks/dissolve_all_chains/break_chains_around）、消除伤害（apply_match_damage/damage_tile 两段式冰甲+叠层顶出）、重力压实触发（apply_gravity）、迷雾层数推导（update_fog），game.gd 12 函数薄壳化（1097→1058 行）。炸弹/彩虹边路构造 edge_path 迁 board_engine 纯函数。
- Validation: 13 项 headless 测试全绿（panels_probe 139→149 断言：冰甲首消裂而不清+次消清除/锁链锁定不可选+崩解恢复/重力列压实+选中提示重置/迷雾层数随模式推导与复位/边路经顶行构造）；导出与 web_entry 通过。

## 2026-09-08 (代码质量 Round AQ：game.gd 最后一批散点清扫)
- Context: 字体管理独立为新模块 ui_fonts.gd（3 字体常量 + font_at_size 按字号缓存 + init_theme 全局主题挂载）；特效胶水 2 函数（_make_fx_tween 补间工厂/_play_stage_clear_celebration 过关庆典）迁 fx_layer；棋盘视觉胶水 2 函数（_color_for 图标配色/_try_get_tile_button 格子查找）迁 board_view；时间告警判定（_is_time_danger）与道具显示循环（_update_power_ups_display）迁 stats_hud；暂停面板动作 2 函数（_on_restart_current_level 会话感知重开/_on_back_to_first_level）迁 ui_panels；_start_second_timer 迁 ui_hud。game.gd 1058→993 行，跌破千行。
- Validation: 13 项 headless 测试全绿（panels_probe 149→162 断言：字体缓存同对象/主题挂载/格子越界拒绝/无图标集白色回退/补间挂载/庆典产物/时钟豁免-低时告警-暂停不告警/特殊会话重开与返回第1关）；导出与 web_entry 通过。

## 2026-09-08 (诊断：界面文字模糊——全链路取证 + ?diag=1 现场诊断徽标)
- 取证：①Godot 3.6 源码确认 stretch 2d 自动字体过采样链（scene_tree STRETCH_MODE_2D 分支 _update_font_oversampling(screen/viewport×shrink)，use_oversampling 默认 true，缓存重建健全）；②桌面离屏实验：override_oversampling=2 与自动档输出逐像素一致（证明桌面过采样已生效），use_filter 开关在 1:1 纹素映射下零差异；③Playwright 模拟 iPhone（dsf=2/3）实测 Web：canvas 物理尺寸正确（780/1170），字体过采样随 DPR（3× 缩回逻辑尺寸细节能量 21.27 ≥ 2× 的 20.61）——模拟环境全链路健康，无法复现模糊。
- 结论：模糊根因在用户实际设备环境而非代码——头号嫌疑 GitHub Pages CDN/浏览器缓存了 09-08 高清化修复（allow_hidpi）之前的旧构建；次嫌特定 webview 的 devicePixelRatio 覆盖失败。
- 变更：shell 加 ?diag=1 实时诊断角标（dpr/canvas 物理尺寸/css 尺寸/effRatio=canvas.width÷clientWidth/UA 类别，1s 刷新）——真机打开读 effRatio：<2 即 canvas 未放大（DPR 链路问题）；≥2 说明渲染正常，模糊是字号/字重观感问题，转产品向优化。
- Validation: 13 项 headless 测试全绿；Playwright 验证徽标读数（dpr=3, canvas=1170x2532, effRatio=3.00）；导出通过。

## 2026-09-10 (加载性能：Service Worker 预缓存 + pck 排除测试代码)
- 背景：用户报"原来秒出现在很慢"。实测定位：本机到 github.io 仅 ~37KB/s，wasm(5.5MB gz)+pck(2.7MB gz) 并行下载需 150~230 秒；"原来秒出"是缓存命中，高频部署使缓存反复失效。体积侧取证：wasm 为官方模板恒定体积，pck 内 emoji 位图(796 张 128px 调色板 PNG, p50 2.6KB)已是 Google 发布态、重压缩无收益(102~107%)——打包体积接近内容下限，优化杠杆在缓存。
- 变更：①新增 shell/sw.js 离线缓存——payload(wasm/pck/js/png) cache-first 永久缓存，二次访问零网络下载（Playwright 实测 transferSize 全 0）；index.html network-first 发现新部署，sw.js 顶部构建 hash（CI sed $GITHUB_SHA 前 7 位）变更触发整组缓存后台换新，当前局继续玩旧缓存、下次打开即新版；②deploy.yml 导出后注入 hash 并附带 sw.js；③export_presets exclude tests/*, tools/*（pck 62→60 文件，2.97→2.85MB）。
- Validation: 13 项 headless 测试 + web_entry + offscreen_font 全绿；SW 二次加载缓存命中实测通过。

## 2026-09-10 (产品升级一期：多页面框架 + 樱花币养成闭环)
- 调研：2025-26 休闲配对品类共识=「配对核心+重 meta 层」（收集册/装扮/连续签到/赛季活动，Appmagic/GameRefinery/Deconstructor of Fun）；本项目 14 种玩法核心已齐，缺口正是 meta 层与页面结构。
- 变更：①新增 page_router.gd 多页面外壳——底部五格导航（主页/旅程/图鉴/有礼/小铺）+ 全屏页面容器，打开页面走 modal 暂停语义并冻结过关推进、隐藏主屏浮层；②旅程页：3 章 15 节点地图（解锁/当前/锁定态，点节点进关）；③图鉴页：14 套图集 210 图案收集册（收集/❓未知/进度）；④有礼页：7 天循环签到（5~50🌸递增，漏签重置）；⑤小铺页：图集商店（30🌸/套，购买自动装备，余额不足拒绝）；⑥经济：progression 新字段 coins/collected/owned_sets/signin_streak/last_signin（normalize/apply_update/same_progress 全扩展），过关奖励 8+2×关 id、开局收集图案 +2/个；⑦header 樱花币钱包 chip，refresh_ui 同步；⑧export 排除 tests/tools。
- 字体：新页面文案触发缺字（樱园初语→樱园初），恢复全量字体（NotoColorEmoji 10.7MB/NotoSansSC 8.3MB/ZCOOL 1.5MB，均超守卫阈值）重跑 subset_fonts.py，887 源字符重切子集并入库。
- 验证：panels_probe 162 断言（加固 special 会话进度断言为相对比较）+ 新增 page_probe 26 断言（导航/页面暂停恢复/地图节点三态/图鉴进度/签到发放与防重/商店购买装备与余额拒绝/过关发币/钱包落盘）本地全绿后合入；其余批次验证移交 CI。

## 2026-09-10 (玩法迭代：第 15 种玩法「叠叠消」——三消槽位核心)
- 调研：Tile Match（羊了个羊/3 Tiles/Triple Match）为当前最热配对品类，主流规则=7 格槽位+三张同面消除+多层堆叠遮挡（上层压下层）+槽满即败，常见道具为洗牌/撤销。
- 变更：①新增 tile_match.gd——纯状态机（generate 每 pattern 3 的倍数+洗乱/is_covered 九宫格遮挡判定/pick 入槽+三消+胜负转换/undo 退牌/shuffle 重排剩余图案，各限一次）+ 全量重建视图（层叠偏移 Button 牌面、7 格槽位、道具行）；②special_modes 注册 tray（第 16 关解锁、240s、4 层×5×6、10 种图案）+ label/intro/callout/RECORD_MODES/panel rows（14 卡）；③session tray 分支：reset 替代棋盘生成（board 置空+牌堆渲染层）、_resolve_tray_clear（tray_result 纪录+🌸+20+结算面板）、_fail_tray_full；④progression 新增 tray_best_score 全 schema 与 tray_first 成就；⑤字体子集重切（897 字符）；⑥deploy.yml CI 测试清单补齐本地全量（mode_meta/stat/panels/page/tray_probe）——今后全部验证都在 CI 远端执行。
- Validation: 本地仅做纯文本自查；全量测试/导出/冒烟由 CI 远端执行（本次为本地零测试提交的首次实践）。

## 2026-09-10 (品牌定名 + 微信小程序能力借鉴：星级评价 / 樱花币复活)
- 调研：微信小游戏典型能力=排行榜/看广告复活/分享得道具/体力墙/星级评价（官方文档+羊了个羊复盘+zrong 失败反馈分析）。纯 H5 无微信 SDK：排行榜与分享需平台能力（跳过），「看广告复活」本地化为「樱花币复活」，星级评价与失败反馈节奏离线可做。
- 定名：游戏名「李米，索菲亚的连连看」——主页标题/欢迎面板/加载壳/落地页四处统一，字体子集重切（897→900 字符含名字）。
- 星级评价：战役通关按剩余时间比评 1-3 星（≥50%/≥25%），progression 新增 level_stars 全 schema（patch key "stars" 取最优），旅程地图节点显示 ⭐，结算面板带星。
- 樱花币复活：战役/特殊模式/步数模式失败后提供「🌸30 复活」（保留棋盘进度，+30 秒或 +5 步），余额不足自动隐藏；开局/结算自动复位按钮。
- Validation: 本地零测试（用户要求），全部验证由 CI 远端执行。

## 2026-09-10 (定名更正：Sophia的连连看)
- 游戏名由「李米，索菲亚的连连看」更正为「Sophia的连连看」，四处统一（主页标题×2/欢迎面板/加载壳/落地页 title+h1）；字体子集重跑确认 Sophia 拉丁字形在快乐体核心覆盖内。

## 2026-09-10 (玩法迭代二期：收集挑战 + 翻翻乐，玩法池 15→17)
- 调研：关卡目标三大类（障碍消除/道具生成/物块收集，腾讯游戏学院）与翻牌记忆配对（百度百科）为微信小游戏连连看常见机制，本项目此前均未覆盖。
- 变更：①「收集挑战」(collect，第 17 关解锁，150s)——随机 3 种目标图案各需消 3 对，board_wrapper 上方目标进度行实时更新，全部达标即过关（无需清空棋盘）；消除统计钩子挂 board_mechanics.apply_match_damage 调用方 game_input（damage 前取图案对）。②「翻翻乐」(flip，第 18 关解锁，180s)——新模块 memory_flip.gd：12 对全暗牌、翻两张同面消除、异面 0.7s 后盖回（新增 flip_back_timer 于 hud_timers）、全消获胜；flip_layer 挂棋盘区。③progression 新增 collect_best_score/flip_best_score 与 collect_first/flip_first 成就；special_modes 补 config/label/intro/callout/RECORD/panel rows（16 卡）；CI 清单加 flip_probe。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (重构 Round BM：page_router 按域拆分，经济独立 economy.gd)
- 审查：page_router.gd 经多页面/经济/签到/商店多轮迭代膨胀到 562 行，导航壳、四页构建、经济逻辑三职责混装。
- 变更：①新增 page_ui.gd（50 行）——公共页头与滚动内容区工具，依赖中立供两个页面模块共用（避免 preload 环）；②新增 economy.gd（311 行）——钱包 chip/每日签到页与领取/图集商店页与购买装备/收集进度统计与图鉴收集发放，全部经济域内聚；③page_router.gd 回归纯导航壳（215 行）：容器/nav/show/close/旅程/图鉴。game/session/ui_hud 的经济调用薄壳全部改向 ECONOMY，page_router 仅保留导航调用。
- Validation: 本地零测试（既定约束），静态自查已知 GDScript 3 陷阱（ALIGNMENT/offset/数组字面量索引）均无命中；全量验证由 CI 远端执行。

## 2026-09-10 (重构 Round BN：特殊模式会话拆出 special_session.gd)
- 审查：session.gd 690 行混装战役会话与 17 种特殊模式的进出/结算/判负。
- 变更：拆出 special_session.gd（227 行）——_start/_exit_special_mode、_resolve_special_clear、_record_special_completion、竞速判负、盲盒记忆五函数；session.gd 回归战役会话（467 行）：reset/裁决/时钟/暂停/复活/成就/翻翻乐与叠叠消的棋盘分支。依赖方向收敛为 session→special_session 单向（经 game 薄壳回调成就，无 preload 环）。
- 顺手修复潜伏崩溃：economy.collect_pair 达标时调用的 game._resolve_collect_clear 薄壳从未定义（collect 玩法达标即 crash，CI 未覆盖此路径）——全仓 game._* 薄壳完整性扫描工具化（python 静态对照），确认零缺失。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (重构 Round BO：主屏构建独立 home_screen.gd)
- 审查：ui_hud.gd 698 行中 build_main_ui 单函数约 330 行（背景/页头/统计卡/道具行/控制区/棋盘区/结算浮层/页面挂载），是文件膨胀主因。
- 变更：build_main_ui 原样迁入新模块 home_screen.gd（零逻辑改动，纯搬移——状态全在 game 节点上，refresh_ui 留守 ui_hud）。ui_hud 698→345 行，回归"主屏刷新+消息+控制+成就通知"职责；game.gd 的 _build_ui 薄壳改向 HOME_SCREEN。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (重构 Round BP：special_modes 数据表外置 special_modes_data.gd)
- 审查：special_modes.gd 582 行中约 250 行为纯数据表（17 个模式 DEFAULT_CONFIGS/MODE_LABELS/INTRO_TEXTS/EXTRA/RECORD_MODES）。
- 变更：数据表整体外置 special_modes_data.gd（239 行，纯 const）；special_modes.gd 回归纯逻辑（359 行）并保留同名转发 const（DATA.X），外部调用与测试零改动。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (重构 Round BQ：全仓死代码清理 + 修复 collect/flip 启动分支丢失)
- 审查：python 静态扫描全仓孤儿函数与重复定义。甄别后确认 10 个死薄壳（_cell_ring/_compress_path/_is_inside/_pad_board/_parse_node_key/_reconstruct_path/_create_board/_shuffle_array/_spawn_petal/_stop_bgm——均为模块化迁移后无人调用的遗留委托）予以删除；引擎回调与字符串信号连接（_spawn_petal 等误报源）逐一排除。
- **严重发现并修复**：BN 轮拆分剪切时丢失了 _start_special_mode 中 collect/flip 的 level 构建分支——选这两个玩法会错误启动成无尽模式棋盘（CI 纯逻辑探针未覆盖启动路径故未拦截）。分支已恢复，并在 page_probe 加防回归守卫：tray/collect/flip 启动后必须构建出带各自 mode_id 的 level。
- 保留：progression/audio_manager 的 5 个未接线 API（体量小且属公开接口，删除收益为零）。
- Validation: 本地零测试，薄壳完整性扫描零缺失，全量验证由 CI 远端执行。

## 2026-09-10 (重构 Round BR：战役结算提取 _settle_campaign_clear)
- 审查：_resolve_after_board_changed 约 115 行，战役 clear 的结算段（时间奖励/金币/星级/解锁推进/终局与中间关双分支）深嵌套内联。
- 变更：结算段原样提取为 _settle_campaign_clear(game)（含 is_final 判定收敛），裁决函数回归"分支判断 + 委派"形态。逻辑零改动（时间奖励/金币/星级/推进数值逐一对照）。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (测试补充 Round BS：三玩法结算路径单测)
- 审查：tray/collect/flip 的达标结算（纪录/花/结算面板）此前无直接断言，属测试盲区。
- 变更：page_probe 补结算探针——tray 清堆后纪录 ≥1200 分且 +🌸20 并显示结算面板；collect 目标填满后纪录并 +🌸20；flip 全消后 bonus 200 纪录并 +🌸20。三个特殊会话结算函数（special_session._resolve_*）行为全覆盖。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (测试补充 Round BT：全玩法启动冒烟探针 startup_probe.gd)
- 动机：BQ 轮抓到的 collect/flip 启动分支丢失与 BS 轮的叠叠消 new_round 缺失，同源于"玩法启动路径无测试"。本探针把 16 种特殊模式逐个真实启动：会话进入/PLAYING/时钟/状态载体（tray 120 张牌、flip 24 卡、collect 3 目标、frost 护甲、stack 埋层、chain 锁、fog 迷雾环、race 对数、moves 预算…）+ 干净退出回战役。
- Validation: 本地零测试，探针随 CI 远端执行。

## 2026-09-10 (测试补充 Round BU：special_modes_data 数据不变量)
- 动机：BP 轮拆出的 special_modes_data.gd（16 模式配置表）此前无专属测试；BQ 的解锁死锁（unlock_level 超出战役上限）正是这类数据问题。
- 变更：mode_meta_test 补数据不变量断言——16 个 config 的 mode_id/name/description 完整性、unlock_level ∈ [1,15]（防解锁死锁回归）、time_limit 非负、tray 牌堆可整除且容量充足、flip 对数为偶。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (测试补充 Round BV：tray 道具路径与 collect 自动过关探针)
- page_probe 补断言：叠叠消可点牌拾取入槽、撤销退牌耗次数、洗牌重排保持牌数；收集挑战填满目标后 collect_pair 自动触发结算并发放 🌸20（此前结算探针绕过了自动触发路径）。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (重构 Round BW：game.gd 薄壳区按域分组重排)
- 变更：game.gd 的 214 个函数按委托域分组重排（23 个域段，段首带 ═══ 分隔注释：生命周期/输入路由/战役会话/特殊模式会话/棋盘机制/棋盘视图/棋盘算法/主屏构建/主屏刷新/屏幕适配/弹窗面板/页面导航/经济/统计 HUD/道具/特效/计时器心跳/字体/玩法数据/进度模型/关卡表/配置装载/进度存取），零逻辑改动。
- 一致性保证：python 规范化行多重集合对比（git HEAD vs 重排后，排除新分隔注释行）= **完全一致（diff 0）**——纯重排零丢失。吸取 BN 教训：块级校验受注释归属漂移干扰，改用文件级规范化多重集合对比（终局校验）。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (重构 Round BX：game.gd 成员声明区按域分组 + economy 伴生探针)
- 变更：①game.gd 成员声明区（约 250 行）按域插入 11 组 ═══ 分组注释（数据配置/特殊会话/棋盘状态/战役进度/计分资源/时钟/成就/道具/机制网格/竞速/视图浮层），零逻辑改动；②page_probe 补 economy 伴生断言：钱包 chip 非负、超量收集在上限截断、达标自动结算。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (重构 Round BY：静态一致性审计固化 tools/shell_audit.py 并入 CI)
- 动机：BQ/BU 轮的一次性扫描（薄壳完整性/死代码/一致性）值得可重复执行——固化为 godot/tools/shell_audit.py（纯标准库，秒级）。
- 检查项：①薄壳完整性（全仓 game._x 调用必须在 game.gd 定义）；②信号 connect 目标存在性（game/self 两类）；③孤儿薄壳（警告级）；④Godot 4 语法残留（ALIGNMENT_CENTER / offset_top / offset_bottom）。ERROR 退出码 1 纳入 CI 硬门禁。
- 接入：deploy.yml 无头测试步骤末尾执行 (cd godot && python3 tools/shell_audit.py)。
- Validation: 本地与 CI 均四项全过（薄壳/connect/孤儿/G4 全干净）；全量测试由 CI 远端执行。

## 2026-09-10 (测试补充 Round BZ：签到曲线边界探针)
- page_probe 补签到曲线边界断言——断签重置（隔两天签到 streak 归 1 且发第 1 天奖励 5🌸）与第 7 天循环跨越（连续 7 天后再签发第 1 天奖励且 streak 继续累计 8）。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (测试补充 Round CA：daily 结算纪录 / endless 跨轮推进探针 + 修复 endless 卡轮)
- 审查：endless 清盘后 special_level 已换下一轮但**没有任何定时器触发 reset**——玩家停在 CLEARED 空盘，点重开还会把轮数清回 1（上线以来的真 bug）。
- 变更：①special_session._resolve_special_clear 的 endless 分支启动 level_advance_timer（1.2s 后经既有 _on_level_advance_timeout 进入下一轮，零新路径）；②page_probe 补 daily 结算纪录（落 today/连胜推进/最佳分）与 endless 跨轮探针（CLEARED→纪录轮数→advance 启动→下一轮跑分保留）。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (功能 Round CB：统计页 📊 数据)
- 变更：①新增统计页（page_router PAGE_STATS + _build_stats）——一页汇总 21 项数据：最佳总分/连击/樱花币/图鉴进度/连续签到/每日与无尽纪录/全部 13 个特殊模式最佳分（从 progression_state 现有字段读取，零新 schema）；②主页进度行新增「📊 数据」入口按钮（_on_stats_pressed → show_page("stats")，走标准页面导航）。
- 探针：page_probe 补 stats 页断言（页面打开/钱包与最佳分行/叠叠消与图鉴行）；tray 结算探针顺带验证 tray_best≥1200 落库后 stats 可见。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (功能 Round CB-2：氛围主题 🎨——小铺新增皮肤分区)
- 变更：①economy.gd 新增 THEMES 表（樱花粉默认/薄荷绿 40🌸/晴空蓝 40🌸/奶油白 40🌸/薰衣草 60🌸，浅色系保证正文可读）；②小铺页新增氛围主题分区（色卡预览+解锁/使用/使用中）；③购买扣 🌸 并入 owned_themes、使用即全屏背景换色（game.bg_rect 成员化）；④progression 新增 owned_themes/current_theme 全 schema，启动时应用已存主题。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-10 (测试补充 Round CC：var 孤儿审计固化 + THEMES 不变量)
- 审查：game.gd 122 个成员变量经扫描**零孤儿、零弱引用**——成员区质量确认干净。
- 变更：①shell_audit.py 新增 3.5 节 orphan member vars 检查（警告级，防未来迭代引入未使用成员）；②page_probe 补 THEMES 数据不变量断言（名称/价格/背景色合法）。
- Validation: 本地零测试，shell_audit 四项半检查全过，全量验证由 CI 远端执行。

## 2026-09-10 (测试补充 Round CD：限时挑战 Fever 边界探针)
- 审查：time_attack 的 fever 机制（连击≥5 → gain×1.5 + 额外 1 秒返还）此前零测试覆盖——限时模式的核心爽点无回归保护。
- 变更：page_probe 补 fever 边界探针——阈值前每次返还 3 秒、达到阈值后每次 4 秒（base 3 + combo bonus 1），以 config 驱动不硬编码。
- Validation: 本地零测试，全量验证由 CI 远端执行。

## 2026-09-11 (重构 Round CE：home_screen 主屏构建拆 section builder)
- 背景：代码质量治理首刀。home_screen.build_main_ui 单函数 401 行（全仓最大函数，此前从 ui_hud.gd 原样搬入），ui_hud.refresh_ui 126 行次之。
- 变更：①home_screen.build_main_ui 改为编排器，按原顺序调用 9 个 section builder（_build_root/_build_header_identity/_build_header_progress/_build_power_ups/_build_controls_flow/_build_progression_flow/_build_message_banner/_build_board_area/_build_floating_overlays/_finalize_build），逐段原样搬移，add_child 次序（z 序/布局）不变；共享 dropdown_style 局部提为 _dropdown_style() 工厂（两处 OptionButton 各得独立副本，视觉等价）；②ui_hud.refresh_ui 拆出 _subtitle_text（13 个特殊模式副标题链，else 改末尾 return，语义等价）、_refresh_status_chip、_refresh_action_buttons 三个助手，本体降到 52 行。对外 API（HOME_SCREEN.build_main_ui / UI_HUD.refresh_ui）零变化。
- 审计：新旧版本 game.* 成员赋值序列 45 条逐一相同；add_child 52 处次序相同（仅计划内 root→game.root_vbox 替换 6 处）；connect 15 处、锚点 preset 13 处次序相同；旧 refresh_ui 全部语句在新文件各恰好一次；shell_audit 六项全过。最大函数 401→63 行。
- Validation: 本地零引擎测试，全量验证由 CI 远端执行。

## 2026-09-12 (功能 Round CF：狂热/完美双新玩法 + Sophia 语音包)
- 玩法：①狂热模式（fever，15 关解锁）——10×8 盘 90 秒，连击 2 起全程 ×1.5 分且每消返 1 秒，复用 time_attack 的 fever 分支（cfg 键改 game.special_mode 动态取）；②完美模式（perfect，15 关解锁）——无时限 10×8 盘，失误 3 次判负（图案不合/路径不通两处 mismatch 分支经新薄壳 _register_perfect_miss 计数，副标题实时显示 失误x/3）。均走 build_classic_style_level 表驱动路径，RECORD_MODES/成就（燃烧吧小宇宙/零失误女神）/模式面板卡/统计页行/副标题全链配置化。
- 语音：Tingting TTS 本地生成 15 条甜系语音（216KB ogg，+6% 音高提亮），新模块 voice_lines.gd 照 cheers 范式（5 事件池 clear/fail/milestone/signin/achievement + game.voice_decks 洗牌牌堆）；6 个钩子点（战役/特殊过关、_fail_stage、连击里程碑、签到、成就通知）；audio_manager 新增 voice_enabled 设置（ConfigFile 持久化）+ 专属 AudioStreamPlayer；加载三级容错（导入资源 → 裸字节喂 AudioStreamOGGVorbis → 静默跳过，兼容无导入缓存的 headless 测试环境）；设置面板新增「语音」开关。
- 测试：mode_meta 16→18 configs、13→15 record、label 17→19 + 语音池不变量（5 事件覆盖/路径合法/15 个 clip 文件存在）；startup_probe 补 fever/perfect 启动断言 + perfect 三失误判负路径；panels_probe 模式卡 16→18；字体子集重跑（1007→1037 字符）。shell_audit 六项全过。
- Validation: 本地零引擎测试，全量验证由 CI 远端执行。
- 修复（同轮带出）：cheers.gd 自 CR 轮潜伏 bug——TIERS 用字符串键 min/lines，代码却以 TIER_MIN_KEY/TIER_LINES_KEY(0/1) 整型索引，每次查档必抛脚本错误，夸赞爆字从未真正显示（里程碑🌸正常）。改为字符串键直取；main 的 CI 日志可证该错误早于本轮存在（power_ups_probe 窗口）。mode_meta_test 面板行断言 16→18 行 + 样例字典补 fever/perfect 最佳分键 + endless 行索引 15→17。

## 2026-09-12 (布局 Round CG：棋盘占比 90%——工具栏并单行 + 底部预留瘦身)
- 背景：用户期望棋盘占屏幕 ~90%（此前竖屏 wrapper ≈83%）。竖屏已是 EXPAND_FILL 容器分权（CP 轮），天花板=header 两行按钮 + nav 预留。
- 变更：①progression 行整行并入 controls 工具栏（home_screen 删 _build_progression_flow，8 个 add_child 改挂 controls_flow；game.gd 删 progression_flow_container 成员；hud_layout 删其布局块）——竖屏隐藏下拉/跳转/清除后恰余 8 键；②竖屏按钮 58×28→44×28 + 字号 12（8×44+7×4=380 ≤ 390 恰好单行）；③卡片 64×36→60×34（数值字号 16→14）；④root/header 间距 4/3→2/2；⑤底部 nav 预留 40→20（棋盘居中留白吸收导航重叠，末行不遮 guard 仍在：6 列关卡末行底 ≈765 < nav 顶 804）。
- 预算：header 98→64px，wrapper ≈ 844-64-4-20 = 756 = **89.6%**。panels_probe ratio 断言 0.78→0.88 + 新增合并行结构断言（modes/settings 按钮父容器=controls_flow）。
- Validation: 本地零引擎测试，shell_audit 六项全过，全量验证由 CI 远端执行。
- CG 实测更正（4ad2ac8 上线值）：首版预算偏差被 panels_probe 布局转储抓出——工具栏实为 9 键（漏数 🏆 成就）换行 2×34px、卡片行 47px（value_holder 硬编码 88×24+标题行）。终版：卡片去标题改数值药丸（22px，holder 60×22）、工具栏 9 键 44×26 两行行距 2（56px）、achievements_button 成员化、底部预留 10px。**实测 wrapper 746/844 = 88.4%**（断言 ≥88%），末行瓷砖 720 < 导航顶 790（70px 余量）。探针新范式：布局断言前 yield 两帧量容器重排后的真实尺寸；DBG 转储可留探针内做回归取证。

## 2026-09-12 (布局 Round CH：冲线 90%——📊/🏆 入口迁入设置面板)
- 背景：用户拍板前按推荐方案实施（88.4% 的剩余物理底线 = 工具栏 9 键两行；用户未选择，采用功能零损失方案）。
- 变更：①工具栏瘦身为 7 键（提示/自动消/洗牌/暂停/重开/🎮玩法/⚙️设置），竖屏 44×26 单行 12px；②📊 数据统计 / 🏆 成就图鉴 两入口迁入 ⚙️ 设置面板（先关设置再打开目标，复用 _on_stats_pressed/_on_achievements_pressed，零新路径）；③stats_button/achievements_button 成员删除，新增 _on_settings_stats_entry/_on_settings_achievements_entry 薄壳。
- 预算：header 22+2+26 = 50px → wrapper ≈ 780/844 = 92.4%。panels_probe ratio 断言 0.88→**0.90**（用户原话值）+ 设置面板两入口存在性断言（遍历 Button 文本）。
- Validation: 本地零引擎测试，shell_audit 六项全过，字体子集无新增字符（1037 不变），全量验证由 CI 远端执行。

## 2026-09-12 (重构 Round CI：玩法分发收敛表驱动——副标题表/道具装载表/特殊会话谓词)
- 动机：用户目标「结构重构提升质量，为项目做大做准备」。摸底发现 game.gd 函数层已收敛（1074 行中仅 4 个 >6 行胶水函数），真正的增长阻力是 62 处散落 13 个脚本的 `special_mode == "xxx"` 字符串比较——每加一个玩法要满仓找分支。
- 变更：①新增 `game._is_special_session()` 谓词薄壳，收敛 10 处 `special_mode != ""` / `== ""` 裸比较（ui_hud/ui_panels×3/progress_store/page_router/game_input/session×2/powerups）；game.gd 内部 2 处本地直读保留；②副标题 15 分支 elif 链改表驱动——special_modes_data 新增 SUBTITLE_RECORDS（11 个纯纪录模式 → `<mode>_best_score` 字段），标签复用 mode_label()，daily/endless/moves/perfect 专属文案与 tray/collect/flip 战役回落留 ui_hud；③特殊会话道具装载 ternary 改 SPECIAL_LOADOUT 三表（BASE 全员/EXTRA 按模式/OVERRIDE 覆盖如 hell），新玩法加行即用。
- 守卫：mode_meta_test 新增两条增长不变量——每个无专属文案的 config 模式必须有 SUBTITLE_RECORDS 行（键名须符合 `<mode>_best_score` 且不得引用未知模式）；LOADOUT EXTRA 只能指向真实模式、OVERRIDE 只能改已知发放键。今后加玩法漏配副标题/道具直接 CI 红。
- 审计：shell_audit 六项全过；副标题逐字等价（11 分支标签/键与 mode_label+SUBTITLE_RECORDS 产出全等，python 静态对照）；道具装载等价（18 模式 × 8 键新旧全等模拟）；game.gd 净 +3 行（谓词薄壳），ui_hud 32 行净减。
- Validation: 本地零引擎测试（既定约束），全量验证由 CI 远端执行。
