# 🐳 Docker 化分析報告：MLX DeepSeek-OCR

## 📋 執行摘要

### ✅ **結論：可以 Docker 化，但有重要限制**

| 項目 | 狀態 | 說明 |
|------|------|------|
| **Docker 化可行性** | ✅ **可行** | 代碼結構適合容器化 |
| **Linux 支援** | ⚠️ **部分支援** | 需要 CUDA + MLX CUDA 支援 |
| **macOS Docker** | ⚠️ **受限** | 無法使用 Metal GPU |
| **雲端部署** | ⚠️ **需確認** | 依賴 MLX CUDA 支援 |

---

## 🔍 代碼分析結果

### 1. MLX 框架限制 ⚠️

#### 當前配置
```python
# app.py:5-6
os.environ['MLX_USE_CPU'] = '1'
os.environ['METAL_DEVICE_WRAPPER_TYPE'] = '1'
```

#### 關鍵發現

**MLX 框架演進：**
- ✅ **2024 年更新**：MLX 新增對 NVIDIA CUDA 的支援
- ⚠️ **mlx-vlm 支援**：需要確認 `mlx-vlm==0.3.5` 是否支援 CUDA
- ❌ **macOS Docker**：即使使用 Docker，也無法使用 Metal GPU

**運行模式：**
```
macOS (Apple Silicon)
├── Metal GPU 模式 ✅ 最佳性能
└── CPU 模式 ✅ 可用但較慢

macOS (Intel)
└── CPU 模式 ✅ 可用但很慢

Linux (NVIDIA GPU)
├── CUDA 模式 ⚠️ 需確認 mlx-vlm 支援
└── CPU 模式 ❌ MLX 不支援 Linux CPU

Linux (無 GPU)
└── ❌ 不支援
```

---

### 2. 依賴項分析

#### 核心依賴
```python
# app.py:33-34
import mlx.core as mx
from mlx_vlm import load, generate
```

#### 圖像處理依賴
```python
# app.py:22, 28-29
from PIL import Image  # Pillow
import cv2             # opencv-python
import numpy as np     # numpy
```

#### PDF 處理
```python
# app.py:15
import fitz  # PyMuPDF
```

#### 可選依賴
```python
# app.py:184
from rembg import remove  # 背景移除（可選，有 fallback）
```

#### 多進程處理
```python
# app.py:26, 71
import multiprocessing
model_loaded_status = multiprocessing.Value('b', False)
```

**Docker 影響：**
- ✅ 所有依賴都可以在 Docker 中安裝
- ⚠️ `multiprocessing` 在 Docker 中需要正確配置
- ✅ `rembg` 是可選的，有 fallback 機制

---

### 3. 系統資源需求

#### 記憶體需求
- 模型加載：~2-3GB
- 圖像處理緩衝：~500MB-1GB
- **總計：建議 4GB+ 可用記憶體**

#### CPU 需求
- CPU 模式：4-8 核心推薦
- CUDA 模式：單核心 + GPU 即可

#### 磁碟空間
- 模型緩存：~800MB-2GB
- 臨時文件：~100MB-500MB

---

## 🐳 Docker 化方案

### 方案 A：Linux x86_64 + CUDA（推薦用於雲端）

#### Dockerfile (Linux + CUDA)

