# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 這個目錄是什麼

`D:\GOOGLE_DRIVE_SYNC` 是 Google Drive 同步根目錄，主要內容：

| 子目錄 | 用途 |
|---|---|
| `second-brain/` | AI 個人作業系統（本機透過 symlink 掛載到 `~/.second-brain`） |
| `knowledge/` | Obsidian 知識庫（wiki 條目、wiki-inbox） |
| `daily_note/` | 每日筆記（YYYY-MM-DD.md）與每週摘要 |
| `工作/` | 工作相關筆記 |
| `私人/` | 私人筆記 |
| `AI_參考資料/` | 舊版 AI 參考資料（已遷移至 second-brain，保留備查） |

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
└── second-brain/         # AI OS（不屬於 Obsidian 筆記內容）
```

**週五 12:00 自動 Routine（Wiki Synthesize - Friday Noon）：**
- 任務 A：掃描 `knowledge/wiki-inbox/` 近 7 天新 clips → 合成 `knowledge/wiki/` wiki 條目
- 任務 B：讀取 `daily_note/` 近 7 天日誌 → 產生 `daily_note/weekly-summary/YYYY-WNN.md`

## second-brain 架構

```
second-brain/
├── core/           # 全域層（每次 session 必載）
├── contexts/       # 情境層（work / life，session 開始時選擇）
├── projects/       # 專案層（自動偵測或手動選擇）
├── adapters/       # AI 工具轉換層（claude / gemini / codex）
│   └── claude/
│       ├── CLAUDE.md          # 全域 bootstrap 指令
│       └── projects/          # 各 project 目錄的 CLAUDE.md 本體
├── skills/         # Claude Code skills（context-loader 等）
├── config/         # statusline.sh 等工具設定
├── secrets/        # 金鑰範本（不含真實值）
└── setup/          # 安裝腳本（Windows / WSL / SSH）
```

**載入優先序：** 專案層 > 情境層 > 全域層

## Symlink 架構

安裝腳本（`setup/setup-windows.ps1`）建立的 symlink：

| 目標（本機） | 來源（Google Drive） |
|---|---|
| `~/.second-brain` | `D:\GOOGLE_DRIVE_SYNC\second-brain` |
| `~/.claude/CLAUDE.md` | `second-brain/adapters/claude/CLAUDE.md` |
| `~/.claude/skills/<name>` | `second-brain/skills/<name>`（per-skill） |
| `~/.claude/statusline.sh` | `second-brain/config/statusline.sh` |
| `~/.gemini/GEMINI.md` | `second-brain/adapters/gemini/GEMINI.md` |
| `~/.codex/AGENTS.md` | `second-brain/adapters/codex/AGENTS.md` |

**Project-level CLAUDE.md 慣例：**  
本體存放於 `adapters/claude/projects/<project>.md`，各 project 目錄以 symlink 指向本體。

## 安裝 / 重裝

```powershell
# 需要系統管理員 或 Developer Mode 已開啟
pwsh -ExecutionPolicy Bypass -File setup\setup-windows.ps1
```

## 新增工作專案

```powershell
# 1. 複製範本
Copy-Item projects\_template.md projects\新專案名.md

# 2. 填入內容後，加入 .gitignore（避免公司 IP 外流）
Add-Content .gitignore "/projects/新專案名.md"

# 3. 在 skills/context-loader/SKILL.md 的 Step 5 偵測表加入 Marker Files
```

## 公私分離（Git 管理規則）

| 進 Git（公開骨架） | 不進 Git（本機 + Drive 同步） |
|---|---|
| `adapters/`, `skills/`, `setup/` | `core/profile.md` |
| `core/meta-rules.md` | `contexts/*/context.md`, `contexts/*/mcp.json` |
| `contexts/*/rules.md` | `projects/<工作專案>.md` |
| `projects/_template.md` | `secrets/.env` |

## Secure Mode

```powershell
# 啟用（只允許 mcp.json 白名單工具）
New-Item -ItemType File "$env:USERPROFILE\.second-brain\.secure-mode"

# 關閉
Remove-Item "$env:USERPROFILE\.second-brain\.secure-mode"
```
