# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 這個目錄是什麼

`D:\GOOGLE_DRIVE_SYNC` 是 Google Drive 同步根目錄，主要內容：

| 子目錄 | 用途 |
|---|---|
| `ai-workspace/` | AI 個人作業系統（本機透過 symlink 掛載到 `~/.ai-workspace`） |
| `knowledge/` | Obsidian 知識庫（wiki 條目、wiki-inbox） |
| `daily_note/` | 每日筆記（YYYY-MM-DD.md）與每週摘要 |
| `工作/` | 工作相關筆記 |
| `私人/` | 私人筆記 |
| `AI_參考資料/` | 舊版 AI 參考資料（已遷移至 ai-workspace，保留備查） |

## Obsidian Vault 結構

Obsidian vault 根目錄為 `D:\GOOGLE_DRIVE_SYNC\`，結構如下：

```
D:\GOOGLE_DRIVE_SYNC\
├── knowledge/
│   ├── wiki/             # wiki 條目（每週五由 routine 合成）
│   └── wiki-inbox/       # Web Clipper 匯入的 clips，依主題建子資料夾
├── daily_note/
│   ├── weekly-summary/   # 每週摘要（每週五由 routine 產生）
│   └── YYYY-MM-DD.md     # 每日筆記
├── 工作/
├── 私人/
└── ai-workspace/         # AI OS（不屬於 Obsidian 筆記內容）
```

**週五 12:00 自動 Routine（Wiki Synthesize - Friday Noon）：**
- 任務 A：掃描 `knowledge/wiki-inbox/` 近 7 天新 clips → 合成 `knowledge/wiki/` wiki 條目
- 任務 B：讀取 `daily_note/` 近 7 天日誌 → 產生 `daily_note/weekly-summary/YYYY-WNN.md`

## ai-workspace 架構

```
ai-workspace/
├── rules/          # 規則層：global.md（全域）+ projects/<name>/（專案全域/path-scoped）
├── mem/            # 累積筆記：global.md（全域）+ projects/<name>.md（專案）
├── projects/       # 專案事實層（CLAUDE.md 本體，自動偵測或手動選擇）
├── mcp/            # MCP 架構設定 / 憑證範本 / 各主機安裝清單
├── adapters/       # AI 工具轉換層（claude / gemini / codex）
│   └── claude/
│       └── CLAUDE.md          # 全域 bootstrap 指令
├── skills/
│   └── global/     # Claude Code skills（context-loader 等）
├── config/         # statusline.sh 等工具設定
└── setup/          # 安裝腳本（Windows / WSL / SSH）+ sync.sh
```

**載入優先序：** 專案層 > 全域層

## 為什麼要放進 Google Drive 同步

- **不是為了讓同一台機器上的 Windows 和 WSL2 共用一份**——WSL2 本來就能透過 `/mnt/d/` 直接讀寫 D: 槽，檔案只要在 D 槽任一資料夾就已經是同一份實體檔案，跟是不是 Google Drive 同步資料夾無關。
- 真正目的是**跨「不同實體機器」自動同步**（例如桌機 + 筆電），兩邊都裝 Google Drive 桌面版後，內容變更會自動雲端同步，不需要每次手動 `git push`/`pull`。
- Git（`sync.sh push`/`pull`）才是**跨所有主機（含沒有 Google Drive 可掛載的 SSH 遠端）**的正式同步管道；Google Drive 只是「本機也有裝 Google Drive」時的額外即時同步層，兩者並行、不互相取代。

## Symlink 架構

安裝腳本（`setup/setup-windows.ps1`）建立的 symlink：

| 目標（本機） | 來源（Google Drive） |
|---|---|
| `~/.ai-workspace` | `D:\GOOGLE_DRIVE_SYNC\ai-workspace` |
| `~/.claude/CLAUDE.md` | `ai-workspace/adapters/claude/CLAUDE.md` |
| `~/.claude/skills/<name>` | `ai-workspace/skills/global/<name>`（per-skill） |
| `~/.claude/statusline.sh` | `ai-workspace/config/statusline.sh` |
| `~/.gemini/GEMINI.md` | `ai-workspace/adapters/gemini/GEMINI.md` |
| `~/.codex/AGENTS.md` | `ai-workspace/adapters/codex/AGENTS.md` |

**Project-level CLAUDE.md 慣例：**
本體存放於 `projects/<project>.md`，各 project 目錄以 symlink 指向本體。

## 安裝 / 重裝

```powershell
# 需要系統管理員 或 Developer Mode 已開啟
pwsh -ExecutionPolicy Bypass -File setup\setup-windows.ps1
```

## 新增工作專案

**推薦：在專案目錄開 Claude Code，走互動選單**（不用手動編輯任何檔案）：
```
cd <專案目錄>
claude
# session 開始（或手動說「載入 context」）→ 跳出選單：
#   1. Link project → New → 輸入新專案名稱
# 會自動在 ai-workspace/projects/ 建本體、建 symlink
```

**手動方式**（本體已經先寫好時）：
```bash
# 本體放到 ai-workspace/projects/<name>.md 後
bash ~/.ai-workspace/setup/sync.sh link-project <專案路徑> <name>
```

> 舊版需要手動編輯 `.gitignore` 加專案代號、編輯 `context-loader/SKILL.md` 的偵測表加 Marker Files
> 兩個步驟，已經都不需要了：`.gitignore` 白名單機制已移除（見下方「Git 版控範圍」說明），
> `context-loader` Step 3 改用互動選單直接讀 `projects/` 目錄現有檔案，不再需要偵測表。

## Git 版控範圍

所有 workspace 內容——`rules/`、`mem/`、`projects/`（含各工作專案 CLAUDE.md）、`skills/` 等——**一律進 Git**，作為多主機/多平台共用的單一事實來源，不做公私分離、不維護白名單。任何主機新增的 md/skill/rule，只要 `sync.sh push` 就會同步給其他所有主機（含 Google Drive 掛不到的 SSH 遠端）。

> **沿革：** 最初曾規劃「公開骨架進 Git、私密內容（如 `rules/global.local.md`、`projects/<工作專案>.md`）只留在本機 + Google Drive 同步」的白名單機制。但白名單容易因專案改名/新增忘記同步維護，2026-07-02 已證實造成一次機密檔案外流（已用 `git filter-repo` 清除歷史修復）。痛定思痛後決定：乾脆不設限制，所有內容一律進 Git，機密性由使用者 commit/push 前自行把關。`ai-workspace` repo 目前是 **Public**，這點務必留意。

**唯一例外：實際憑證（API key / token）。** 這不算「公私分離」的一部分，是任何情況下都不該進版控的機密。目前 `ai-workspace` 本身沒有任何憑證管理機制（MCP 已確認不由 `ai-workspace` 管理，見下方）；若日後有其他工具需要存真實金鑰，一律放使用者家目錄、不進這個 repo。

## MCP 不由 ai-workspace 管理

MCP server 的安裝/設定/憑證各主機各自獨立處理，用 Claude Code 原生的 `claude mcp add ...` 即可，不透過 `ai-workspace` 集中管理或同步。哪台主機需要哪個 MCP，就在那台上裝一次；`ai-workspace` 不記錄安裝清單、不同步架構設定或憑證。

> **沿革：** 2026-07-02 設計階段曾規劃 `mcp/settings.json`（架構設定）+ `mcp/.env.example`（憑證範本）+ `mcp/manifest.md`（安裝清單，號稱由 `sync.sh` 自動偵測/自動 push）三件套集中管理機制，但從未真正實作（`sync.sh` 從頭到尾沒有任何 MCP 相關程式碼）。2026-07-03 確認：不需要統一管理，直接維持 Claude Code 原生的各主機獨立模式，相關規劃文件與範本檔案已移除。

## Claude Code 設定（`~/.claude/settings.json`）

### SessionStart Hook

每次 session 開始時自動執行：
1. **SSH 環境**：`git pull ~/.ai-workspace`（同步最新 ai-workspace）
2. **所有環境**：注入指令讓 Claude 執行 `/context-loader`

Hook 存放於各機器的 `~/.claude/settings.json`，**不進 Git**（屬於本機設定）。

### SSH 主機初始設定

SSH 主機完成 `setup-ssh.sh` 後，貼上以下指令設定 hook：

```bash
python3 << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
hook_cmd = """if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then git -C "$HOME/.ai-workspace" pull --quiet 2>/dev/null || true; fi; echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"IMPORTANT: 立即執行 /context-loader skill 以載入 ai-workspace context（rules、專案層）。請在回應使用者之前先完成此步驟。"}}'"""

os.makedirs(os.path.expanduser("~/.claude"), exist_ok=True)

settings = {}
if os.path.exists(settings_path):
    with open(settings_path, encoding="utf-8") as f:
        settings = json.load(f)

settings.setdefault("hooks", {})["SessionStart"] = [
    {"hooks": [{"type": "command", "command": hook_cmd, "shell": "bash"}]}
]

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print("Done:", settings_path)
PYEOF
```

## 日常同步

```bash
bash setup/sync.sh          # git pull + symlink 校驗
bash setup/sync.sh push     # git pull（防覆蓋）→ commit → push
```
