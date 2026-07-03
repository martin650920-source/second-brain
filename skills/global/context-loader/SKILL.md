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

## Step 3：專案操作

### 3.1 先判斷觸發方式與 cwd 現況（不用問使用者）

**先判斷這次是怎麼觸發的（用「這是不是本次對話第一輪」判斷，不要用猜的）：**
- **本次對話目前為止還沒有任何使用者訊息**（這是第一輪）→ 視為**自動觸發**。SessionStart hook 只會在 session 剛開始時注入一次指令，不可能發生在已經有來有往的對話中間，所以「是不是第一輪」是可靠、agent 自己就能判斷的訊號，不需要額外的機制
- **對話中已經有過至少一輪**，使用者這時才說「load context」「載入 context」或輸入 `/context-loader` → 視為**手動觸發**

**再檢查 `<cwd>/CLAUDE.md`：**
- **已是 symlink，且目標檔案存在**：
  - 若是**自動觸發** → 已經連結過，解析 symlink 指向的 `<BASE>/projects/<name>.md` 取得 `<name>`，直接視同選定專案 `<name>`，跳過本 Step 剩餘部分，進入 Step 4（不用每次開 session 都跳選單，已設定好的專案零打擾）
  - 若是**手動觸發** → 使用者主動再叫一次，代表想做點什麼（例如移除、換連結），**一律跳出 3.2 操作選單**，不要因為已連結就跳過
- **已是 symlink，但目標檔案不存在（斷鍊）** → 不論自動/手動觸發，都提示：
  ```
  這個目錄的 CLAUDE.md 連結已失效（原本指向的 <BASE>/projects/<name>.md 不存在了，
  可能是專案已被移除或改名）。
  ```
  然後進入 3.2，讓使用者決定要重新 Link 還是直接用 Remove Project 順手清掉這條殘留 symlink
- **是真實檔案**（尚未接上 ai-workspace）或**完全不存在** → 不論自動/手動觸發，都進入 3.2

### 3.2 操作選單

```
1. Link project（建立/連結專案本體到 ai-workspace）
2. Remove project（清理 ai-workspace 內某專案的殘留檔案）
```

（若當前工具有互動選擇元件如 AskUserQuestion，優先用該元件呈現；否則以文字列出編號，請使用者輸入數字。以下所有選單皆比照辦理。）

---

#### 選 1：Link Project

跳出選單：

```
1. New（建立新專案）
2. <既有專案 1>
3. <既有專案 2>
...（依 <BASE>/projects/ 實際檔案數量列出，排除 _template.md）
N. Skip（跳過，不載入專案層）
```

##### 選到 New

1. 詢問使用者：「新專案名稱？」，取得 `<name>`
2. 判斷 cwd 目前 `CLAUDE.md` 狀態（3.1 已檢查過）：
   - **是真實檔案**（已有內容）→ 讀取全文，直接作為 `<BASE>/projects/<name>.md` 的初始內容寫入，**保留使用者原本寫好的內容，不要用 `/init-project-md` 重新掃描覆蓋**
   - **不存在** → 觸發 `/init-project-md` skill 分析 codebase 生成內容（該 skill Step 2 支援外部指定名稱，直接把 `<name>` 傳入，會跳過它自己的 cwd 衍生邏輯），其餘步驟不變
3. 寫入 `<BASE>/projects/<name>.md` 後，在 ai-workspace 目錄執行 `bash setup/sync.sh link-project <cwd> <name> <flag>`：
   - cwd 原本沒有真實檔案 → 不需要 `<flag>`
   - cwd 原本有真實檔案 → 先問使用者要備份還是直接取代，依答案帶 `--backup`（備份成 `CLAUDE.md.bak-<日期>` 後取代）或 `--force`（直接覆蓋）；不帶 flag 的話指令會直接拒絕執行並報錯，不會誤覆蓋
4. 建立完成後視同選定專案 `<name>`，繼續 Step 4

##### 選到既有專案 `<name>`

