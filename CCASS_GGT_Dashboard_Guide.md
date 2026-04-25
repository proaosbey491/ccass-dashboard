# 港股通 CCASS 异动日报 — 构建指南

> 本文档记录了从数据采集到网站部署的完整构建过程，包括 HKEX CCASS 数据抓取、Sina Finance 行情获取、SQLite 数据库存储、多格式报告生成（Excel/Markdown/JSON）、以及基于 GitHub Pages 的 SPA 仪表板部署。

---

## 一、项目概述

### 1.1 目标
构建一个**每日自动更新**的港股通 CCASS（中央结算系统）持股变动追踪系统：
- 每日抓取港交所 CCASS 持股数据
- 对比前一日计算持股变动
- 结合实时行情进行异动分析
- 生成可视化仪表板并部署到 GitHub Pages

### 1.2 技术栈
| 层级 | 技术 |
|------|------|
| **数据采集** | Python 3.9 + requests + BeautifulSoup |
| **数据存储** | SQLite |
| **行情来源** | Sina Finance API (hq.sinajs.cn) |
| **报告生成** | pandas + openpyxl (Excel) |
| **前端仪表板** | 原生 HTML + ECharts (SPA) |
| **部署托管** | GitHub Pages |
| **定时任务** | macOS LaunchAgent |

### 1.3 项目结构
```
~/Documents/Kimi/ccass_reports_v2/
├── index.html              # SPA 仪表板主页面
├── data/
│   ├── manifest.json       # 日期索引
│   ├── data_YYYY-MM-DD.json # 每日数据（供前端加载）
│   └── ...
├── ccass_report_YYYYMMDD.xlsx   # Excel 报告
└── ccass_report_YYYYMMDD.md     # Markdown 报告

~/.config/agents/skills/Skill_CCASS/
├── SKILL.md
├── scripts/
│   └── ccass_tracker_v2.py      # 主程序
└── assets/
    └── index.html                 # 模板文件
```

---

## 二、数据采集系统

### 2.1 CCASS 数据来源
**香港交易所披露易** (www3.hkexnews.hk)
- 通过 ASP.NET 表单提交（VIEWSTATE + __doPostBack）
- 查询每只股票的 CCASS 持股明细
- 包含：总持股数、参与者数、占总股本比例

### 2.2 行情数据来源
**Sina Finance API** (hq.sinajs.cn)
```
https://hq.sinajs.cn/list=rt_hk{code}
```
返回字段：股票名称、最新价、开盘价、昨收、最高价、最低价、涨跌额、涨跌(%)、成交量、成交额、PE 等。

> 注意：Eastmoney/AKShare 在本网络环境下因代理问题不可用，yfinance 有限流。Sina Finance 是唯一稳定可靠的数据源。

### 2.3 港股通股票范围
从全部主板 3084 只股票缩减为**港股通 271 只主要标的**，存储在：
```
~/Documents/Kimi/hk_ggt_codes.txt
```

### 2.4 采集脚本使用
```bash
# 港股通模式（271只股票，约15-20分钟）
python3 ccass_tracker_v2.py --file ~/Documents/Kimi/hk_ggt_codes.txt

# 指定日期
python3 ccass_tracker_v2.py --file ~/Documents/Kimi/hk_ggt_codes.txt --date 2026-04-22

# 仅生成报告（不重新采集）
python3 ccass_tracker_v2.py --report-only --date 2026-04-22
```

---

## 三、数据计算逻辑

### 3.1 CCASS 变动计算
```python
# 持股数量变动（股）
ccass_total_change = ccass_total_shares(今日) - ccass_total_shares(昨日)

# 变动比例（%）— 采用百分比变化公式
ccass_total_change_pct = (ccass_total_shares(今日) - ccass_total_shares(昨日)) / ccass_total_shares(昨日) * 100%
```

### 3.2 异动判定
| 类型 | 条件 |
|------|------|
| **大幅增持** | 变动 > 0.5% 总股本 或 > 1000万股 |
| **大幅减持** | 变动 < -0.5% 总股本 或 < -1000万股 |
| **股价异动** | 单日涨跌 > ±5% |
| **放量** | 成交量 > 前20日均量 2倍 |

---

## 四、报告生成

### 4.1 Excel 报告（多工作表）
| 工作表 | 内容 |
|--------|------|
| 全部数据 | 所有股票的 CCASS + 行情数据 |
| 异动股票 | 触发异动的股票 |
| CCASS增持Top50 | 按增持量排序 |
| CCASS减持Top50 | 按减持量排序 |
| 汇总 | 市场整体统计 |

### 4.2 Markdown 报告
自动生成自然语言摘要，包含：
- 市场整体概况
- 大幅增持/减持股票列表
- 股价异动分析
- 多维度共振（CCASS变动 + 股价变动 + 放量）

