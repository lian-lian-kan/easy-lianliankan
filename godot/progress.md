
## 2026-09-30 (Round 37：线上 bug 根修——禁用按钮「幽灵字」的真凶是 Godot 3 主题项名)

- Context: 用户线上报障「玩法大厅字体颜色跟背景冲突，什么都看不到」。本地样张同现象复现：玩法大厅除每日挑战外的玩法卡、小铺「使用中」键，全是白卡上的一行幽灵字。此前两轮（R31 棋盘褪色、R32 次级按钮禁用字色）都把机理误判成「Godot 3 画 disabled 时压 alpha」，本轮才挖到真凶。
- **根因（无头探针实证）**：Godot 3 Button 禁用字色的主题项叫 **`font_color_disabled`**，引擎默认值 `Color(0.9, 0.9, 0.9, 0.2)`——两成透明幽灵白；而全库写的 `font_disabled_color` 是 **Godot 4 的名字**，`add_color_override`/`theme.set_color` 都是静默空操作（探针对拍：读不存在项返回黑 dummy，读 `font_color_disabled` 返回引擎默认幽灵白）。所以每次「给 disabled 设了可读字色」都从未生效，禁用按钮一路渲染引擎默认幽灵白压白卡=隐形。
- **三层修复**：①全局主题默认 `theme.set_color("font_color_disabled", "Button", 8f6b80)`（ui_fonts.init_theme，任何 disabled 按钮兜底可读）；②`_apply_button_font_colors` 按面亮度推导禁用字色（浅底粉字/深底白字，与四态同规则）；③错名调用点改正（ui_style.style_secondary_button、economy 使用中键），实心玫瑰主按钮（style_dialog_buttons）显式白字禁用态。锁定玩法卡语义保持 disabled（不可点+弱化墨色），与旅程锁定节点同语言。
- **连带修测试结构 bug**：ui_style_test 的 quit(0)/quit(1) 块在 Round 35 追加糖果面断言时被顶到了文件中部——糖果面 9 条断言全在 quit 之后**从未执行**（audit 第 8 项只管 quit 诚实性、管不到 quit 后死代码）。quit 块移至文件末尾，断言复活。
- **像素级验证**：从上一提交抽出修复前样张与修复后同区域采样——修复前最暗像素亮度 0.89（#dfe4e7，幽灵白实锤）、修复后 0.355（满对比文字）；小铺「使用中」（真实 disabled）修复后样张清晰可读，disabled 渲染路径直接视觉验证。
- Validation: 受影响探针先行全绿（ui_style/ui_fonts/economy/page_router/page_probe/panels/start_screen）；全量 57 项 CI 清单 rc 全 0；port_shell_audit clean；ui_style_test 补 2 条禁用字色亮度推导断言、ui_fonts_test 补全局主题默认断言。零新增渲染字符（仅注释与既有文案）。推送后待 CI deploy 回填。
