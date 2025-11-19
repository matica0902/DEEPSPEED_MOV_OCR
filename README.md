# MLX DeepSeek-OCR Railway 部署

基于 MLX 的 DeepSeek-OCR 应用，支持在 Railway 平台上部署。

## 📁 项目结构

```
├── app.py              # Flask 应用主文件
├── requirements.txt    # Python 依赖
├── Dockerfile         # Docker 构建配置
├── railway.json       # Railway 部署配置
├── .dockerignore      # Docker 忽略文件
├── templates/         # HTML 模板
│   └── index.html
└── static/           # 静态文件
    └── app.js
```

## 🚀 Railway 部署步骤

### 1. 连接 GitHub 仓库

1. 访问 [Railway Dashboard](https://railway.app)
2. 点击 "New Project"
3. 选择 "Deploy from GitHub repo"
4. 授权并选择此仓库

### 2. 设置环境变量

在 Railway 项目设置中添加：

- `MLX_USE_CPU=1` - 启用 CPU 模式
- `PYTHONUNBUFFERED=1` - Python 输出缓冲
- `PORT` - Railway 会自动设置

### 3. 部署

Railway 会自动检测 `railway.json` 并开始构建部署。

## 📝 功能特性

- ✅ 支持图片 OCR 识别
- ✅ 支持 PDF 文档处理
- ✅ CPU 模式优化
- ✅ 并发控制
- ✅ 健康检查端点

## 🔗 API 端点

- `GET /` - 主页面
- `GET /api/health` - 健康检查
- `POST /api/ocr` - OCR 处理

## 📄 许可证

MIT License