```dockerfile
# ==============================================================================
# MLX DeepSeek-OCR Docker Image (Linux + CUDA)
# ==============================================================================

# 使用 NVIDIA CUDA 基礎鏡像
FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

# 設置環境變數
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV MLX_USE_CPU=0
ENV HF_HOME=/root/.cache/huggingface

# 安裝系統依賴
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-dev \
    python3-pip \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# 設置 Python 3.11 為預設
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
RUN update-alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3 1

# 安裝 Python 依賴
COPY requirements.txt /app/requirements.txt
WORKDIR /app

# 安裝 MLX（需要 CUDA 支援版本）
RUN pip3 install --no-cache-dir \
    mlx>=0.20.0 \
    mlx-vlm==0.3.5 \
    && pip3 install --no-cache-dir -r requirements.txt

# 可選：安裝 rembg（背景移除）
RUN pip3 install --no-cache-dir rembg || echo "rembg installation failed, will use fallback"

# 複製應用代碼
COPY . /app

# 創建必要的目錄
RUN mkdir -p /app/uploads /tmp/uploads && \
    chmod 777 /app/uploads /tmp/uploads

# 暴露端口
EXPOSE 5000

# 健康檢查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/api/status || exit 1

# 啟動命令
CMD ["python3", "app.py"]
```

#### docker-compose.yml

```yaml
version: '3.8'

services:
  mlx-ocr-api:
    build:
      context: .
      dockerfile: Dockerfile
    image: mlx-deepseek-ocr:latest
    container_name: mlx-ocr-api
    ports:
      - "5000:5000"
    environment:
      - MLX_USE_CPU=0
      - HF_HOME=/root/.cache/huggingface
    volumes:
      - ./uploads:/app/uploads
      - model-cache:/root/.cache/huggingface
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  model-cache:
    driver: local
```

#### 構建與運行

```bash
# 構建鏡像
docker build -t mlx-deepseek-ocr:latest .

# 運行容器（需要 NVIDIA GPU）
docker run --gpus all -p 5000:5000 \
    -v $(pwd)/uploads:/app/uploads \
    mlx-deepseek-ocr:latest

# 或使用 docker-compose
docker-compose up -d
```

---

### 方案 B：macOS Docker（僅 CPU 模式）

#### Dockerfile (macOS)

```dockerfile
# ==============================================================================
# MLX DeepSeek-OCR Docker Image (macOS - CPU 模式)
# ==============================================================================

FROM python:3.11-slim

# 設置環境變數
ENV PYTHONUNBUFFERED=1
ENV MLX_USE_CPU=1
ENV METAL_DEVICE_WRAPPER_TYPE=1
ENV HF_HOME=/root/.cache/huggingface

# 安裝系統依賴
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 安裝 Python 依賴
COPY requirements.txt /app/requirements.txt
WORKDIR /app

# ⚠️ 注意：MLX 在 Linux Docker 中可能無法正常運行
# 即使設置 CPU 模式，MLX 仍需要 macOS 環境
RUN pip3 install --no-cache-dir -r requirements.txt || \
    echo "⚠️ MLX installation may fail on Linux"

# 複製應用代碼
COPY . /app

# 創建必要的目錄
RUN mkdir -p /app/uploads /tmp/uploads && \
    chmod 777 /app/uploads /tmp/uploads

# 暴露端口
EXPOSE 5000

# 啟動命令
CMD ["python3", "app.py"]
```

**⚠️ 重要限制：**
- MLX 在 Linux Docker 中**可能無法運行**
- 即使設置 `MLX_USE_CPU=1`，MLX 仍需要 macOS 環境
- **建議：macOS 上直接運行，不使用 Docker**

---

### 方案 C：混合架構（推薦生產環境）

#### 架構設計

