# GPU/CPU 检查与多线程分析报告

## 📋 当前代码状态分析

### ✅ 1. GPU 检查机制

**现有检查点：**
- `app.py:570` - 主进程启动时检查 Metal 可用性
- `app.py:432` - 子进程加载模型时检查 Metal 可用性
- `check_gpu.py` - 独立的 GPU 验证脚本

**代码位置：**
```python
# app.py:570
if not mx.metal.is_available():
    print("WARNING: Metal is not available, MLX might not perform well.")
```

**问题：**
- ⚠️ 仅打印警告，没有明确的 CPU 回退处理
- ⚠️ 没有在 API 响应中返回 GPU 状态
- ⚠️ 没有阻止应用启动的机制（即使没有 GPU）

---

### ❌ 2. CPU 回退机制

**当前状态：**
- MLX 库会自动回退到 CPU（如果 Metal 不可用）
- 但代码中没有明确处理这种情况
- 用户无法知道当前使用的是 GPU 还是 CPU

**缺失功能：**
- ❌ 没有明确的 CPU 模式检测
- ❌ 没有性能警告（CPU 模式会很慢）
- ❌ 没有在状态 API 中返回设备信息

---

### ⚠️ 3. GPU 多线程/并发限制

**当前实现：**

1. **Flask 多线程：**
   ```python
   # app.py:1706
   app.run(host='0.0.0.0', port=5001, debug=False, threaded=True)
   ```
   - ✅ Flask 使用多线程处理 HTTP 请求

2. **OCR 多进程：**
   ```python
   # app.py:497
   process = multiprocessing.Process(
       target=_run_ocr_in_process,
       args=(image_bytes, prompt, max_tokens, output_queue)
   )
   ```
   - ⚠️ 每个 OCR 请求创建独立的子进程
   - ⚠️ 每个子进程都会加载模型到 GPU

**问题分析：**

1. **无并发限制：**
   - 如果同时有 10 个请求，会创建 10 个子进程
   - 每个子进程都会占用 GPU 内存（约 4-8GB）
   - 可能导致 GPU 内存不足（OOM）

2. **GPU 资源竞争：**
   - macOS Metal 不支持真正的多进程 GPU 并发
   - 多个进程同时使用 GPU 会导致：
     - 性能下降（资源竞争）
     - 内存碎片化
     - 可能的崩溃

3. **模型重复加载：**
   - 每个子进程都加载一次模型
   - 浪费内存和时间
   - 理想情况：模型只加载一次，多个任务共享

---

## 🔧 改进建议

### 1. 增强 GPU 检查和 CPU 回退

**建议修改：**

```python
# 在 app.py 中添加
def check_gpu_status():
    """检查 GPU 状态并返回详细信息"""
    metal_available = mx.metal.is_available()
    default_device = mx.default_device()
    
    status = {
        'metal_available': metal_available,
        'device': str(default_device),
        'using_gpu': metal_available and ('gpu' in str(default_device).lower() or 'metal' in str(default_device).lower()),
        'using_cpu': not metal_available or 'cpu' in str(default_device).lower()
    }
    
    if not metal_available:
        print("⚠️ WARNING: Metal GPU not available, using CPU mode (performance will be slow)")
    
    return status

# 在启动时检查
gpu_status = check_gpu_status()
if not gpu_status['metal_available']:
    print("⚠️ CRITICAL: Running in CPU-only mode. Performance will be significantly slower.")
    print("   Expected OCR time: 60-120 seconds per page (vs 15-30 seconds with GPU)")
```

### 2. 添加并发限制

**建议实现进程池：**

