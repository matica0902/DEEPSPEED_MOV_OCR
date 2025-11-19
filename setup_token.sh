#!/bin/bash

# ==============================================================================
# Hugging Face Token 自动设置脚本
# ==============================================================================

echo "🔑 Hugging Face Token 设置工具"
echo "=================================="
echo ""

# 检查是否已有 token
if [ -f .env ] && grep -q "HF_TOKEN=" .env; then
    echo "✅ 发现已存在的 .env 文件"
    read -p "是否要更新 token? (y/n): " update
    if [ "$update" != "y" ]; then
        echo "保持现有 token"
        exit 0
    fi
fi

echo "📋 请按照以下步骤获取您的 Hugging Face Token:"
echo ""
echo "1. 访问: https://huggingface.co/settings/tokens"
echo "2. 点击 'New token'"
echo "3. 输入名称（如 'MLX-OCR-App'）"
echo "4. 选择 'Read' 权限"
echo "5. 点击 'Generate token'"
echo "6. 复制生成的 token"
echo ""
read -p "请输入您的 Hugging Face Token: " token

if [ -z "$token" ]; then
    echo "❌ Token 不能为空"
    exit 1
fi

# 验证 token 格式（应该以 hf_ 开头）
if [[ ! "$token" =~ ^hf_ ]]; then
    echo "⚠️  警告: Token 格式可能不正确（通常以 'hf_' 开头）"
    read -p "是否继续? (y/n): " continue
    if [ "$continue" != "y" ]; then
        exit 1
    fi
fi

# 创建或更新 .env 文件
echo "HF_TOKEN=$token" > .env
echo "HUGGINGFACE_TOKEN=$token" >> .env
echo "HUGGING_FACE_HUB_TOKEN=$token" >> .env

echo ""
echo "✅ Token 已保存到 .env 文件"
echo ""
echo "📝 下一步："
echo "   1. 确保 .env 文件已添加到 .gitignore（不会提交到 Git）"
echo "   2. 运行应用时会自动读取 .env 文件中的 token"
echo ""
echo "🚀 现在可以运行: ./start.sh 或 python app.py"

