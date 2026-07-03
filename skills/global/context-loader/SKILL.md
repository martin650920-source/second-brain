---
name: context-loader
description: >
  兩層 context 載入器（全域 → 專案）。
  在 session 開始時自動觸發（由 adapters bootstrap），
  或 user 說「load context」、「載入 context」時觸發。
---

# Context Loader v3

## Step 1：解析 Base Path

| 環境 | Base Path |
|---|---|
| Windows (PowerShell) | `$env:USERPROFILE\.ai-workspace` |
| WSL / Linux / SSH | `~/.ai-workspace` |

若路徑不存在，停止並回報：
```
`~/.ai-workspace` not found — 請先執行 setup script。
```

## Step 2：載入全域層（必載）

讀取：
1. `<BASE>/rules/global.md` — 個人偏好、AI 行為準則、衝突優先權規則

## Step 2.5：Skill Drift 偵測

比對 `<BASE>/skills/global/` 與 `~/.claude/skills/`，找出有 skill 目錄但**缺少對應 symlink** 的項目。

**Windows（PowerShell）：**
```powershell
$base      = "$env:USERPROFILE\.ai-workspace"
$skillsDir = "$env:USERPROFILE\.claude\skills"
$missing   = Get-ChildItem "$base\skills\global" -Directory |
             Where-Object { -not (Test-Path "$skillsDir\$($_.Name)") }
$missing | ForEach-Object { $_.Name }
```

**WSL / SSH（bash）：**
```bash
base=~/.ai-workspace
for d in "$base/skills/global"/*/; do
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
      -Path "$skillsDir\$($s.Name)" -Target "$base\skills\global\$($s.Name)"
}
```

WSL / SSH：
```bash
for name in $missing_names; do
    ln -sf "$base/skills/global/$name" ~/.claude/skills/"$name"
done
```

若無缺漏 → 靜默跳過，不輸出任何訊息。

## Step 3：選擇專案

列出 `<BASE>/projects/` 底下所有 `.md` 檔（排除 `_template.md`），組成選單：

1. **New**（建立新專案）
2. <既有專案 1>
3. <既有專案 2>
...（依實際檔案數量列出，一個檔名一行）
N. **Skip**（跳過，不載入專案層）

跳出選單讓使用者選擇（若當前工具有互動選擇元件如 AskUserQuestion，優先用該元件呈現；否則以文字列出編號，請使用者輸入數字）。

> 舊版用特徵檔案（CMakeLists.txt / Android.bp 等）自動偵測，改名或新增專案時容易忘記同步更新這份表格
> 導致誤判（本 session 已修過兩次）。改成手動選單後不再需要維護偵測規則。

### 選到 New

1. 詢問使用者：「新專案名稱？」，取得 `<name>`
2. 觸發 `/init-project-md` skill 建立本體與 symlink，**用使用者輸入的 `<name>` 取代該 skill Step 2 的自動衍生名稱**，其餘步驟不變（分析 codebase、寫入 `<BASE>/projects/<name>.md`、建立 symlink）
3. 建立完成後視同選定專案 `<name>`，繼續 Step 4（此時 cwd 已有 symlink，Step 5 會靜默略過）

### 選到既有專案 `<name>`

視同選定專案 `<name>`，繼續 Step 4。

### 選到 Skip

不載入專案層，提示：
```
已跳過本次專案層載入。之後如果要幫這個目錄接上 ai-workspace：
- 還沒有本體 → 在這個目錄說「建立 CLAUDE.md」或輸入 /init-project-md，會自動建立本體並連結
- 本體已存在於 <BASE>/projects/ → 到 ai-workspace 目錄執行：
    bash setup/sync.sh link-project <這個目錄的路徑> <projects/ 下對應檔名（不含 .md）>
```

## Step 4：載入專案層

若有選定專案 `<name>`，依序讀取（存在才讀，不存在靜默跳過）：
1. `<BASE>/projects/<name>.md` — 專案事實（`/init` 產生的 CLAUDE.md 本體）
2. `<BASE>/rules/projects/<name>/general.md` — 專案全域規則
3. `<BASE>/rules/projects/<name>/<topic>.md` — path-scoped 規則（若當前操作路徑符合 frontmatter `paths:`）
4. `<BASE>/mem/projects/<name>.md` — 該專案的累積筆記

## Step 5：cwd CLAUDE.md 偵測

檢查 `<cwd>/CLAUDE.md` 是否存在：

- 若**不存在**：
  - 若 Step 3 已選定**既有專案** `<name>` → 直接建立 symlink（等同 `sync.sh link-project <cwd> <name>`），**不要**觸發 `/init-project-md`（那是重新掃描建全新本體，不是連結既有本體，會誤蓋）
  - 若 Step 3 選的是 **New** → 此時應該已有 symlink（Step 3 已建立），略過
  - 若 Step 3 選的是 **Skip** → 不重複詢問，Step 3 的 Skip 提示已經講過後續怎麼做

- 若存在但**不是 symlink**（真實檔案）→ 靜默略過（使用者自行管理）。

- 若已是 symlink → 靜默略過。

## Step 6：確認並待命

輸出摘要：
```
## Session Context Loaded
- Global : rules/global.md ✓
- Project: projects/<name>.md ✓  |  rules: [有/無]  |  mem: [有/無]
Ready. What are we working on today?
```
