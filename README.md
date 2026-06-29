# 第二大腦（second-brain）

個人 AI 作業系統 — 讓 Claude Code、Gemini CLI、Codex 共用同一份設定、規則與知識，並依情境（工作/生活）自動切換。

## 架構

```
second-brain/
├── core/                    # 全域層（永遠載入）
│   ├── profile.md           # 個人偏好（私密）
│   ├── profile.template.md  # 公開範本
│   └── meta-rules.md        # 衝突優先權規則
├── contexts/                # 情境層（session 開始時選擇）
│   ├── work/                # 工作情境（公司工具白名單）
│   └── life/                # 生活情境（個人工具白名單）
├── projects/                # 專案層（自動偵測）
│   └── _template.md
├── adapters/                # AI 工具轉換層（盡量薄）
│   ├── claude/
│   │   ├── CLAUDE.md        # 全域 bootstrap
│   │   └── projects/        # 各專案目錄的 CLAUDE.md 本體
│   ├── gemini/GEMINI.md
│   └── codex/AGENTS.md
├── skills/
│   ├── context-loader/      # 三層載入邏輯（含 skill drift 偵測）
│   └── init-project-md/     # 為任意專案目錄建立 CLAUDE.md + symlink
├── secrets/
│   └── .template            # 金鑰範本（不含真實值）
├── config/
└── setup/
```

**載入優先序：** 專案層 > 情境層 > 全域層

## 安裝

### WSL
```bash
bash setup/setup-wsl.sh
```

### SSH Remote
```bash
bash setup/setup-ssh.sh git@github.com:yourname/second-brain.git
```

### Windows
```powershell
.\setup\setup-windows.ps1
```

## 日常使用

```
開啟 Claude Code
    ↓
context-loader 自動執行
    ├─ Skill Drift 偵測：有新 skill 未連結？→ 提示建立 symlink
    ├─ 選擇情境（work / life / none）
    ├─ 自動偵測專案（或手動選擇）
    └─ cwd CLAUDE.md 偵測：尚未建立？→ 提示執行 /init-project-md
    ↓
Ready
```

**第一次進入新專案目錄時：**
context-loader 會偵測到 `CLAUDE.md` 不存在，提示執行 `/init-project-md`。
該 skill 會分析 codebase、將本體存入 `adapters/claude/projects/<name>.md`，並在專案目錄建立 symlink。

## 新增工作專案

1. 複製 `projects/_template.md` → `projects/<專案名>.md`
2. 填入專案架構、指令、術語
3. 在 `skills/context-loader/SKILL.md` 的偵測表加入 Marker Files
4. **在 `.gitignore` 加入 `/projects/<專案名>.md`**（避免公司 IP 外流）

## 公私分離

| 進 Git（公開骨架） | 不進 Git（本機+Drive 同步） |
|---|---|
| adapters/, skills/, setup/ | core/profile.md |
| core/meta-rules.md | contexts/*/context.md |
| contexts/*/rules.md | contexts/*/mcp.json |
| projects/_template.md | projects/<工作專案>.md |
| secrets/.template | secrets/.env |

## Secure Mode

安裝時選擇啟用後，AI 工具只能使用當前情境 `mcp.json` 白名單內的工具，工作與個人資產完全隔離。

手動開關：
```bash
touch ~/.second-brain/.secure-mode    # 啟用
rm ~/.second-brain/.secure-mode       # 關閉
```
