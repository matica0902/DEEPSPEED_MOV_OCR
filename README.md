# MLX DeepSeek-OCR Hugging Face Spaces 部署

基于 MLX 的 DeepSeek-OCR 应用，支持在 Hugging Face Spaces 平台上部署。

## 📁 项目结构

```
├── app.py              # Flask 应用主文件
├── requirements.txt    # Python 依赖
├── Dockerfile         # Docker 构建配置（Hugging Face Spaces 使用）
├── app_config.yaml    # Hugging Face Spaces 配置
├── .dockerignore      # Docker 忽略文件
├── start.sh           # 本地开发启动脚本（可选）
├── startback.sh       # 本地开发备用启动脚本（可选）
├── templates/         # HTML 模板
│   └── index.html
└── static/           # 静态文件
    └── app.js
```

> **注意**：`start.sh` 和 `startback.sh` 仅用于本地开发，Hugging Face Spaces 部署时会自动使用 `Dockerfile` 中的 `CMD` 指令，不会使用这些脚本。

## 🚀 Hugging Face Spaces 部署步骤

### 1. 创建 Hugging Face Space

1. 访问 [Hugging Face Spaces](https://huggingface.co/spaces)
2. 点击 "Create new Space"
3. 填写信息：
   - **Space name**: 你的应用名称（如 `mlx-ocr`）
   - **SDK**: 选择 **Docker**
   - **Hardware**: 选择 **CPU upgrade**（$30/月，推荐）或 **CPU basic**（免费，但资源有限）
   - **Visibility**: Public 或 Private

### 2. 连接 GitHub 仓库

1. 在 Space 设置中选择 "Repository"
2. 选择 "Connect to existing repository"
3. 授权并选择你的 GitHub 仓库：`matica0902/DEEPSPEED_MOV_OCR`
4. Hugging Face 会自动检测 `app_config.yaml` 和 `Dockerfile`

### 3. 自动部署

- Hugging Face Spaces 会自动检测配置并开始构建
- 首次部署需要 5-10 分钟（下载依赖和模型）
- 部署完成后会提供一个公开 URL

### 4. 配置说明

**app_config.yaml** 已配置：
- ✅ 固定端口：7860（Hugging Face Spaces 标准端口）
- ✅ CPU 升级硬件（$30/月）
- ✅ 环境变量：`MLX_USE_CPU=1`
- ✅ 持久化存储：10GB（用于模型缓存）

## 💻 本地开发

如果要在本地运行（笔记本电脑），可以使用启动脚本：

```bash
# 使用启动脚本（自动激活虚拟环境、检查依赖、寻找可用端口）
chmod +x start.sh
./start.sh
```

> **Hugging Face Spaces 部署说明**：Hugging Face Spaces 会自动使用 `Dockerfile` 中的 `CMD ["python", "app.py"]` 启动应用，不会执行 `start.sh`，因此启动脚本的存在不会影响部署。

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

## 💰 费用说明

### Hugging Face Spaces 定价

- **CPU Basic**（免费）：
  - 2 vCPU
  - 16GB RAM
  - 适合测试，但可能资源不足

- **CPU Upgrade**（$30/月）：
  - 4 vCPU
  - 32GB RAM
  - 推荐用于生产环境

## 📄 许可证

MIT License
