# KernelSU-Next SUSFS Integration

## Overview
This patch integrates SUSFS with KernelSU-Next, which uses a fundamentally different dispatch mechanism compared to official KernelSU (weishu).

| Aspect | Official KernelSU | KernelSU-Next |
|--------|------------------|---------------|
| Syscall hook | `prctl()` | `sys_reboot()` |
| Dispatch function | `ksu_handle_prctl()` | `ksu_handle_sys_reboot()` |
| Magic detection | None (prctl cmd) | `SUSFS_MAGIC` (`0xFAFAFAFA`) |
| Entry file | `kernel/core_hook.c` | `kernel/supercall/dispatch.c` |

## Files Modified

| File | Change |
|------|--------|
| `kernel/Kconfig` | Added "KernelSU - SUSFS" menu with all feature toggles |
| `kernel/Kbuild` | Added auto-detection of `fs/susfs.c` + SUSFS version info |
| `kernel/supercall/dispatch.c` | Added SUSFS switch/case dispatch in `ksu_handle_sys_reboot()` |
| `kernel/core/init.c` | Added `susfs_init()` call in `ksu_init()` |

## Usage

### Auto (via apply.sh)
```bash
bash core-scripts/apply.sh /path/to/kernel/source --kernelsu-next
```

### Manual
```bash
# 1. Apply main SUSFS kernel patch
cd /path/to/kernel/source
patch -p1 --fuzz=5 < /path/to/backport/kernel/50_add_susfs_in_kernel-4.19.patch

# 2. Apply KernelSU-Next integration patch
cd /path/to/KernelSU-Next  # e.g. KernelSU/ or drivers/kernelsu/
patch -p1 --fuzz=3 < /path/to/backport/kernel/KernelSU-Next/007-susfs-for-kernelsu-next.patch
```

## Kconfig Dependencies
- `CONFIG_KSU_SUSFS` depends on `KSU` and `THREAD_INFO_IN_TASK`
- All feature toggles depend on `CONFIG_KSU_SUSFS`
- Default: all features enabled (y)

## Supported Commands
The following CMD_SUSFS commands are dispatched via sys_reboot:

| Command | Kconfig Guard | Description |
|---------|--------------|-------------|
| `CMD_SUSFS_ADD_SUS_PATH` | `KSU_SUSFS_SUS_PATH` | Add hidden path |
| `CMD_SUSFS_ADD_SUS_PATH_LOOP` | `KSU_SUSFS_SUS_PATH` | Add hidden path (loop) |
| `CMD_SUSFS_HIDE_SUS_MNTS_FOR_NON_SU_PROCS` | `KSU_SUSFS_SUS_MOUNT` | Hide mounts |
| `CMD_SUSFS_ADD_SUS_KSTAT` | `KSU_SUSFS_SUS_KSTAT` | Add kstat spoof |
| `CMD_SUSFS_UPDATE_SUS_KSTAT` | `KSU_SUSFS_SUS_KSTAT` | Update kstat spoof |
| `CMD_SUSFS_ADD_SUS_KSTAT_STATICALLY` | `KSU_SUSFS_SUS_KSTAT` | Add static kstat |
| `CMD_SUSFS_SET_UNAME` | `KSU_SUSFS_SPOOF_UNAME` | Spoof uname |
| `CMD_SUSFS_ENABLE_LOG` | `KSU_SUSFS_ENABLE_LOG` | Toggle logging |
| `CMD_SUSFS_SET_CMDLINE_OR_BOOTCONFIG` | `KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG` | Spoof cmdline |
| `CMD_SUSFS_ADD_OPEN_REDIRECT` | `KSU_SUSFS_OPEN_REDIRECT` | Open redirect |
| `CMD_SUSFS_ADD_SUS_MAP` | `KSU_SUSFS_SUS_MAP` | Hide mmap |
| `CMD_SUSFS_ENABLE_AVC_LOG_SPOOFING` | (built-in) | AVC log spoofing |
| `CMD_SUSFS_SHOW_ENABLED_FEATURES` | (built-in) | Show features |
| `CMD_SUSFS_SHOW_VARIANT` | (built-in) | Show variant |
| `CMD_SUSFS_SHOW_VERSION` | (built-in) | Show version |

## Notes
- Placeholder index hashes (`XXXXXXX`) need replacement per actual KernelSU-Next version
- Patch assumes KernelSU-Next directory has `kernel/Kconfig`, `kernel/Kbuild`, `kernel/supercall/dispatch.c`, `kernel/core/init.c`
- If structure differs, adjust paths accordingly
