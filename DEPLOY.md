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
