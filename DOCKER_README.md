# 🐳 Docker 部署指南

## 📋 快速開始

### 前置要求

1. **Docker** 已安裝
2. **NVIDIA Docker**（如果使用 GPU）
   ```bash
   # 安裝 NVIDIA Container Toolkit
   # Ubuntu/Debian
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
   curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
   sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
   sudo systemctl restart docker
   ```

### 構建鏡像

```bash
# 使用預設 Dockerfile (Linux + CUDA)
docker build -t mlx-deepseek-ocr:latest .

# 或使用 macOS 版本（有限制）
docker build -f Dockerfile.macos -t mlx-deepseek-ocr:macos .
```

### 運行容器

#### 方法 1：直接運行

```bash
# Linux + CUDA (推薦)
docker run --gpus all \
    -p 5000:5000 \
    -v $(pwd)/uploads:/app/uploads \
    -v mlx-model-cache:/root/.cache/huggingface \
    mlx-deepseek-ocr:latest

# macOS (CPU 模式，有限制)
docker run \
    -p 5000:5000 \
    -v $(pwd)/uploads:/app/uploads \
    -v mlx-model-cache:/root/.cache/huggingface \
    mlx-deepseek-ocr:macos
```

#### 方法 2：使用 docker-compose

```bash
# 啟動服務
docker-compose up -d

# 查看日誌
docker-compose logs -f

# 停止服務
docker-compose down
```

---

## ⚠️ 重要限制

### MLX 框架限制

1. **Linux + CUDA**：
   - ✅ MLX 0.20.0+ 支援 CUDA
   - ⚠️ 需要確認 `mlx-vlm==0.3.5` 是否支援 CUDA
   - ⚠️ 需要實際測試驗證

2. **macOS Docker**：
   - ❌ 無法使用 Metal GPU
   - ⚠️ MLX 在 Linux Docker 中可能無法運行
   - ✅ **建議：macOS 上直接運行，不使用 Docker**

3. **Linux CPU 模式**：
   - ❌ MLX 不支援 Linux CPU 模式
   - ❌ 必須使用 CUDA（NVIDIA GPU）

---

## 🧪 測試驗證

### 1. 檢查 MLX 是否可用

```bash
# 進入容器
docker exec -it mlx-ocr-api bash

# 測試 MLX
python3 -c "import mlx.core as mx; print('MLX OK')"
python3 -c "from mlx_vlm import load; print('mlx-vlm OK')"
```

### 2. 檢查 API 狀態

```bash
# 從主機測試
curl http://localhost:5000/api/status

# 預期回應
# {"model_loaded": false, "ready": false}
```

### 3. 測試 OCR 功能

```bash
# 上傳圖片測試
curl -X POST http://localhost:5000/api/ocr \
    -F "file=@test_image.jpg"
```

---

## 📊 資源配置

### 記憶體需求

```yaml
# docker-compose.yml
deploy:
  resources:
    limits:
      memory: 8G
    reservations:
      memory: 4G
```

### GPU 配置

```yaml
# docker-compose.yml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

---

## 🔧 故障排除

### 問題 1：MLX 無法導入

**錯誤：**
```
ModuleNotFoundError: No module named 'mlx'
```

**解決方案：**
1. 確認使用 CUDA 版本的 MLX
2. 檢查 Dockerfile 中的 MLX 安裝命令
3. 確認基礎鏡像包含 CUDA 支援

### 問題 2：GPU 不可用

**錯誤：**
```
RuntimeError: CUDA not available
```

**解決方案：**
```bash
# 檢查 NVIDIA Docker
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# 如果失敗，安裝 NVIDIA Container Toolkit
```

### 問題 3：模型下載失敗

**解決方案：**
```bash
# 檢查網路連接
docker exec mlx-ocr-api curl -I https://huggingface.co

# 手動下載模型到 volume
docker exec mlx-ocr-api python3 -c "from mlx_vlm import load; load('mlx-community/DeepSeek-OCR-4bit')"
```

---

## 📝 相關文件

- `DOCKER_ANALYSIS.md` - 詳細的 Docker 化分析
- `Dockerfile` - Linux + CUDA Dockerfile
- `Dockerfile.macos` - macOS Dockerfile（有限制）
- `docker-compose.yml` - Docker Compose 配置

---

## 🎯 推薦方案

### 開發環境
```bash
# macOS 上直接運行（不使用 Docker）
cd /path/to/project
source venv/bin/activate
python3 app.py
```

### 測試環境
```bash
# Linux + CUDA Docker
docker-compose up -d
```

### 生產環境
```bash
# 混合架構
# - Web Server: Linux Docker
# - OCR API: macOS 直接運行（利用 Metal GPU）
```

---

**注意：請先驗證 MLX CUDA 支援狀態，再進行生產部署！**

