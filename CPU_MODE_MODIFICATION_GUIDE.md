# 强制使用 CPU 模式 - 修改指南

## 📋 需要修改的文件清单

### ✅ 必须修改的文件：

1. **`app.py`** - 主应用文件（3 处需要修改）

### ⚠️ 可选修改的文件：

2. **`check_gpu.py`** - GPU 检查脚本（可选，可以保留或删除）
3. **`test_model.py`** - 测试脚本（可选）

---

## 🔧 详细修改说明

### 文件 1：`app.py`（必须修改）

#### 修改位置 1：导入部分（第 26-27 行）

**当前代码：**
```python
import mlx.core as mx
from mlx_vlm import load, generate
```

**修改为：**
```python
import mlx.core as mx
from mlx_vlm import load, generate

# 强制使用 CPU 模式
mx.set_default_device(mx.cpu)
print("🔧 CPU Mode: Forced to use CPU (GPU/Metal disabled)")
```

**位置：** `app.py` 第 26-27 行之后

---

#### 修改位置 2：模型加载函数（第 422-433 行）

**当前代码：**
```python
def _load_model_for_subprocess():
    global _model_instance, _processor_instance, _model_instance_lock
    with _model_instance_lock:
        if _model_instance is not None and _processor_instance is not None:
            return True
        try:
            print(f"[{os.getpid()}] 🚀 Loading MLX DeepSeek-OCR model in subprocess...")
            model_path = "mlx-community/DeepSeek-OCR-8bit"
            _model_instance, _processor_instance = load(model_path)
            print(f"[{os.getpid()}] ✅ Model loaded successfully in subprocess!")
            print(f"[{os.getpid()}] 🔊 Metal available: {mx.metal.is_available()}")
            return True
        except Exception as e:
            print(f"[{os.getpid()}] ❌ Error loading model in subprocess: {e}")
            traceback.print_exc()
            _model_instance = None
            _processor_instance = None
            return False
```

**修改为：**
```python
def _load_model_for_subprocess():
    global _model_instance, _processor_instance, _model_instance_lock
    with _model_instance_lock:
        if _model_instance is not None and _processor_instance is not None:
            return True
        try:
            # 强制使用 CPU 模式
            mx.set_default_device(mx.cpu)
            
            print(f"[{os.getpid()}] 🚀 Loading MLX DeepSeek-OCR model in subprocess (CPU mode)...")
            model_path = "mlx-community/DeepSeek-OCR-8bit"
            _model_instance, _processor_instance = load(model_path)
            print(f"[{os.getpid()}] ✅ Model loaded successfully in subprocess!")
            print(f"[{os.getpid()}] 🔊 Running in CPU mode (Metal disabled)")
            return True
        except Exception as e:
            print(f"[{os.getpid()}] ❌ Error loading model in subprocess: {e}")
            traceback.print_exc()
            _model_instance = None
            _processor_instance = None
            return False
```

**位置：** `app.py` 第 422-439 行

---

#### 修改位置 3：主进程预加载函数（第 567-578 行）

**当前代码：**
```python
def preload_model_main_process():
    print("🔧 Setting model preloaded status for main process...")
    try:
        if not mx.metal.is_available():
            print("WARNING: Metal is not available, MLX might not perform well.")
        
        model_loaded_status.value = True
        print("✅ Model preloaded status set successfully for main process.")
        return True
    except Exception as e:
        print(f"❌ Failed to set model preloaded status: {e}")
        return False
```

**修改为：**
```python
def preload_model_main_process():
    print("🔧 Setting model preloaded status for main process...")
    try:
        # 强制使用 CPU 模式
        mx.set_default_device(mx.cpu)
        print("🔧 CPU Mode: Forced to use CPU (GPU/Metal disabled)")
        print("⚠️  Performance: CPU mode is slower (60-120 sec/page vs 15-30 sec/page)")
        
        model_loaded_status.value = True
        print("✅ Model preloaded status set successfully for main process.")
        return True
    except Exception as e:
        print(f"❌ Failed to set model preloaded status: {e}")
        return False
```

**位置：** `app.py` 第 567-578 行

---

### 文件 2：`check_gpu.py`（可选修改）

**选项 A：保留但添加 CPU 模式提示**

在文件开头添加：
```python
#!/usr/bin/env python3
"""
GPU/Metal 验证脚本
注意：当前配置为强制 CPU 模式
"""

import mlx.core as mx

# 强制使用 CPU 模式
mx.set_default_device(mx.cpu)
print("⚠️  CPU Mode: GPU checking disabled, using CPU only")
```

