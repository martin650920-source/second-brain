# SYM6-FTA 專案筆記

## 2026-07-07

- pesi middleware 已整合進 SYM6-FTA 並 push（commit `de557e13a` 整合、`f127c310a` 修 bug；
  遠端 `git@10.1.4.203:offical_project/montage/SYM6-FTA.git`，master 直推）。
- rd205（/src/martin_wang/project/SYM6-FTA）已完成首次全量建置（`make mall` 約 30–40 分），
  日常改 `Brief_Sample/` 或 `pesi/` 只需 `cd ddk && source envsetup symphony6_tee.cfg && make sample`。
  改 pesi 的 config header（pv_cfg.inc / pvwarecfg.h）要 `make pesi_clean sample`（pesi Makefile 無 header 相依追蹤）。
- **pesi 是 32-bit 出身**（TNTSAT 32-bit userspace），本案 64-bit userspace 已踩到一例：
  `os_pesi/convert_os.c` 的 `msSemaId` 用 `u32` 存 pointer-sized handle → 高半溢出被 "semaN" 字串蓋掉
  → `sem_wait` 垃圾指標 SIGSEGV（板上驗證修復）。之後怪 crash 優先懷疑同族問題
  （u32 存指標／`%x` 印 64-bit／對齊假設）。
- **core 分析流程**（rd205 的 aarch64 gdb 內嵌 Python 壞，不可用）：
  dmesg 取 pc/lr/x29 → `readelf -n core` 的 NT_FILE 段找 pc 所屬映射與 offset →
  手動走 frame-pointer 鏈（build 有 `-fno-omit-frame-pointer`）→
  `aarch64-none-linux-gnu-addr2line -f -C -e out/general/Brief_Sample/mt_sample <addr...>`。
  mt_sample 是 non-PIE（`-Ttext-segment=0x100400000`），vaddr 直接餵 addr2line 即可。
- `PESI_PTDEBUG=1`（oemmake/mtg/pvwarecfg.h）= emon 測試指令模式（pesi_init 會返回、sample CLI 存活）；
  6 個死掉的測試指令已用 `develop/pt_stubs.c` 空實作補起來。
- build 產物用 `.git/info/exclude` + `git update-index --skip-worktree` 隱藏（未還原，保增量編譯）；
  切分支若被擋，`git update-index --no-skip-worktree <file>` 解除。
