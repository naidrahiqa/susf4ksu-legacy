# AGENTS.md — SUSFS-Pollux

Fork dari [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu.git) branch `kernel-4.19`, dikustomisasi untuk **Redmi 12 (fire / MT6768 / Helio G88)** dengan Pollux Kernel.

## Project

Ini adalah **dependency project** — bukan standalone. Di-clone oleh `pollux_kernel_fire/pollux/scripts/prepare_build.sh` ke dalam `susfs4ksu/` directory. Kernel patches di-apply dari sini ke kernel source.

## Critical Constraints

### 1. Kernel 4.19 only
Patches dari upstream yang target kernel lebih baru (5.x, 6.x) **tidak akan apply**.

### 2. Fuzz + Wiggle fallback
Patches sering conflict dengan MTK vendor modifications. Build script handle ini otomatis:
```bash
patch -p1 --fuzz=5 < susfs_patch_to_4.19.patch || true
# Auto-wiggle rejected hunks
```

### 3. susfs_def.h → susfs.h mapping
KernelSU-Next source patches wajib include `susfs.h`, bukan `susfs_def.h`. Build script auto-patches:
```bash
sed -i 's|#include <linux/susfs_def.h>|#include <linux/susfs.h>|g' drivers/kernelsu/**/*.c
```

### 4. FUSE passthrough DISABLED
`# CONFIG_FUSE_PASSTHROUGH is not set` — enabling causes SUSFS deadlock.

### 5. MTK vendor files yang sering conflict
- `mm/oom_kill.c` — MTK OOM extensions
- `fs/open.c` — MTK filesystem hooks
- `kernel/sysctl.c` — MTK sysctl additions

## Project Structure

```
SUSFS-Pollux/
├── opencode.json              # OpenCode AI config
├── AGENTS.md                  # This file — AI agent instructions
├── README.md                  # Project documentation
├── .gitignore                 # Git ignore rules
├── kernel/                    # Kernel patch files
│   └── 50_add_susfs_in_kernel-4.19.patch   # Main SUSFS patch
├── userspace/                 # Pre-built binaries
│   └── arm64/
│       ├── susfs              # SUSFS CLI tool (pre-compiled)
│       └── busybox            # Busybox for ARM64
├── fixup/                     # Python fixup scripts
│   ├── fix_susfs_sched.py     # MTK KABI compat for sched.h
│   ├── fix_susfs_namespace.py # fs_context-aware mount hiding
│   ├── fix_supercall_susfs.py # Type conflicts in supercall.c
│   └── fix_susfs_selinux.py   # Function placement in selinux.c
├── pollux/                    # Pollux-specific
│   ├── apply.sh               # Auto-apply script
│   ├── patch_vermagic.py      # Vermagic bypass for 4.19
│   └── verify.sh              # Verification script
└── patches/                   # Additional patches
    ├── 001-spoof-cpuinfo.patch
    ├── 002-spoof-fingerprint.patch
    └── 003-auto-apply.patch
```

## Patch Application Flow

### Auto (from prepare_build.sh)
```bash
# 1. Clone repo
git clone -b kernel-4.19 --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git susfs4ksu

# 2. Apply kernel patch
patch -p1 --fuzz=5 < susfs4ksu/kernel/50_add_susfs_in_kernel-4.19.patch

# 3. Apply fixup scripts
python3 fixup/fix_susfs_sched.py .
python3 fixup/fix_susfs_namespace.py .
python3 fixup/fix_supercall_susfs.py drivers/kernelsu/supercall/supercall.c
python3 fixup/fix_susfs_selinux.py .

# 4. Fix includes
sed -i 's|#include <linux/susfs_def.h>|#include <linux/susfs.h>|g' drivers/kernelsu/**/*.c
```

### Manual (on-device)
```bash
cd susfs4ksu
bash pollux/apply.sh /path/to/kernel/source
```

## SUSFS Features

| Feature | Config Option | Description |
|---------|---------------|-------------|
| `sus_path` | `CONFIG_KSU_SUSFS_SUS_PATH` | Hide paths from apps |
| `sus_mount` | `CONFIG_KSU_SUSFS_SUS_MOUNT` | Hide mount points |
| `sus_kstat` | `CONFIG_KSU_SUSFS_SUS_KSTAT` | Hide file stats |
| `sus_map` | `CONFIG_KSU_SUSFS_SUS_MAP` | Hide memory maps |
| `spoof_uname` | `CONFIG_KSU_SUSFS_SPOOF_UNAME` | Spoof kernel uname |
| `spoof_cmdline` | `CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG` | Spoof cmdline |
| `open_redirect` | `CONFIG_KSU_SUSFS_OPEN_REDIRECT` | Redirect file open |
| `hide_symbols` | `CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS` | Hide SUSFS symbols |
| `auto_add_mappings` | `CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KERNEL_MAPPINGS` | Auto kernel mappings |

## Shell Scripting Rules

- **mksh compatibility** — Android `/system/bin/sh` is mksh. No bash arrays, no `[[ ]]`.
- **No `local` in top-level while loops** — mksh silently crashes.
- **Verify writes** — always readback after writing to sysfs/procfs.

## Audit Checklist

1. `fs/susfs.c` exists (SUSFS kernel patch applied)
2. `include/linux/susfs.h` exists (not `susfs_def.h`)
3. SUSFS flags in KernelSU Makefile match defconfig
4. No `.rej` files remaining after patch application
5. `susfs` CLI binary exists in userspace
6. No kernel 5.x/6.x patches mixed in
7. MTK vendor files (`mm/oom_kill.c`, `fs/open.c`, `kernel/sysctl.c`) not broken

## Upstream

- Original: `simonpunk/susfs4ksu` branch `kernel-4.19`
- Fork: `YOUR_USERNAME/SUSFS-Pollux` branch `kernel-4.19`

## License

GPLv2 (same as susfs4ksu).