### 4.3 JSON 数据（前端用）
```json
{
  "date": "2026-04-22",
  "prev_date": "2026-04-21",
  "kpi": {
    "total_stocks": 265,
    "increase_count": 62,
    "decrease_count": 20,
    "price_up_count": 55,
    "price_down_count": 190
  },
  "increase": [...],
  "decrease": [...],
  "scatter": [...],
  "all": [...],
  "summary_html": "..."
}
```

---

## 五、SPA 仪表板

### 5.1 页面标题
```html
<title>港股通CCASS异动日报</title>
<h1>📊 港股通CCASS异动日报</h1>
```

### 5.2 KPI 卡片（5个）
- 监控股票总数
- CCASS 增持家数
- CCASS 减持家数
- 股价上涨家数
- 股价下跌家数

> （已删除"CCASS持股不变"卡片）

### 5.3 图表
| 图表 | 类型 | 说明 |
|------|------|------|
| **CCASS增持Top20** | 横向柱状图 | 从大到小排列，红色 |
| **CCASS减持Top20** | 横向柱状图 | 从大到小排列，绿色 |
| **持股变动分布** | 饼图 | 增持/减持占比 |
| **CCASS变动 vs 股价变动** | 散点图 | 仅展示有变化的股票 |

#### 散点图配置
- **X轴**：CCASS变动(%) — (今日-昨日)/昨日×100%
- **Y轴**：股价变动(%) — 直接读取涨跌(%)
- **气泡大小**：绝对持股变动量
- **颜色**：红色=增持，绿色=减持
- **数据筛选**：仅 ccass_change != 0 的股票

### 5.4 数据表格
- **列**：股票代码、股票名称、CCASS变动、变动比例(%)、CCASS占比(%)、最新价、涨跌(%)、成交量、成交额、PE、异动标记
- **排序**：点击表头可按列排序（升序/降序）
- **颜色标签**：红色=上涨/增持，绿色=下跌/减持

### 5.5 异动摘要
```html
<p>本日共监控 <strong>265</strong> 只港股通股票。</p>
<ul>
    <li><strong>CCASS 持股变动</strong>：增持 62 家 | 减持 20 家</li>
    <li><strong>股价表现</strong>：上涨 55 家 | 下跌 190 家</li>
</ul>
```

> （已删除"CCASS总持股净变动"行，并将"港股主板股票"改为"港股通股票"）

---

## 六、GitHub Pages 部署

### 6.1 部署流程
```bash
# 1. 进入项目目录
cd ~/Documents/Kimi/ccass_reports_v2

# 2. 初始化 Git（如未初始化）
git init
git remote add origin https://github.com/USERNAME/ccass-dashboard.git

# 3. 提交代码
git add -A
git commit -m "Initial commit"

# 4. 推送
git push -u origin main

# 5. 在 GitHub Settings -> Pages 中启用 Pages
#    Source: Deploy from a branch -> main -> /(root)
```

### 6.2 访问地址
```
https://USERNAME.github.io/ccass-dashboard
```

### 6.3 CORS 注意事项
SPA 必须通过 HTTP/HTTPS 访问，file:// 协议会被浏览器安全策略阻止。本地预览请使用：
```bash
cd ~/Documents/Kimi/ccass_reports_v2
python3 -m http.server 8080
# 访问 http://localhost:8080
```

---

## 七、自动化配置

### 7.1 自动采集脚本
```bash
# 主脚本位置
~/Documents/Kimi/ccass_auto_run.sh
```

脚本内容：
```bash
#!/bin/bash
set -e

REPORTS_DIR="/Users/sagiexue/Documents/Kimi/ccass_reports_v2"
SCRIPT="/Users/sagiexue/.config/agents/skills/Skill_CCASS/scripts/ccass_tracker_v2.py"
GGT_CODES="/Users/sagiexue/Documents/Kimi/hk_ggt_codes.txt"

# 1. 采集数据（港股通271只）
cd "$REPORTS_DIR"
/usr/bin/python3 "$SCRIPT" --file "$GGT_CODES"

# 2. 复制数据到正确位置
cp .../data/data_*.json "$REPORTS_DIR"/data/
cp .../ccass_report_* "$REPORTS_DIR"/

# 3. 更新 manifest.json
python3 -c "import json, glob; ..."

# 4. Git 提交并推送
git add -A
git commit -m "Auto update: $(date '+%Y-%m-%d')"
GIT_SSL_NO_VERIFY=1 git push origin main
```

### 7.2 macOS 定时任务（LaunchAgent）
配置文件：`~/Library/LaunchAgents/com.ccass.scraper.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ccass.scraper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/sagiexue/Documents/Kimi/ccass_auto_run.sh</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/sagiexue/Documents/Kimi/ccass_reports_v2</string>
    <!-- 北京时间每天 23:30 运行 -->
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key><integer>23</integer>
        <key>Minute</key><integer>30</integer>
    </dict>
</dict>
</plist>
```