```python
from multiprocessing import Pool, Semaphore
import atexit

# 限制最大并发进程数（根据 GPU 内存调整）
MAX_CONCURRENT_PROCESSES = 2  # 对于 8GB GPU，建议 1-2 个进程
process_semaphore = Semaphore(MAX_CONCURRENT_PROCESSES)

def generate_with_timeout_and_process(image, prompt, max_tokens=8192, timeout=160):
    # 使用信号量限制并发
    if not process_semaphore.acquire(timeout=30):
        raise RuntimeError("Too many concurrent OCR requests. Please try again later.")
    
    try:
        # ... 原有的处理逻辑 ...
    finally:
        process_semaphore.release()
```

### 3. 添加 GPU 状态 API

**建议添加：**

```python
@app.route('/api/gpu-status')
def gpu_status():
    """返回 GPU 状态信息"""
    status = check_gpu_status()
    return jsonify({
        'success': True,
        'gpu_status': status,
        'recommendations': {
            'max_concurrent': MAX_CONCURRENT_PROCESSES if status['using_gpu'] else 4,
            'performance_warning': not status['using_gpu']
        }
    })
```

### 4. 优化模型加载（可选）

**建议使用进程池预加载：**

```python
# 使用进程池而不是每次创建新进程
from multiprocessing import Pool

# 全局进程池（在启动时创建）
ocr_pool = None

def init_ocr_pool():
    global ocr_pool
    if ocr_pool is None:
        ocr_pool = Pool(processes=MAX_CONCURRENT_PROCESSES, 
                       initializer=_init_worker_process)
```

---

## 📊 当前限制总结

| 项目 | 状态 | 说明 |
|------|------|------|
| GPU 检查 | ⚠️ 部分 | 有检查但不够完善 |
| CPU 回退 | ❌ 缺失 | MLX 自动回退，但代码未处理 |
| 并发限制 | ❌ 缺失 | 无限制，可能导致 GPU OOM |
| 状态监控 | ❌ 缺失 | 无法查看当前 GPU 使用情况 |
| 模型共享 | ❌ 缺失 | 每个进程独立加载模型 |

---

## 🎯 优先级建议

### 高优先级（立即修复）
1. ✅ 添加 GPU 状态检查和 CPU 回退处理
2. ✅ 添加并发限制（防止 GPU OOM）

### 中优先级（后续优化）
3. ⚠️ 添加 GPU 状态 API
4. ⚠️ 优化模型加载（使用进程池）

### 低优先级（可选）
5. 💡 添加 GPU 使用率监控
6. 💡 动态调整并发数（根据 GPU 内存）

---

## 🔍 验证方法

### 检查当前 GPU 使用情况：

```bash
# 1. 运行 GPU 检查脚本
python check_gpu.py

# 2. 查看 Activity Monitor
# - 打开 Activity Monitor
# - 查看 GPU 标签页
# - 运行 OCR 任务，观察 GPU 使用率

# 3. 测试并发限制
# - 同时发送多个 OCR 请求
# - 观察是否创建多个进程
# - 检查 GPU 内存使用情况
```

---

## 📝 注意事项

1. **macOS Metal 限制：**
   - Metal 不支持真正的多进程 GPU 并发
   - 建议最多 1-2 个并发进程使用 GPU
   - 超过限制会导致性能下降

2. **GPU 内存：**
   - DeepSeek-OCR-8bit 模型约需 4-8GB GPU 内存
   - 多个进程会叠加内存使用
   - 需要根据 GPU 内存调整并发数

3. **CPU 模式性能：**
   - CPU 模式比 GPU 慢 3-5 倍
   - 建议在 CPU 模式下增加并发数（4-8 个进程）
   - 但要注意 CPU 负载

---

## ✅ 总结

**当前代码存在的问题：**
1. ✅ 有 GPU 检查，但不够完善
2. ❌ 没有明确的 CPU 回退处理
3. ❌ 没有并发限制，可能导致 GPU 资源竞争
4. ❌ 没有 GPU 状态监控 API

**建议立即实施：**
1. 增强 GPU 检查和 CPU 回退机制
2. 添加并发限制（Semaphore 或进程池）
3. 添加 GPU 状态 API



