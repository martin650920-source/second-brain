# Meta Rules — 載入優先權

## 衝突解決原則

當不同層級的設定衝突時，遵循此優先序：

**專案層 > 情境層 > 全域層**

| 層級 | 來源 | 說明 |
|---|---|---|
| 全域層 | `core/profile.md` | 所有 session 都套用的基底偏好 |
| 情境層 | `contexts/<name>/rules.md` | 工作或生活情境的專屬規則 |
| 專案層 | `projects/<name>.md` | 當前 repo 的特定規定 |

## 範例

- global 說「繁體中文」，context 沒有特別指定 → 套用「繁體中文」
- global 說「條列式回答」，project 說「commit message 用英文」→ commit message 用英文，其他回答仍條列式繁體中文
- context/work 說「不使用個人工具」，project 沒有說 → 套用 work 的限制

## 每日筆記操作慣例

當 user 說「加到我每日筆記」：
- 找到 `D:\GOOGLE_DRIVE_SYNC\daily_note\<今日日期>.md`，直接寫入
- 待辦/TODO → 加到 `# Day planner` 區塊末尾，格式：`- [ ] <內容>`
- 若 `# Day planner` 不存在，先在檔案末尾建立該區塊再加入
- 若今日檔案不存在，建立新檔並加入 `# Day planner` 區塊

## MCP 規則（Secure Mode）

**白名單制**：只載入當前情境 `mcp.json` 列出的工具。

- `work` 情境 → 只有公司工具可用，個人工具不存在
- `life` 情境 → 只有個人工具可用，公司工具不存在
- 未列入白名單的 MCP 視為不存在，不得呼叫
- Secure Mode 開啟時，若被要求使用白名單外的工具，須拒絕並說明原因
