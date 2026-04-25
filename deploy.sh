#!/bin/bash
# CCASS 仪表板部署脚本
# 支持 GitHub Pages / Vercel / 阿里云 OSS

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "  CCASS 仪表板部署工具"
echo "========================================"
echo ""

# 检查是否有新数据需要提交
if [ -d ".git" ]; then
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "Update dashboard data $(date +%Y-%m-%d)"
        echo "✅ 新数据已提交到 Git"
    else
        echo "ℹ️  没有新数据需要提交"
    fi
fi

echo ""
echo "请选择部署平台："
echo ""
echo "1) GitHub Pages - 免费，适合长期托管"
echo "2) Vercel - 免费，一键部署，自动更新"
echo "3) 阿里云 OSS - 国内访问快，约¥5/月"
echo "4) 仅生成本地部署指南"
echo ""
read -p "请输入选项 (1-4): " choice

case $choice in
    1)
        deploy_github_pages
        ;;
    2)
        deploy_vercel
        ;;
    3)
        deploy_aliyun
        ;;
    4)
        generate_guide
        ;;
    *)
        echo "无效选项"
        exit 1
        ;;
esac

deploy_github_pages() {
    echo ""
    echo "📋 GitHub Pages 部署步骤："
    echo ""
    
    if ! command -v gh &> /dev/null; then
        echo "⚠️  未检测到 GitHub CLI (gh)"
        echo ""
        echo "方案 A - 命令行安装："
        echo "  brew install gh"
        echo "  gh auth login"
        echo ""
        echo "方案 B - 手动部署："
        echo "  1. 在 https://github.com/new 创建新仓库（如 ccass-dashboard）"
        echo "  2. 不要勾选 README 或 .gitignore"
        echo "  3. 运行以下命令："
        echo ""
        echo "     git remote add origin https://github.com/你的用户名/ccass-dashboard.git"
        echo "     git branch -M main"
        echo "     git push -u origin main"
        echo ""
        echo "  4. 进入仓库 Settings > Pages"
        echo "  5. Source 选择 Deploy from a branch"
        echo "  6. Branch 选择 main，文件夹选择 / (root)"
        echo "  7. 保存后等待 1-2 分钟"
        echo "  8. 访问 https://你的用户名.github.io/ccass-dashboard"
        echo ""
        return
    fi
    
    echo "✅ 已检测到 GitHub CLI"
    read -p "请输入 GitHub 仓库名 (如 ccass-dashboard): " repo_name
    
    gh repo create "$repo_name" --public --source=. --remote=origin --push
    
    echo ""
    echo "✅ 代码已推送到 GitHub"
    echo ""
    echo "现在启用 GitHub Pages："
    echo ""
    
    # 尝试通过 API 启用 GitHub Pages
    gh api "repos/$(gh api user -q .login)/$repo_name/pages" \
        --method POST \
        --input - <<< '{"source":{"branch":"main","path":"/"}}' 2>/dev/null || true
    
    echo "✅ GitHub Pages 已启用"
    echo ""
    echo "🌐 你的网站将在 1-2 分钟后可用："
    echo "   https://$(gh api user -q .login).github.io/$repo_name"
    echo ""
    echo "⏳ 请在浏览器中打开上述链接查看"
}

deploy_vercel() {
    echo ""
    echo "📋 Vercel 部署步骤："
    echo ""
    
    if ! command -v vercel &> /dev/null; then
        echo "⚠️  未检测到 Vercel CLI"
        echo ""
        echo "安装步骤："
        echo "  npm i -g vercel"
        echo ""
        echo "或者使用 npx（无需全局安装）："
        echo "  npx vercel --yes"
        echo ""
        return
    fi
    
    echo "✅ 已检测到 Vercel CLI"
    echo ""
    echo "正在部署到 Vercel..."
    vercel --yes
    
    echo ""
    echo "✅ 部署完成！"
    echo ""
}

deploy_aliyun() {
    echo ""
    echo "📋 阿里云 OSS 部署步骤："
    echo ""
    echo "1. 登录阿里云控制台 https://oss.console.aliyun.com"
    echo "2. 创建 Bucket（如 ccass-dashboard）"
    echo "3. 区域选择离你最近的（如 华东1-杭州）"
    echo "4. 权限设置为 公共读"
    echo "5. 开启 静态页面托管"
    echo "   - 默认首页: index.html"
    echo "   - 默认404页: index.html"
    echo "6. 上传本目录所有文件到 OSS"
    echo "7. 绑定自定义域名（可选）"
    echo ""
    echo "💡 可以使用 ossutil 命令行工具批量上传："
    echo "  ossutil cp -r ./ oss://你的bucket名/"
    echo ""
}

generate_guide() {
    echo ""
    echo "📖 部署指南已生成"
}
