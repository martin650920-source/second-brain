---
name: context-loader
description: >
  三層 context 載入器（全域 → 情境 → 專案）。
  在 session 開始時自動觸發（由 adapters bootstrap），
  或 user 說「load context」、「載入 context」時觸發。
---

# Context Loader v2

## Step 0：Secure Mode 確認

執行以下指令確認是否啟用 Secure Mode：
```bash
[ -f ~/.second-brain/.secure-mode ] && echo "SECURE" || echo "NORMAL"
```

**若 SECURE MODE ON：**
- MCP 白名單嚴格執行，只有 `mcp.json` 列出的工具可用
- 若 user 要求使用白名單外的工具，拒絕並說明：「目前 Secure Mode 開啟，此工具不在 [情境名] 白名單內」

## Step 1：解析 Base Path

| 環境 | Base Path |
|---|---|
| Windows (PowerShell) | `$env:USERPROFILE\.second-brain` |
| WSL / Linux / SSH | `~/.second-brain` |

若路徑不存在，停止並回報：
```
`~/.second-brain` not found — 請先執行 setup script。
```

## Step 2：載入全域層（必載）

依序讀取：
1. `<BASE>/core/profile.md` — 個人偏好與環境
2. `<BASE>/core/meta-rules.md` — 衝突優先權規則

## Step 2.5：Skill Drift 偵測

比對 `<BASE>/skills/` 與 `~/.claude/skills/`，找出有 skill 目錄但**缺少對應 symlink** 的項目。

**Windows（PowerShell）：**
```powershell
$base      = "$env:USERPROFILE\.second-brain"
$skillsDir = "$env:USERPROFILE\.claude\skills"
$missing   = Get-ChildItem "$base\skills" -Directory |
             Where-Object { -not (Test-Path "$skillsDir\$($_.Name)") }
$missing | ForEach-Object { $_.Name }
```

**WSL / SSH（bash）：**
```bash
base=~/.second-brain
for d in "$base/skills"/*/; do
  name=$(basename "$d")
  [ ! -e ~/.claude/skills/"$name" ] && echo "$name"
done
```

**若有缺漏 skill：**
```
發現 N 個尚未連結的 skill：<name1>, <name2>
要現在建立 symlink 嗎？[Y/n]
```

若 Y，依環境建立 symlink：

Windows：
```powershell
foreach ($s in $missing) {
    New-Item -ItemType SymbolicLink `
      -Path "$skillsDir\$($s.Name)" -Target $s.FullName
}
```

WSL / SSH：
```bash
for name in $missing_names; do
    ln -sf "$base/skills/$name" ~/.claude/skills/"$name"
done
```

若無缺漏 → 靜默跳過，不輸出任何訊息。

## Step 3：選擇情境（Lazy Loading）

顯示選單：
```
情境選擇：
  1) work   — 工作（僅公司工具）
  2) life   — 生活（僅個人工具）
  3) none   — 不選（只載全域層）

請選擇 [1/2/3，預設 3]：
```

**若選 none → 直接跳 Step 5**

## Step 4：載入情境層

載入選定情境的內容：
- `<BASE>/contexts/<name>/context.md`
- `<BASE>/contexts/<name>/rules.md`（若存在）
- 讀取 `<BASE>/contexts/<name>/mcp.json` → 取得可用工具清單

顯示可用 MCP 工具：
```
可用工具（<name> 情境）：
  - gitlab
  ※ 其他工具在此情境下不可用
```

## Step 5：自動偵測專案

掃描 cwd 的特徵檔案：

| 特徵 | 專案 |
|---|---|
| `CMakeLists.txt` + `include/mt_unf_*.h` | `nagra-tntsat` |
| `robot/` + `*.robot` | `nagra-tntsat` |
| `project.yml`（Ceedling） | `nagra-tntsat` |
| `Android.bp` 或路徑含 `aosp`/`android`/`1319D` | `android-aosp` |

若偵測到 → 確認：
```
偵測到專案：nagra-tntsat，載入？[Y/n]
```

若未偵測到 → 列出 `<BASE>/projects/` 的 `.md` 檔（排除 `_template.md`）讓 user 選，或輸入 0 跳過。

## Step 6：載入專案層

讀取 `<BASE>/projects/<selected>.md`。

## Step 6.5：cwd CLAUDE.md 偵測

檢查 `<cwd>/CLAUDE.md` 是否存在：

- 若**不存在** → 提示：
  ```
  此目錄尚未建立 CLAUDE.md，要現在建立嗎？[Y/n]
  ```
  若 Y → 觸發 `/init-project-md` skill。

- 若存在但**不是 symlink**（真實檔案）→ 靜默略過（使用者自行管理）。

- 若已是 symlink → 靜默略過。

## Step 7：確認並待命

輸出摘要：
```
## Session Context Loaded
- Mode   : [SECURE / NORMAL]
- Global : core/profile.md + meta-rules.md ✓
- Context: contexts/<name>/ ✓  |  MCP: [工具清單]
- Project: projects/<name>.md ✓
Ready. What are we working on today?
```
