# 连连看 H5 游戏

一个基于 TypeScript + React 开发的移动端连连看游戏。

## 🎮 游戏特性

- **核心玩法**：点击两个相同的水果图标进行消除
- **路径算法**：支持最多2次拐弯的连通路径
- **智能提示**：自动寻找可消除的配对
- **无解处理**：自动检测无解状态并重新排列
- **移动优化**：响应式设计，触摸友好

## 🚀 在线体验

- **GitHub Pages**: https://lian-lian-kan.github.io/demo/
- **本地开发**: http://localhost:50511/

## 🛠️ 技术栈

- **前端框架**: React 19 + TypeScript
- **构建工具**: Vite 7
- **测试框架**: Vitest
- **部署方式**: GitHub Pages + GitHub Actions

## 📱 游戏说明

1. 点击两个相同的水果图标
2. 如果路径可达（最多2次拐弯），则消除配对
3. 消除所有配对即可获胜
4. 使用"提示"按钮获取可消除的配对
5. 使用"重开"按钮重新开始游戏

## 🧪 开发

```bash
# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 运行测试
npm run test

# 构建生产版本
npm run build
```

## 📦 项目结构

```
src/
├── game/
│   ├── engine.ts      # 核心游戏逻辑
│   └── engine.test.ts # 单元测试
├── components/
│   ├── Board.tsx      # 游戏棋盘组件
│   └── GitHubIcon.tsx # GitHub图标组件
├── utils/
│   └── tileIcons.ts   # 水果图标映射
├── App.tsx           # 主应用组件
└── main.tsx          # 应用入口
```

## ⚙️ GitHub Pages 配置说明

如果GitHub Actions构建失败，请确保在仓库设置中：

1. 进入 Settings → Pages
2. 将 Source 设置为 "GitHub Actions"
3. 确保 Actions 权限已启用 (Settings → Actions → General)
4. 推送代码后会自动触发部署