- 在 ai-workspace 目錄執行 `bash setup/sync.sh link-project <cwd> <name> <flag>`：
  - cwd 目前 `CLAUDE.md` 不存在或已是 symlink → 不需要 `<flag>`
  - cwd 目前 `CLAUDE.md` 是真實檔案（非 symlink）→ 指令會直接拒絕並報錯（避免誤覆蓋），這時提醒使用者：「這個目錄目前的 CLAUDE.md 是真實檔案，連結既有專案會用 symlink 取代它，目前內容不會自動保留進 ai-workspace，要先備份嗎？[Y/n]」，依答案重跑並帶 `--backup` 或 `--force`
- 這個指令除了建 `<cwd>/CLAUDE.md` symlink，也會**自動建立/更新 `<cwd>/CLAUDE.local.md`**（指向 `rules/global.md`、`mem/global.md`，若該專案有 `rules/projects/<name>/general.md` 或 `mem/projects/<name>.md` 也會一併加進去），不用另外處理
- 視同選定專案 `<name>`，繼續 Step 4

##### 選到 Skip

不建立/連結，提示：
```
已跳過本次專案層載入。之後如果要幫這個目錄接上 ai-workspace：
- 還沒有本體 → 在這個目錄說「建立 CLAUDE.md」或輸入 /init-project-md，會自動建立本體並連結
- 本體已存在於 <BASE>/projects/ → 到 ai-workspace 目錄執行：
    bash setup/sync.sh link-project <這個目錄的路徑> <projects/ 下對應檔名（不含 .md）>
```

---

#### 選 2：Remove Project

1. 列出 `<BASE>/projects/` 底下所有 `.md` 檔（排除 `_template.md`），讓使用者選一個要移除的專案 `<name>`
2. 依序檢查以下四個路徑是否存在，**每一項存在的話都要在對話裡個別詢問使用者是否刪除**（一項一項確認，不要整批刪，讓使用者有機會先自行複製/備份內容再答應）：
   - `<BASE>/projects/<name>.md`
   - `<BASE>/rules/projects/<name>/`（整個資料夾）
   - `<BASE>/mem/projects/<name>.md`
   - `<BASE>/skills/projects/<name>/`（整個資料夾，若有）
3. 若 cwd 目前的 `CLAUDE.md` 剛好是 symlink 且指向這個正要移除的 `<name>` → 一併問使用者要不要順手清掉這個目錄自己的連結
4. 使用者確認完要刪哪些之後，在 ai-workspace 目錄執行**一次**：
   ```bash
   bash setup/sync.sh remove-project <name> --paths=<使用者同意刪除的項目，逗號分隔，從 projects,rules,mem,skills 中挑> [--unlink-cwd]
   ```
   （這個子指令本身不互動、不會再跳確認，只依你組好的參數做確定性刪除——確認的動作在第 2、3 步已經在對話裡問完了。若使用者四項都同意刪，直接不帶 `--paths` 也可以，預設就是全刪）
5. 執行完提示：
   ```
   ai-workspace 內的 <name> 殘留檔案已清理，記得執行 sync.sh push 同步給其他主機。
   注意：其他主機專案目錄下的 CLAUDE.md / CLAUDE.local.md symlink 不在 ai-workspace 管轄範圍，
   不會自動清除，需要你自行到那些主機上手動刪除（例如 rm <專案路徑>/CLAUDE.md）。
   ```
6. 本次不載入專案層，繼續 Step 5（確認並待命）

## Step 4：載入專案層

若有選定專案 `<name>`，依序讀取（存在才讀，不存在靜默跳過）：
1. `<BASE>/projects/<name>.md` — 專案事實（`/init` 產生的 CLAUDE.md 本體）
2. `<BASE>/rules/projects/<name>/general.md` — 專案全域規則
3. `<BASE>/rules/projects/<name>/<topic>.md` — path-scoped 規則（若當前操作路徑符合 frontmatter `paths:`）
4. `<BASE>/mem/projects/<name>.md` — 該專案的累積筆記

## Step 5：確認並待命

輸出摘要：
```
## Session Context Loaded
- Global : rules/global.md ✓
- Project: projects/<name>.md ✓  |  rules: [有/無]  |  mem: [有/無]
Ready. What are we working on today?
```
