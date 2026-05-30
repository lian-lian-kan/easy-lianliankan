# 连连看 H5

基于 Godot 3.5 开发的 Web 版连连看游戏，可直接在浏览器中运行。

## 🎮 在线体验

打开 `public/index.html` 即可在浏览器中运行游戏。

## 技术栈

- **引擎**: Godot 3.5 LTS
- **平台**: Web (HTML5/WebGL)
- **语言**: GDScript
- **导出**: Godot HTML5 Export

## 📁 项目结构

```
├── godot/                  # Godot 项目源码
│   ├── data/              # 游戏配置数据
│   ├── docs/              # 设计文档
│   ├── scenes/            # 场景文件
│   ├── scripts/           # GDScript 脚本
│   └── project.godot      # 项目配置
├── public/                # H5 游戏入口
│   ├── index.html         # 浏览器兼容性检测页
│   └── godot/             # Godot Web 导出文件
│       ├── index.html     # 游戏主页面
│       ├── index.js       # JavaScript 运行时
│       ├── index.wasm     # WebAssembly 编译文件
│       └── index.pck      # 游戏资源包
├── DEPLOY.md              # 部署说明文档
└── README.md              # 项目说明
```

## 🚀 快速开始

### 方式 1：本地运行（推荐）

```bash
cd public
python3 -m http.server 8080
```

浏览器访问：`http://localhost:8080`

### 方式 2：使用 Node.js

```bash
npm install -g http-server
cd public
http-server -p 8080
```

### 方式 3：Godot 编辑器调试

1. 下载 [Godot 3.5](https://godotengine.org/download/3.x/)
2. 打开 `godot/project.godot`
3. 按 F5 运行

## 🎯 游戏功能

### 核心玩法
- ✅ 15 个精心设计的关卡
- ✅ 4 种游戏模式（经典、冲刺、连击、耐力）
- ✅ 14 套主题皮肤
- ✅ 连击系统（最高 8 连击）
- ✅ 道具系统（8 种道具）

### 留存系统
- ✅ 体力系统（5 点上限，20 分钟恢复）
- ✅ 每日签到（7 天循环奖励）
- ✅ 金币经济系统
- ✅ 排行榜（总分、速通、无尽模式）
- ✅ 商店系统

## 📦 重新导出

修改游戏后，重新导出 Web 版本：

```bash
cd godot
godot --export-release "Web" ../public/godot/index.html
```

## 🌐 浏览器支持

- Chrome 57+
- Firefox 51+
- Safari 15+
- Edge 16+

需要 WebGL 支持。

## 🧩 H5 兼容增强（2026-03）

当前 Web 入口已加入以下兼容增强：

- `viewport-fit=cover` + `safe-area` 适配（刘海屏/底部手势条）。
- 动态视口高度同步（`visualViewport` + `orientationchange`），减少移动端地址栏伸缩导致的画面跳动。
- WebGL 上下文丢失恢复提示（含“刷新重试”按钮）。
- 移动端自动 DPR 封顶（默认上限 `2.0`，降低高分屏卡顿或黑屏概率）。
- 启动加载看门狗（长时间无进度时给出重试提示）。

### 启动参数

- 强制指定 DPR（可选）：
  - `http://localhost:50511/demo/godot/index.html?dpr=1.5`
  - 不传时，移动端默认自动上限 `2.0`。

### 服务器跨源隔离策略

`server.js` 默认是“兼容优先”，不强制 COOP/COEP。  
若你要启用跨源隔离（比如后续启线程）：

```bash
ENABLE_CROSS_ORIGIN_ISOLATION=1 node server.js
```

## 📚 相关文档

- [部署说明](DEPLOY.md) - 详细部署指南
- [设计文档](godot/docs/game_design_doc.md) - 游戏设计文档

## 📄 License

MIT License
