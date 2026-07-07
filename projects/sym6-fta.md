# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo shape (read this first)

Unlike some sibling checkouts of this SDK, **this is a single flat git repository** rooted at the
project directory (one `.git` here, no `.repo` manifest, no per-subdirectory `.git`s). The actual DDK
source lives under `ddk/`, committed directly into this repo (see commit `e9815faf1 Add ddk directory`).
`git log` / `git diff` / `git blame` work normally from anywhere in the tree — no need to `cd` into
subdirectories like on repo-tool-based checkouts of this SDK.

`ddk/Makefile`, `ddk/Kconfig`, `ddk/envsetup`, `ddk/component/Makefile` are symlinks:
```
ddk/Makefile          -> build/script/Makefile-top
ddk/Kconfig           -> build/script/Kconfig-top
ddk/envsetup          -> build/script/envsetup-top
ddk/component/Makefile -> ../build/script/Makefile-component
```
Edit the real files under `ddk/build/script/`, not the symlinks.

This is a vendor DTV SoC DDK (MStar/MediaTek "Montage" platform, chip family "Symphony"; this checkout
targets `symphony6` / board `chicago_tee`). It is the **FTA (Free-To-Air) variant** — no conditional-access
/ smart-card middleware is integrated (no `pesi/`, no Nagra CA modules; the only Nagra reference is a
sample smart-card test app under `Brief_Sample/smart_card/`). Building requires proprietary
cross-toolchains at fixed absolute paths (see Build System below) that are almost certainly not present in
a typical dev sandbox — treat `make` as something to reason about, not something to routinely execute,
unless you've confirmed the toolchain exists.

## Build System

All builds happen from `ddk/` (the SDK root, referred to as `SDK_DIR` throughout the Makefiles).

1. **Set up environment** — sources `ddk/envsetup`, which sets `SDK_DIR`, `MFRS_CFG` (product config file
   name, default `symphony6.cfg`), and toolchain/ccache flags:
   ```bash
   cd ddk
   source envsetup [<config>.cfg] [ccache]
   ```
   Valid `<config>.cfg` values are any file under `product/configs/*.cfg`, e.g.:
   `symphony6_tee.cfg`, `symphony6_tee_gst.cfg`, `symphony6_tee_nor.cfg`, `symphony6_tee_pip.cfg`,
   `symphony6_tee_chrome.cfg`, `symphony6_tee_release.cfg`,
   `symphony6_32user_32kernel_tee.cfg` (and `_gst` / `_loader` variants).

2. **Configure** — Kconfig-based, top menu defined in `ddk/Kconfig` (→ `build/script/Kconfig-top`),
   selecting chip (`symphony1/2/4/6`, `aria`), arch (mips/arm/aarch64), board (`MFRS`), DDR size, etc.
   ```bash
   make menuconfig        # edit product/configs/$MFRS_CFG interactively
   make syncconfig         # regenerate generated/autoconf.h from the current .config
   make kernel_menuconfig  # edit the Linux kernel defconfig under product/configs/kernel_configs/
   ```

3. **Build** — `make` (or explicit `make all`) drives `mall`, which builds subsystems in this order:
   `kernel` → `common` → `buildroot_step1` → `debug_tools` → `msp` → `buildroot_step2` →
   `buildroot_step999` → `kware` → `comp` (component) → `sample` → `mboot`, then packages firmware/flash
   images. Use `make j=<N>` to override the parallel job count (defaults to CPU count, capped at 32).

   Each subsystem has its own `<target>`, `<target>_clean`, `<target>_install`, `<target>_uninstall`
   targets (see `ddk/Makefile` / `make help` for the full list): `kernel`, `common`, `msp`, `kware`,
   `comp`, `buildroot_*`, `sample`, `wb`, `mboot`, `firmware`, `chip-verification`.

   ```bash
   make            # full build: mall + firmware + flash
   make clean      # mclean + buildroot_clean
   make kernel     # build just the Linux kernel + uImage
   make msp        # build just msp/ (drv + api)
   make common     # build just common/ (drv + api)
   make kware      # build just kware/ middleware
   make comp       # build just component/ (ported OSS libs)
   make mboot      # build the U-Boot-based bootloader
   make flash      # package a flashable image (product/$(MFRS) → image/$(MFRS))
   ```

4. **Per-subsystem builds**: individual driver/api directories (`msp/drv/<module>`, `common/api/<module>`,
   etc.) are plain kbuild-style or recursive Makefiles and can usually be built directly with
   `make -C <dir>` once the top-level environment (`source envsetup`) has run once, since most variables
   (`CC`, `CFLAGS`, `SDK_DIR`, `INCLUDE_DIR`, ...) come from `build/script/env.mk` / `base.mk` via
   `include`, not from the calling shell.

Key build variable sources, if you need to trace how a flag or path is derived:
- `build/script/base.mk` — CFLAGS/warning policy, arch defines, top-level `include` chain
- `build/script/env.mk` — all path variables (`COMMON_DIR`, `MSP_DIR`, `KWARE_DIR`, `BUILDROOT_DIR`,
  toolchain paths per arch/chip, output dirs under `out/general` or `out/loader`)
- `build/script/kern_lib.mk`, `build/script/Makefile-ko.rule`, `Makefile-lib.rule`, `Makefile-app.rule` —
  the generic rules used by leaf-directory Makefiles to build kernel modules, static/shared libs, apps

**No unit test framework exists in this codebase.** `chip-verification` (`VERIFICATION_DIR`) and `wb`
(`WB_DIR`) are on-target hardware verification suites, not host-runnable tests; there is no host-side
`make test` / CI test target.

