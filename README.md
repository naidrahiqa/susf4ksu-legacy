# SUSFS — Pollux Fork

Fork dari [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu.git) branch `kernel-4.19`, dikustomisasi untuk **Redmi 12 (fire / MT6768 / Helio G88)** dengan Pollux Kernel.

## Kenapa Fork?

- Upstream patches sering conflict dengan MTK vendor modifications
- Custom fixup scripts untuk kompatibilitas kernel 4.19.325
- Pre-compiled `susfs` CLI tool (skip build step)
- Auto-detect kernel version & apply patch otomatis
- Custom features: spoof `/proc/cpuinfo`, spoof build fingerprint

## Fitur

### SUSFS Core
- `sus_path` — sembunyikan path dari apps
- `sus_mount` — sembunyikan mount points
- `sus_kstat` — sembunyikan file stats
- `sus_map` — sembunyikan memory maps
- `spoof_uname` — spoof kernel uname
- `spoof_cmdline_or_bootconfig` — spoof cmdline/bootconfig
- `open_redirect` — redirect file open calls
- `hide_ksu_susfs_symbols` — sembunyikan simbol SUSFS dari kernel
- `auto_add_sus_kernel_mappings` — auto-add kernel mappings

### Pollux Additions
- `spoof_cpuinfo` — spoof `/proc/cpuinfo` entries
- `spoof_fingerprint` — spoof `ro.build.fingerprint`
- `auto_apply` — auto-detect kernel version & apply patches
- `precompiled_cli` — pre-built `susfs` binary (arm64)

## Struktur

```
SUSFS-Pollux/
├── kernel/                 # Kernel patch files
│   ├── 50_add_susfs_in_kernel-4.19.patch
│   └── ...
├── userspace/              # susfs CLI tool
│   ├── arm64/
│   │   └── susfs           # Pre-compiled binary
│   └── ...
├── fixup/                  # Python fixup scripts
│   ├── fix_susfs_sched.py
│   ├── fix_susfs_namespace.py
│   ├── fix_supercall_susfs.py
│   └── fix_susfs_selinux.py
├── pollux/                 # Pollux-specific
│   ├── patch_vermagic.py   # Vermagic bypass
│   └── apply.sh            # Auto-apply script
├── AGENTS.md               # AI agent instructions
└── README.md               # This file
```

## Usage

### Auto-Apply (Recommended)
```bash
cd /sdcard/SUSFS-Pollux
bash pollux/apply.sh /path/to/kernel/source
```

### Manual Apply
```bash
# Apply kernel patch
patch -p1 --fuzz=5 < kernel/50_add_susfs_in_kernel-4.19.patch

# Apply fixup scripts
python3 fixup/fix_susfs_sched.py /path/to/kernel/source
python3 fixup/fix_susfs_namespace.py /path/to/kernel/source
python3 fixup/fix_supercall_susfs.py /path/to/kernel/drivers/kernelsu/supercall/supercall.c
python3 fixup/fix_susfs_selinux.py /path/to/kernel/source
```

## Patches

### Core SUSFS
- `kernel/50_add_susfs_in_kernel-4.19.patch` — Main SUSFS patch untuk kernel 4.19

### Pollux Additions
- `pollux/patches/001-spoof-cpuinfo.patch` — Spoof `/proc/cpuinfo` entries
- `pollux/patches/002-spoof-fingerprint.patch` — Spoof `ro.build.fingerprint`
- `pollux/patches/003-auto-apply.patch` — Auto-detect kernel version

### Fixup Scripts
- `fixup/fix_susfs_sched.py` — MTK KABI compatibility for sched.h
- `fixup/fix_susfs_namespace.py` — fs_context-aware mount hiding
- `fixup/fix_supercall_susfs.py` — Type conflicts in supercall.c
- `fixup/fix_susfs_selinux.py` — SUSFS function placement in selinux.c

## Todo

- [ ] Pre-compiled `susfs` CLI binary (arm64)
- [ ] Spoof `/proc/cpuinfo` implementation
- [ ] Spoof `ro.build.fingerprint` implementation
- [ ] Auto-detect kernel version script
- [ ] CI/CD integration test
- [ ] Web-based SUSFS config builder

## Upstream

Based on:
- simonpunk/susfs4ksu `kernel-4.19` branch
- KernelSU-Next `legacy-susfs` branch

## License

Same as susfs4ksu (GPLv2).
