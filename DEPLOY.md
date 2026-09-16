# 连连看 H5 部署说明

## 项目说明

这是一个基于 **Godot 3.5** 开发的连连看 H5 游戏，可以直接在浏览器中运行。

## 文件结构

```
public/                      # H5游戏入口目录
├── index.html              # 浏览器兼容性检测页
└── godot/                  # Godot Web导出文件
    ├── index.html          # Godot游戏主页面
    ├── index.js            # Godot JavaScript运行时
    ├── index.wasm          # Godot WebAssembly编译文件
    ├── index.pck           # 游戏资源包
    └── ...                 # 其他辅助文件
```

## 本地测试

### 方式1：使用Python简单HTTP服务器

```bash
cd public
python3 -m http.server 8080
```

然后浏览器访问：`http://localhost:8080`

### 方式2：使用Node.js http-server

```bash
npm install -g http-server
cd public
http-server -p 8080
```

### 方式3：使用VS Code Live Server插件

在VS Code中安装Live Server插件，右键点击 `public/index.html` 选择 "Open with Live Server"

## 重新导出游戏

如果修改了Godot项目，需要重新导出：

```bash
# 进入Godot项目目录
cd godot

# 使用Godot命令行导出（需要Godot 3.5已安装）
godot --export-release "Web" ../public/godot/index.html
```

## 部署到服务器

### 静态文件托管

将 `public/` 目录下的所有文件上传到静态文件服务器：

- **GitHub Pages**: 将public目录内容推送到gh-pages分支
- **Netlify**: 拖拽public目录到Netlify部署区域
- **Vercel**: 使用vercel CLI部署public目录
- **AWS S3**: 上传public目录内容到S3 bucket
- **阿里云OSS**: 上传public目录内容到OSS bucket

### Nginx配置示例

```nginx
server {
    listen 80;
    server_name lianliankan.example.com;
    root /var/www/lianliankan/public;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # 启用gzip压缩
    gzip on;
    gzip_types text/plain text/css application/javascript application/wasm;
}
```

## 注意事项

1. **WebGL支持**: 用户浏览器需要支持WebGL
2. **文件大小**: `index.wasm` (~37MB) 和 `index.pck` (~25MB) 较大，建议启用gzip压缩
3. **跨域**: 如果使用CDN，注意配置CORS头
4. **移动端**: 已适配移动端触摸操作

## 浏览器兼容性

- Chrome 57+
- Firefox 51+
- Safari 15+
- Edge 16+

## 游戏功能

- 15个关卡挑战
- 14套主题皮肤
- 体力系统
- 每日签到
- 排行榜
- 商店系统

## 技术栈

- 引擎: Godot 3.5 LTS
- 导出: HTML5/WebGL
- 语言: GDScript

## 配置入口

- 关卡: `godot/data/campaign.json`
- 数值: `godot/data/tuning.json`
- 主题: `godot/data/icon_sets.json`
- 经济: `godot/data/economy.json`
- 商店: `godot/data/shop.json`

## 安卓 APK 构建（CI 自动出包）

`.github/workflows/android-build.yml` 在 push main 或手动触发（workflow_dispatch）时构建调试版 APK：

1. 下载 Godot 3.6.2 headless + 官方导出模板中的 Android 模板 APK（与 Web 流水线同款缓存机制）；
2. CI 内用 `keytool` 生成一次性 debug keystore，写入 `~/.config/godot/editor_settings-3.tres`
   ——`export_presets.cfg` 的 keystore 字段刻意留空，Godot 3.x headless 导出在
   `keystore/debug` 为空时自动回退到 editor settings 的 `export/android/debug_keystore*`（源码级确认的官方回退链）；
3. `--export-debug "Android"` 导出调试包，Sanity 检查清单（manifest / 双架构 so）后以 Artifact 上传，保留 30 天。

产物获取：仓库 → Actions → 对应 run → 底部 Artifacts 下载 `SophiaLianliankan-debug-<sha>`。

- 包名 `cn.zhaixingren.lianliankan`，竖屏 + 沉浸式全屏，armeabi-v7a + arm64-v8a 双架构。
- 调试包签名是 CI 每次临时生成的，仅用于装机测试，不可上架；正式签名需把 release keystore
  放入 repo secrets 后改走 release 导出（后续任务）。
- 云同步零改动：`server_sync.gd` 在非 Web 平台走原生 `HTTPRequest` 分支（`7783efc` 保留），
  端点用常量 `DEFAULT_API_BASE`（已指向线上）。
- targetSdk 说明：预构建模板导出的 targetSdk 跟随 Godot 3.6 模板默认值；要上架 Google Play
  （现要求 targetSdk 34+）需开启 gradle 构建并实测提升 targetSdk，属后续任务。
- 本地导出：Godot 编辑器「项目 → 导出 → Android」按官方文档配置一次 debug keystore 即可用同一 preset。
