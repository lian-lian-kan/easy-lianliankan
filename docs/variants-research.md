# 连连看玩法变体调研与集成路线（2026-09-13）

目标：把主流连连看产品的玩法变体全部收编。调研来源：4399/7k7k 宠物连连看系列、
Onet Connect Classic、Dream Pet Link 1/2、Jolly Jong Connect、连连看4（llk.cn）、
欢乐连连看（经典/无尽/双人 + 麻将元素）、小米连连看（传统/冒险/挑战）、
宠物连连看3D/Mahjongg Dimensions（3D 旋转）、连连看对战（联网 2P）。

## 现状对照（原 19 种 → 现已 25 种，三轮集成全部落地 2026-09-13）

| 业界变体 | 我们对应 | 状态 |
|---|---|---|
| 经典 Onet（≤2 拐弯连线） | 战役 15 关 | ✅ |
| 闯关冒险 | 战役 + 星级 | ✅ |
| 无限/无尽 | endless | ✅ |
| 争分夺秒/消除加时 | time_attack | ✅ |
| 步数限制 | moves | ✅ |
| 记忆翻牌（Dream Pet Link 变体） | memory/flip | ✅ |
| 冰冻两次消除 | frost | ✅ |
| 无时限休闲 | zen | ✅ |
| 高压速通 | hell | ✅ |
| 人机竞速（连连看对战的单机近似） | race（vs 机器人） | ✅ |
| 叠层/麻将多层 | stack | ✅ |
| 重力下落 | gravity | ✅ |
| 迷雾 | fog | ✅ |
| 锁链 | chain | ✅ |
| 连击激励/狂热加成 | fever + cheers | ✅ |
| 零失误挑战 | perfect | ✅ |
| 羊了个羊式三消槽 | tray | ✅ |
| 收集目标 | collect | ✅ |
| 每日一题（全网同盘） | daily | ✅ |
| **石头/障碍牌（宠物连连看经典）** | — | 🆕 rock 障碍模式 |
| **炸弹倒计时牌** | — | 🆕 defuse 拆弹行动 |
| **指定连消（必须先消高亮对）** | — | 🆕 target |
| **变脸（图案周期变化）** | — | 🆕 shift |
| **行列滑移（消除后盘面平移）** | — | 🆕 slide |
| **守塔/大战僵尸（消除即攻击）** | — | 🆕 defense |
| 联网双人对战/合作 | race（人机） | ⏸ 需联网基建，另立项 |
| 3D 旋转方块（Mahjongg Dimensions） | — | ⏸ 需 3D 渲染，另立项 |
| 六边形棋盘 | — | ⏸ 路径算法重写，另立项 |

主题皮肤类（宠物/果蔬/宝石…）由图集系统覆盖（14 套图集），不算独立玩法。

## 入口编排

所有特殊玩法走 🎮 玩法面板统一入口（卡片式、按解锁等级开锁），
每个玩法一张独立卡片 = 独立入口；解锁曲线：rock 第 14 关解锁、defuse 第 15 关。
统计页与副标题全链自动收录（mode_meta 增长守卫兜底）。

## 三轮落地

- Round 1：rock 障碍 + defuse 拆弹（本提交）
- Round 2：target 指定连消 + shift 变脸
- Round 3：slide 滑移 + defense 守卫 + 面板分类分组

## 第二轮调研与可行性结论（2026-09-13，Round CO'）

第二轮联网调研（Onet Connect Plus / Onet Puzzle 各类 gravity modes / Tile Frost-Match / 7k7k 六边形旋转消除 / Hex Puzzle 等）结论：

- **已收编（Round CO'）**：👫 **同屏对战 duel**——双人轮流消除，成功继续、失败换人，清盘分高者胜（欢乐连连看双人模式的离线化：联网对战需服务器基建，同屏轮流保留对战博弈）；🔟 **合十消 sum10**——两张数字牌相加为 10 即可消（1-9/2-8/3-7/4-6/5-5），引擎配对规则经 board_engine.values_match 模式化，提示/寻路/洗牌全链感知。
- **3D 旋转（Mahjong Dimensions 类）**：不可行——渲染层是 GridContainer 方格按钮矩阵，3D 旋转骰面需要 3D 场景/自定义投影渲染，与 2D 竖屏架构冲突；按用户决策跳过。已有叠层模式（stack）承载「多层棋盘」体验。
- **六边形棋盘（hex connect）**：2D 可行但需另立项——寻路 BFS 的 visited/方向扩展按 4 方向硬编码（六邻接为 6 方向且转向语义不同），渲染 GridContainer 只支持方格矩阵，powerup 炸弹 3x3/镜像生成等十余处隐含方格假设；改动横跨 board 域全部模块。已记录改造清单：①board_engine 方向表参数化+六邻接 offset-row 邻接函数 ②board_view 自由布局渲染器 ③生成器镜像逻辑六边形化。
- **玻璃双层牌（frost 变体）**：与既有冰雪模式机制重复，不重复收编。

## 第三轮扩展（2026-09-23，规则族 + 肉鸽 + Boss，25 → 32 种）

架构成熟后的第三轮扩展（注册表一行声明 + values_match 规则谓词 + interactions 域，
见 progress.md Round 29）：

- **合十家族（规则级）**：🎱 **差一消 diff1**（|a-b|=1 即消，牌面拆 (t, t+1)）与
  🎲 **倍数消 mult**（成倍即消，牌面取 2-4/2-6/2-8/3-6/3-9/4-8 除子集，1/5/7 不发）——
  与 sum10 共用 `values_match` 谓词通道与 `apply_rule_faces` 牌面通道，提示/寻路/洗牌全链自动感知。
- **♾️ 肉鸽无尽**：endless 每轮过关后进入「轮间休整」三选一增益——整体复用攀登树的
  tree_buffs 基建（roll_offer/面板/会话钩子），无时钟故排除 time_gift/tool_breeze 两个
  时间类 buff；跳过也算一种选择，挑选/跳过后才踢推进计时器。
- **👾 Boss 挑战**：在 defense 骨架上长出——复用逼近节奏成员当狂暴时钟，每消一对打一下；
  血线 2/3、1/3 各狂暴一次（逼近提速 + 变脸盘面干扰，swap 保 parity 可解性不变）；
  打空血量即时结算（盘面无需清空），经 game 壳进 special_session 结算通路。
- **联网对战**：立项评估成文 docs/online-battle-design.md（MVP=HTTP 轮询同盘竞速，
  复用 race 骨架；WebSocket 升级留二期），未实施。
- **解锁曲线真 bug 修复**：slide/defense/sum10/duel 的 unlock_level 16/17 超出战役
  15 关的可达上限（highest_unlocked_level_index 钳制 ≤14，解锁检查最高 15）——四个玩法
  正常进度下永远解锁不了；全部压回 ≤15，mode_meta_test 守卫改为从战役表长度推导上限。
