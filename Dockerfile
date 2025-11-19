# 使用 Python 3.10 基礎映象
FROM python:3.10-slim

# 設定環境變數
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    MLX_USE_CPU=1 \
    METAL_DEVICE_WRAPPER_TYPE=1 \
    HF_HOME=/tmp/hf_cache

# 安裝系統依賴（移除不存在的包）
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-opencv \
    libopenblas-dev \
    libgfortran5 \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 設定工作目錄
WORKDIR /app

# 複製 requirements.txt
COPY requirements.txt .

# 安裝 Python 依賴
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.txt

# 複製應用程式碼
COPY app.py .
COPY templates/ templates/
COPY static/ static/

# 建立暫存目錄
RUN mkdir -p /tmp/hf_cache && \
    chmod 777 /tmp/hf_cache

# 暴露埠口
EXPOSE 5001

# 健康檢查
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5001/api/health').read()" || exit 1

# 啟動應用
CMD ["python", "app.py"]