```
┌─────────────────────────────────────────┐
│         雲端部署架構                      │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────┐      ┌─────────────┐ │
│  │  Web Server  │      │  OCR API    │ │
│  │  (Linux)     │─────>│  (macOS)    │ │
│  │  Nginx/      │ HTTP │  直接運行    │ │
│  │  Apache      │      │  (非 Docker) │ │
│  └──────────────┘      └─────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

**說明：**
- Web Server：Linux Docker（處理靜態文件和路由）
- OCR API：macOS 直接運行（利用 Metal GPU）
- 通過 HTTP API 通信

---

## ⚠️ 關鍵限制與注意事項

### 1. MLX CUDA 支援狀態

**需要確認：**
- ✅ MLX 0.20.0+ 支援 CUDA
- ⚠️ `mlx-vlm==0.3.5` 是否支援 CUDA？
- ⚠️ 模型 `mlx-community/DeepSeek-OCR-4bit` 是否支援 CUDA？

**驗證方法：**
```bash
# 在 Linux + CUDA 環境中測試
python3 -c "import mlx.core as mx; print(mx.metal.is_available())"
python3 -c "from mlx_vlm import load; print('mlx-vlm OK')"
```

### 2. 多進程處理

**Docker 配置：**
```dockerfile
# 確保 multiprocessing 正常工作
ENV PYTHONUNBUFFERED=1
```

**代碼檢查：**
```python
# app.py:71
model_loaded_status = multiprocessing.Value('b', False)
```
- ✅ 使用 `multiprocessing.Value` 是 Docker 友好的
- ⚠️ 確保共享記憶體正確配置

### 3. 模型下載與緩存

**Docker 卷配置：**
```yaml
volumes:
  - model-cache:/root/.cache/huggingface
```

**首次運行：**
- 模型會自動下載到 `/root/.cache/huggingface`
- 使用 volume 持久化，避免重複下載

### 4. 記憶體管理

**Docker 資源限制：**
```yaml
deploy:
  resources:
    limits:
      memory: 8G
    reservations:
      memory: 4G
```

---

## 🧪 測試建議

### 1. 本地測試（macOS）

```bash
# 測試 Docker 構建（不運行）
docker build -t mlx-ocr-test .

# 測試代碼語法
docker run --rm mlx-ocr-test python3 -m py_compile app.py
```

### 2. Linux + CUDA 測試

```bash
# 在 Linux + NVIDIA GPU 環境中
docker build -t mlx-ocr-cuda .
docker run --gpus all mlx-ocr-cuda python3 -c "import mlx.core as mx; print('MLX OK')"
```

### 3. 功能測試

```bash
# 啟動容器
docker run --gpus all -p 5000:5000 mlx-ocr-cuda

# 測試 API
curl http://localhost:5000/api/status
```

---

## 📊 方案對比

| 方案 | 平台 | GPU 支援 | 性能 | 推薦度 |
|------|------|---------|------|--------|
| **方案 A** | Linux + CUDA | ✅ NVIDIA GPU | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **方案 B** | macOS Docker | ❌ 無 GPU | ⭐⭐ | ⭐ |
| **方案 C** | 混合架構 | ✅ Metal GPU | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## ✅ 建議與結論

### 推薦方案

1. **開發環境**：macOS 直接運行（不使用 Docker）
2. **測試環境**：Linux + CUDA Docker（需確認 MLX CUDA 支援）
3. **生產環境**：混合架構（Web Server Docker + OCR API 直接運行）

### 實施步驟

1. **驗證 MLX CUDA 支援**
   ```bash
   # 在 Linux + CUDA 環境中測試
   pip install mlx mlx-vlm
   python3 -c "from mlx_vlm import load; print('OK')"
   ```

2. **構建 Docker 鏡像**
   ```bash
   docker build -t mlx-ocr:latest .
   ```

3. **測試運行**
   ```bash
   docker run --gpus all -p 5000:5000 mlx-ocr:latest
   ```

4. **監控與優化**
   - 監控記憶體使用
   - 監控 GPU 使用率
   - 優化模型加載策略

---

## 📝 相關文件

- `DEPLOYMENT_GUIDE.md` - 部署指南
- `系統支援說明.md` - 系統支援說明
- `requirements.txt` - 依賴清單

---

## 🔄 更新日誌

- **2024-12-XX**：MLX 新增 CUDA 支援，更新 Docker 化分析
- **注意**：需要實際測試確認 `mlx-vlm` 的 CUDA 支援狀態

---

**結論：代碼可以 Docker 化，但需要確認 MLX CUDA 支援。建議先在 Linux + CUDA 環境中測試驗證。**

