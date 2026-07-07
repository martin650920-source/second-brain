# ai-workspace

個人 AI 作業系統 — 讓 Claude Code、Gemini CLI、Codex 共用同一份規則、記憶與知識。

> 前身為 `second-brain`（再更早是 `ai_refrence`）。詳細重構決策紀錄見 [`ai-workspace-design.md`](./ai-workspace-design.md)。

## 架構

```
ai-workspace/
├── rules/                   # 規則層（該怎麼做）
│   ├── global.md            # 全域規則（永遠載入）
│   └── projects/            # 專案規則
│       └── <name>/
│           ├── general.md   # 專案全域規則
│           └── <topic>.md   # path-scoped 規則（frontmatter paths:）
├── mem/                      # 累積筆記層（發生過什麼/學到什麼）
│   ├── global.md
│   └── projects/<name>.md
├── projects/                 # 專案事實層（CLAUDE.md 本體，/init 產生，自動偵測）
│   └── _template.md
├── adapters/                 # AI 工具轉換層（盡量薄，只放 bootstrap 指令）
│   ├── claude/CLAUDE.md
│   ├── gemini/GEMINI.md
│   └── codex/AGENTS.md
├── skills/
│   └── global/
│       ├── context-loader/   # 兩層載入邏輯（含 skill drift 偵測）
│       ├── init-project-md/  # 為任意專案目錄建立 CLAUDE.md + symlink
│       └── wiki-synthesize/  # 週報/wiki 合成
├── config/
└── setup/
    ├── sync.sh                # 日常同步：pull / push / link-project / link-skill
    ├── setup-windows.ps1      # 首次 bootstrap（Windows）
    ├── setup-wsl.sh           # 首次 bootstrap（WSL）
    └── setup-ssh.sh           # 首次 bootstrap（SSH 遠端）
```

**載入優先序：** 專案層 > 全域層

## 安裝（首次 bootstrap，只做一次）

### WSL
```bash
bash setup/setup-wsl.sh
```

### SSH Remote
```bash
bash setup/setup-ssh.sh git@github.com:yourname/ai-workspace.git
```

### Windows
```powershell
.\setup\setup-windows.ps1
```

## 日常同步

已完成 bootstrap 後，日常更新一律用 `sync.sh`（WSL / SSH）：

```bash
bash setup/sync.sh          # git pull + symlink 校驗（斷鍊/新增未連結/孤兒 symlink）
bash setup/sync.sh push     # 先 pull 防覆蓋，再 commit + push
```

新增專案或 skill 的連結：

```bash
bash setup/sync.sh link-project <專案路徑> <專案名>
bash setup/sync.sh link-skill <專案名> <skill名>
```

## 日常使用

```
開啟 Claude Code
    ↓
context-loader 自動執行
    ├─ Skill Drift 偵測：有新 skill 未連結？→ 提示建立 symlink
    ├─ 自動偵測專案（或手動選擇）
    └─ cwd CLAUDE.md 偵測：尚未建立？→ 提示執行 /init-project-md
    ↓
Ready
```

**第一次進入新專案目錄時：**
context-loader 會偵測到 `CLAUDE.md` 不存在，提示執行 `/init-project-md`。
該 skill 會分析 codebase、將本體存入 `projects/<name>.md`，並在專案目錄建立 symlink。

## 新增工作專案

推薦在專案目錄開 Claude Code，走 context-loader 互動選單自動建立本體 + symlink（見 `docs/快速上手指南.md`）。舊版需要手動編輯 `.gitignore` 加專案代號、編輯 `context-loader/SKILL.md` 偵測表兩個步驟，皆已移除，不再需要。

## Git 版控範圍

不做公私分離、不維護白名單。`rules/`、`mem/`、`projects/`（含各工作專案 CLAUDE.md）、`skills/`、`adapters/`、`setup/` 等**全部進 Git**，任何主機新增的內容 `sync.sh push` 之後，其他主機/平台都能同步拿到同一份。

> **沿革：** 最初曾規劃「公開骨架 vs 私密內容（`rules/global.local.md`、`projects/<工作專案>.md`）」的白名單機制，因專案改名/新增時容易忘記同步維護，2026-07-02 已證實造成一次機密外流（已用 `git filter-repo` 清除歷史修復）。2026-07-03 進一步確認：不再區分公私，全部進 Git，機密性由使用者 commit/push 前自行把關。`ai-workspace` repo 目前是 **Public**，這點務必留意。

## MCP 不由 ai-workspace 管理

MCP server 的安裝/設定/憑證**各主機各自獨立處理**，用 Claude Code 原生的 `claude mcp add ...` 即可，不透過 `ai-workspace` 集中管理或同步。哪台主機需要哪個 MCP，就在那台上裝一次；`ai-workspace` 不記錄安裝清單、不同步架構設定或憑證。

> **沿革：** 2026-07-02 設計階段曾規劃 `mcp/settings.json`（架構設定）+ `mcp/.env.example`（憑證範本）+ `mcp/manifest.md`（安裝清單，號稱由 `sync.sh` 自動偵測/自動 push）三件套集中管理機制，但從未真正實作（`sync.sh` 從頭到尾沒有任何 MCP 相關程式碼）。2026-07-03 確認：不需要統一管理，直接維持 Claude Code 原生的各主機獨立模式，相關規劃文件與範本檔案已移除。

## TODO（已知未解決、留給未來的自己）

- `sync.sh` 目前只有 bash 版本（WSL/SSH），Windows 尚無對應的 `sync.ps1`
- 情境層（work/life + Secure Mode MCP 白名單）已在這次重構整套移除，日後有需要再重新設計

## 從舊版 `second-brain` 遷移

GitHub repo 已改名 `second-brain` → `ai-workspace`（2026-07-02）。舊網址 GitHub 會自動重定向一段時間，但建議盡快處理：

1. ~~GitHub repo 改名~~ ✅ 已完成
2. 各主機（含這台機器正式在用的 `~/.second-brain` 指向的舊 clone）重新 clone 或重新命名資料夾 → 待執行
3. 各主機重新執行對應的 `setup-*` 腳本重建 symlink → 待執行
4. 確認每台主機 `git remote -v` 指向新 URL `martin650920-source/ai-workspace.git`（本機已更新，其餘主機需自行確認）

詳見 [`ai-workspace-design.md`](./ai-workspace-design.md) 開頭的改名 Checklist。