加载任务：
```bash
launchctl load ~/Library/LaunchAgents/com.ccass.scraper.plist
```

### 7.3 本地服务器自启
配置文件：`~/Library/LaunchAgents/com.ccass.dashboard.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <key>Label</key><string>com.ccass.dashboard</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>-m</string><string>http.server</string><string>8000</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/sagiexue/Documents/Kimi/ccass_reports_v2</string>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
</dict>
</plist>
```

---

## 八、关键修改记录

### 8.1 股票范围调整
- **原**：全部主板 3084 只股票（约60-90分钟）
- **改**：港股通 271 只主要标的（约15-20分钟）
- **文件**：`~/Documents/Kimi/hk_ggt_codes.txt`

### 8.2 变动比例公式调整
- **原**：百分点变化 `ccass_total_pct - ccass_total_pct_prev`
- **改**：百分比变化 `(今日-昨日)/昨日 * 100%`
- **代码**：`ccass_tracker_v2.py` line ~471

### 8.3 页面标题修改
- **原**：港股 CCASS 异动日报
- **改**：港股通CCASS异动日报

### 8.4 KPI 卡片调整
- **删除**："CCASS持股不变" 卡片
- **保留**：总数、增持、减持、股价涨、股价跌

### 8.5 柱状图排序
- **修复**：添加 `.reverse()` 实现从大到小排列
- **增持图**：最大增持在最上方
- **减持图**：最大减持在最上方

### 8.6 表格排序功能
- **新增**：点击表头可按列升序/降序排序
- **指示符**：▲ ▼ 显示当前排序方向

### 8.7 散点图优化
- **数据筛选**：仅展示 `ccass_change != 0` 的股票
- **X轴名称**：CCASS变动(%)
- **数据量**：从 262 只减少到 82 只

### 8.8 异动摘要精简
- **删除**："CCASS总持股净变动: xxx股" 行
- **删除**："不变 x 家" 统计
- **修改**："港股主板股票" -> "港股通股票"

### 8.9 图表渲染修复
- **问题**：ECharts 在隐藏容器中初始化导致尺寸为0
- **修复**：dashboard 显示后 `setTimeout(() => charts.forEach(c => c.resize()), 100)`

---

## 九、常见问题

### Q1: GitHub 推送超时
**解决**：
```bash
GIT_SSL_NO_VERIFY=1 git push origin main
```

### Q2: 采集速度过慢
**优化参数**（`ccass_tracker_v2.py`）：
```python
CCASS_DELAY = 0.5          # 请求间隔（原1.5秒）
CCASS_BATCH = 50           # 每批数量（原20只）
CCASS_BATCH_DELAY = 2      # 批次间隔（原5秒）
```

### Q3: 数据文件未更新
**检查**：
```bash
# 确认数据文件已复制到正确位置
ls ~/Documents/Kimi/ccass_reports_v2/data/

# 确认 manifest.json 包含新日期
cat ~/Documents/Kimi/ccass_reports_v2/data/manifest.json
```

### Q4: 网站显示旧数据
**解决**：
1. 强制刷新浏览器：`Cmd + Shift + R`
2. 添加缓存参数：`https://xxx.github.io/ccass-dashboard?v=2`
3. 等待 GitHub Pages 构建（通常1-2分钟）

---

## 十、维护命令速查

```bash
# 手动触发采集
cd ~/Documents/Kimi/ccass_reports_v2
python3 ~/.config/agents/skills/Skill_CCASS/scripts/ccass_tracker_v2.py \
    --file ~/Documents/Kimi/hk_ggt_codes.txt

# 查看定时任务状态
launchctl list | grep com.ccass

# 查看采集日志
tail -f /tmp/ccass_auto_run.log

# 本地预览
cd ~/Documents/Kimi/ccass_reports_v2
python3 -m http.server 8080
```

---

## 附录：相关文件路径

| 文件 | 路径 |
|------|------|
| 主程序 | `~/.config/agents/skills/Skill_CCASS/scripts/ccass_tracker_v2.py` |
| 港股通股票列表 | `~/Documents/Kimi/hk_ggt_codes.txt` |
| 自动运行脚本 | `~/Documents/Kimi/ccass_auto_run.sh` |
| SPA 页面 | `~/Documents/Kimi/ccass_reports_v2/index.html` |
| 数据目录 | `~/Documents/Kimi/ccass_reports_v2/data/` |
| 定时任务 | `~/Library/LaunchAgents/com.ccass.scraper.plist` |
| 本地服务器 | `~/Library/LaunchAgents/com.ccass.dashboard.plist` |
| SQLite 数据库 | `~/.config/agents/skills/Skill_CCASS/scripts/ccass_data_v2.db` |

---

## 附录：GitHub 仓库信息

- **仓库地址**：https://github.com/proaosbey491/ccass-dashboard
- **网站地址**：https://proaosbey491.github.io/ccass-dashboard
- **用户名**：proaosbey491