## Flashing / bring-up (from `ddk/Brief_Sample/readme.txt`)

```bash
./patch_sdk.sh ../linux
cd ../linux && source envsetup symphony4_512.cfg && make
```
Images land under `linux/image/boston/output-board_lqfp_std_v30/update_fta30/`. Flash via USB + uboot
shell script (`update_512_spinand_encrypt.vbs` etc. run through SecureCRT). This sample readme references
an older `symphony4_512` config path — treat it as illustrative of the flash workflow, not as the
authoritative config for this checkout (default here is `symphony6*`, board `chicago_tee`).

## Architecture

The DDK is layered from kernel space up to userspace middleware, plus parallel bootloader/TEE trees:

```
kernel/linux-x.y.z          Vendor-patched Linux kernel (arch/{arm,arm64,mips} per chip)
  common/drv/                Kernel modules: cross-chip base infra (osal, mem, mmz, log, module, sys, cache, dump, file)
  msp/drv/                   Kernel modules: chip/media-specific drivers (demux, avplay, frontend, hdmi20, dai,
                              adec/aenc, cipher_scpu, crypto_engine, gpio, i2c, ir, jpeg, gfx2d, ...)
common/api/, msp/api/         Userspace libraries wrapping the drv/ kernel modules (ioctl-based), headers in
                              common/inc + common/api/inc + common/drv/inc, msp/inc + msp/api/inc + msp/drv/inc
                              ("unf" = unified API, e.g. msp/inc/mt_unf_*.h is the public userspace-facing API surface)
kware/                       Middleware: mtos (in-house RTOS-style task/sem/mutex/timer abstraction used by
                              driver-adjacent code, kware/mtos), fastplayer, drm_adapter, media, lzma, libdownload,
                              ci_route_ts, mtlzswplayer
component/                   Ported third-party/OSS libraries built against the DDK toolchain+sysroot:
                              directfb, bento4, ffmpeg (component/media/framework/ffmpeg), jemalloc, ncurses,
                              neon, network, bluetooth, hdmi20, kexec, gperftools, linux-fusion
buildroot/                   Buildroot-based root filesystem + toolchain package build
tee/                         TrustZone TEE (OP-TEE-based): arm32/ and arm64/ secure-world trees, xtest
mboot/                       U-Boot-based bootloader, ATE (auto test equipment) hooks, DDR parameter generator
loader/                      Separate minimal "loader" product build (own apps/msp/product tree, selected via
                              CFG_MT_BUILD_LOADER, outputs to out/loader instead of out/general)
product/                     Board/product definitions: product/configs/*.cfg (top-level Kconfig defconfigs per
                              board+feature combo), product/configs/kernel_configs/ (kernel defconfigs),
                              product/chicago_tee* (per-board flash layout, ubinize configs, boot args)
Brief_Sample/                Sample apps demonstrating individual driver/API usage (one dir per feature area:
                              demux, blindscan, cipher_*, ac4, hdmi, smart_card, etc.) — good place to see an
                              API's expected call sequence
image/, pub/                 Build output: pub/ holds installed static/shared libs, kernel modules, headers;
                              image/$(MFRS)/ is the assembled, flashable per-board image
tools/                       Host-side tools: prebuilt cross-toolchains under tools/prebuilts, flashing/image
                              tools (mksquashfs, mkfs.ubifs, ubinize) under tools/linux
docs/ForRelease/             Vendor-provided PDF/CHM user guides (SDK, Kconfig, Mboot, driver test cases) —
                              check here before guessing at undocumented driver/API behavior
```

Chip variants supported by the Kconfig (`Kconfig` → `MT_CHIP_SYMPHONY{1,2,4,6}` / `MT_CHIP_ARIA`) map to
different kernel architectures: `symphony1/2` = MIPS, `symphony4`/`aria` = ARM32 (kernel and userspace both
32-bit). `symphony6` is special-cased with two independent choices — 32/64-bit **kernel** space
(`MT_32BIT_KMODE`/`MT_64BIT_KMODE`) and 32/64-bit **userspace** (`MT_32BIT_MODE`/`MT_64BIT_MODE`) — so a
symphony6 build can be pure 32-bit, pure 64-bit, or 32-bit userspace over a 64-bit kernel; 64-bit userspace
requires a 64-bit kernel (`MT_64BIT_MODE depends on MT_64BIT_KMODE` in `Kconfig`).

Firmware for the AV/media co-processor (`make firmware`) builds from `$(AV_RTOS_DIR)`
(`${SDK_DIR}/av_rtos/platform`), which may not be part of this checkout — if that directory is absent,
firmware-related build targets will fail by design; don't try to "fix" a missing `av_rtos/` directory
without checking whether it's simply not checked out here.

## Coding conventions observed in the tree

- Kernel-space code (`*/drv/`) is straight Linux kernel-module style C; userspace code (`*/api/`,
  `kware/`, `component/`) is compiled with `-Wall -Wformat=2 -Wstrict-prototypes -Wshadow` plus several
  `-Werror=` flags for pointer/int conversions and implicit declarations (see `build/script/base.mk`) —
  new userspace code must not introduce these warnings-as-errors.
- Public userspace-facing API headers are prefixed `mt_unf_*.h` (e.g. `msp/inc/mt_unf_hdmi.h`,
  `msp/inc/mt_unf_frontend.h`) — this is the "unified interface" surface other code and sample apps
  (`Brief_Sample/`) are expected to include.
