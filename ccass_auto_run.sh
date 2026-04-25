#!/bin/bash
# CCASS 港股通股票每日自动采集 + 推送到 GitHub Pages
set -e

REPORTS_DIR="/Users/sagiexue/Documents/Kimi/K_CCASS"
SCRIPT="/Users/sagiexue/.config/agents/skills/Skill_CCASS/scripts/ccass_tracker_v2.py"
GGT_CODES="/Users/sagiexue/Documents/Kimi/K_CCASS/hk_ggt_codes.txt"
LOG_FILE="/tmp/ccass_auto_run.log"

exec >> "$LOG_FILE" 2>&1

echo "========================================"
echo "CCASS 港股通自动采集开始: $(date '+%Y-%m-%d %H:%M:%S')"
echo "股票范围: 港股通 ($(wc -l < "$GGT_CODES") 只)"
echo "========================================"

# 步骤1: 运行数据采集（港股通股票）
echo "[1/3] 开始采集港股通 CCASS 数据..."
cd "$REPORTS_DIR"
/usr/bin/python3 "$SCRIPT" --file "$GGT_CODES"
echo "[1/3] ✅ 数据采集完成"

# 步骤2: 复制数据到正确位置
echo "[2/3] 整理数据文件..."
cp /Users/sagiexue/.config/agents/skills/Skill_CCASS/scripts/ccass_reports_v2/data/*.json "$REPORTS_DIR"/data/ 2>/dev/null || true
cp /Users/sagiexue/.config/agents/skills/Skill_CCASS/scripts/ccass_reports_v2/ccass_report_* "$REPORTS_DIR"/ 2>/dev/null || true

# 更新 manifest.json
python3 -c "
import json, os, glob
files = sorted(glob.glob('data/data_*.json'))
dates = [os.path.basename(f).replace('data_','').replace('.json','') for f in files]
with open('data/manifest.json', 'w') as f:
    json.dump({'dates': dates}, f, indent=2)
"
echo "[2/3] ✅ 数据整理完成"

# 步骤3: Git 提交并推送
echo "[3/3] 推送到 GitHub Pages..."
cd "$REPORTS_DIR"
git add -A
git commit -m "Auto update GGT: $(date '+%Y-%m-%d')" || echo "没有新文件需要提交"
git push origin main
echo "[3/3] ✅ GitHub 推送完成"

echo ""
echo "========================================"
echo "全部完成: $(date '+%Y-%m-%d %H:%M:%S')"
echo "网站地址: https://proaosbey491.github.io/ccass-dashboard"
echo "========================================"
echo ""
