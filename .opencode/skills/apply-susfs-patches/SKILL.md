---
name: apply-susfs-patches
description: Apply SUSFS kernel patches, fixup scripts, and verify patch state on a 4.19 NON-GKI kernel source tree
license: GPL-2.0-only
metadata:
  kernel: "4.19"
  variant: non-gki
---

## When to use

Use this skill when the task involves applying SUSFS patches to a kernel source directory, running fixup scripts, or verifying whether SUSFS patches are correctly applied. This is the primary workflow of the `backport-susf4ksu-legacy` project.

## Workflow

### 1. Check current state

```bash
bash pollux/verify.sh <kernel_dir>
```

If `fs/susfs.c` already exists, patches may already be applied. The auto-apply script (`apply.sh`) is idempotent and will skip if already applied.

### 2. Apply patches (auto)

```bash
bash pollux/apply.sh <kernel_dir>
```

This runs steps 3–5 in sequence and is the recommended path.

### 3. Apply main SUSFS patch

```bash
patch -p1 --fuzz=5 < kernel/50_add_susfs_in_kernel-4.19.patch
```

If this fails, fall back to `wiggle`:
```bash
find <kernel_dir> -name "*.rej" -exec wiggle --replace {} +
```

### 4. Apply KernelSU-Next patch

Apply from within `drivers/kernelsu/` directory (NOT kernel root):

```bash
cd <kernel_dir>/drivers/kernelsu
patch -p1 --fuzz=3 < <susfs_repo>/kernel/KernelSU/10_enable_susfs_for_ksu.patch
```

This patch backports `path_umount`, `get_cred_rcu`, `can_umount` to kernel 4.19 via Makefile `$(shell ...)`.

### 5. Apply additional v2.2.0 patches

```bash
patch -p1 --fuzz=3 < patches/004-sus_map-proc-maps.patch
patch -p1 --fuzz=3 < patches/005-avc-log-spoofing.patch
```

### 6. Run fixup scripts (strict order)

```bash
python3 fixup/fix_susfs_sched.py <kernel_dir>
python3 fixup/fix_susfs_namespace.py <kernel_dir>
python3 fixup/fix_supercall_susfs.py <kernel_dir>/drivers/kernelsu/supercall/supercall.c
python3 fixup/fix_susfs_selinux.py <kernel_dir>
python3 pollux/fix_mtk_includes.py <kernel_dir>
```

### 7. Fix susfs_def.h → susfs.h includes

```bash
find <kernel_dir>/drivers/kernelsu -type f -exec sed -i 's|susfs_def\.h|susfs.h|g' {} +
```

### 8. (Optional) Apply vermagic bypass

For Xiaomi vendor module compatibility:

```bash
python3 pollux/patch_vermagic.py <kernel_dir>
```

### 9. Verify

```bash
bash pollux/verify.sh <kernel_dir>
```

Expected: zero errors, zero `.rej` files.

## Critical constraints

- **Kernel 4.19 ONLY** — upstream patches target 5.x/6.x and will not apply cleanly.
- **`CONFIG_FUSE_PASSTHROUGH`** must be disabled (causes SUSFS deadlock).
- MTK vendor files (`mm/oom_kill.c`, `fs/open.c`, `kernel/sysctl.c`) often conflict — patch with `--fuzz=5`.
- `fixup/gen_extra_hunks.py` is `.gitignore`d and run manually to generate v2.2.0 hunks.
- `upstream-419/`, `upstream-latest/`, `legacy-target/` are gitignored reference clones populated by `prepare_build.sh`.

## Build userspace tool

```bash
cd userspace/src && ndk-build
```

Output: `ksu_susfs` for `arm64-v8a`. Pre-built binary at `userspace/arm64/susfs`.