**选项 B：删除或重命名文件**

如果不需要 GPU 检查，可以：
- 删除 `check_gpu.py`
- 或重命名为 `check_gpu.py.disabled`

---

### 文件 3：`test_model.py`（可选修改）

**当前代码：**
```python
print(f"✅ MLX Metal available: {mx.metal.is_available()}")
```

**修改为：**
```python
# 强制使用 CPU 模式
mx.set_default_device(mx.cpu)
print(f"✅ MLX CPU Mode: Forced (Metal disabled)")
```

---

## 📝 完整修改清单

### 必须修改（app.py）：

| 行号 | 位置 | 修改内容 | 优先级 |
|------|------|---------|--------|
| 26-27 | 导入后 | 添加 `mx.set_default_device(mx.cpu)` | ⭐⭐⭐ 必须 |
| 422-439 | `_load_model_for_subprocess()` | 添加 CPU 模式设置 | ⭐⭐⭐ 必须 |
| 567-578 | `preload_model_main_process()` | 修改 GPU 检查为 CPU 模式 | ⭐⭐⭐ 必须 |

### 可选修改：

| 文件 | 修改内容 | 优先级 |
|------|---------|--------|
| `check_gpu.py` | 添加 CPU 模式提示或删除 | ⭐ 可选 |
| `test_model.py` | 添加 CPU 模式设置 | ⭐ 可选 |

---

## 🔍 修改后的验证

### 1. 检查修改是否正确

```bash
# 搜索是否还有 GPU 相关代码
grep -n "mx.metal\|mx.gpu" app.py

# 应该只看到注释或已修改的代码
```

### 2. 启动应用验证

```bash
# 启动应用
python app.py

# 查看输出，应该看到：
# "🔧 CPU Mode: Forced to use CPU (GPU/Metal disabled)"
# "⚠️  Performance: CPU mode is slower..."
```

### 3. 测试 OCR 功能

```bash
# 发送 OCR 请求，确认可以正常运行
# 虽然速度较慢（60-120秒/页），但应该可以完成
```

---

## ⚠️ 注意事项

### 1. 性能影响

- **GPU 模式：** 15-30 秒/页
- **CPU 模式：** 60-120 秒/页（慢 3-5 倍）

### 2. 并发建议

CPU 模式下可以增加并发数：
- GPU 模式：建议 1-2 个并发进程
- CPU 模式：建议 4-8 个并发进程（根据 CPU 核心数）

### 3. 内存使用

- CPU 模式使用系统内存，通常比 GPU 内存更大
- 但每个进程仍会占用 2-4GB 内存

---

## ✅ 快速修改步骤

### 步骤 1：修改 app.py（3 处）

1. **第 27 行后添加：**
```python
mx.set_default_device(mx.cpu)
print("🔧 CPU Mode: Forced to use CPU (GPU/Metal disabled)")
```

2. **第 427 行后添加：**
```python
mx.set_default_device(mx.cpu)
```

3. **第 570 行替换：**
```python
mx.set_default_device(mx.cpu)
print("🔧 CPU Mode: Forced to use CPU (GPU/Metal disabled)")
print("⚠️  Performance: CPU mode is slower (60-120 sec/page vs 15-30 sec/page)")
```

### 步骤 2：测试

```bash
python app.py
# 查看输出确认 CPU 模式已启用
```

---

## 📊 修改前后对比

### 修改前（自动检测 GPU/CPU）：
- ✅ 自动检测 GPU，如果可用则使用 GPU
- ✅ GPU 不可用时自动回退到 CPU
- ⚠️ 无法强制使用 CPU

### 修改后（强制 CPU 模式）：
- ✅ 强制使用 CPU，忽略 GPU
- ✅ 明确提示 CPU 模式
- ✅ 性能警告（CPU 模式较慢）

---

## 🎯 总结

**必须修改的文件：**
- ✅ `app.py`（3 处修改）

**可选修改的文件：**
- ⚠️ `check_gpu.py`（可选）
- ⚠️ `test_model.py`（可选）

**关键修改：**
- 在 3 个位置添加 `mx.set_default_device(mx.cpu)`
- 修改 GPU 检查提示为 CPU 模式提示

**修改后效果：**
- 强制使用 CPU 模式
- 忽略 GPU/Metal
- 可以正常运行，但性能较慢



