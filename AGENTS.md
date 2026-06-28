# AGENTS.md — SUSFS Backport (Legacy/Universal)

**Backport** dari [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu.git) — membawa fitur SUSFS v2.2.0+ (SUS_MAP, AVC spoof, sus_su, dll.) ke kernel lawas (4.19, NON-GKI).  
**Universal** — tidak terikat device tertentu. Script pembantu untuk vendor spesifik (MTK, Xiaomi) dipisahkan.  
**Dependency project** — bukan standalone. Di-clone dan di-apply ke kernel source via `prepare_build.sh`.

## Patch Application (harus urut)

Jalankan `bash core-scripts/apply.sh <kernel_dir> [--mtk] [--xiaomi-vermagic]` — ini melakukan semua langkah di bawah.  
Langkah manual jika tidak pakai script:

1. **Main SUSFS patch** — `kernel/50_add_susfs_in_kernel-4.19.patch`  
   `patch -p1 --fuzz=5 < kernel/50_add_susfs_in_kernel-4.19.patch`

2. **KernelSU-Next patch** — `kernel/KernelSU/10_enable_susfs_for_ksu.patch`  
   Apply ke `drivers/kernelsu/` (bukan kernel source root). Patch ini juga backport `path_umount`, `get_cred_rcu`, `can_umount` ke kernel 4.19 via Makefile `$(shell ...)`.

3. **Additional v2.2.0 patches** — `patches/004-sus_map-proc-maps.patch` (SUS_MAP hooks di `task_mmu.c`) dan `005-avc-log-spoofing.patch` (spoof AVC log di `avc.c`).

4. **Fixup scripts** (urut):
   ```bash
   python3 fixup/fix_susfs_sched.py <kernel_dir>                 # MTK KABI compat
   python3 fixup/fix_susfs_namespace.py <kernel_dir>             # mount hiding hooks
   python3 fixup/fix_supercall_susfs.py <supercall.c>            # type conflicts
   python3 fixup/fix_susfs_selinux.py <kernel_dir>               # selinux.c placement
   python3 vendor/mediatek/fix_mtk_includes.py <kernel_dir>     # Clang compat MTK headers
   ```

5. **Fix includes** — KernelSU-Next source must use `susfs.h`, not `susfs_def.h`:
   ```bash
   find <kernel_dir>/drivers/kernelsu -type f -exec sed -i 's|susfs_def\.h|susfs.h|g' {} +
   ```

6. **Vermagic bypass** (opsional, untuk vendor module Xiaomi):
   `python3 vendor/xiaomi/patch_vermagic.py <kernel_dir>`

## Critical Constraints

- **Kernel 4.19 ONLY** — patch dari upstream 5.x/6.x tidak akan apply.
- **FUSE passthrough DISABLED** — `CONFIG_FUSE_PASSTHROUGH` causes deadlock.
- **MTK vendor files sering conflict**: `mm/oom_kill.c`, `fs/open.c`, `kernel/sysctl.c`. Patch dengan `--fuzz=5`, fallback ke `wiggle` jika tersedia.
- **`fixup/gen_extra_hunks.py`** — generate extra diff hunks untuk v2.2.0 features (SUS_MAP, AVC spoof) dan append ke patch utama. Dijalankan manual, di-`.gitignore`.
- **`.rej` files** = gagal patch. Cari dengan `core-scripts/verify.sh`.
- **`legacy-target/`, `upstream-419/`, `upstream-latest/`** = reference clones upstream, isinya kosong di repo (di-`.gitignore`), diisi saat `prepare_build.sh` clone.

## Build SUSFS CLI Tool

```bash
cd userspace/src && ndk-build
```
Hasilnya `ksu_susfs` binary untuk `arm64-v8a`. Pre-built binary sudah ada di `userspace/arm64/susfs`.

## Key Files

| File | Isi |
|------|-----|
| `kernel/fs/susfs.c` | Implementasi SUSFS kernel module (1118 baris) |
| `kernel/include/linux/susfs.h` | Header SUSFS (included dari KernelSU) |
| `kernel/KernelSU/10_enable_susfs_for_ksu.patch` | Patch KernelSU source + Kconfig options |
| `patches/004-sus_map-proc-maps.patch` | SUS_MAP hooks |
| `patches/005-avc-log-spoofing.patch` | AVC log spoofing |
| `core-scripts/verify.sh` | Verification script — jalankan setelah apply |
| `core-scripts/apply.sh` | Auto-apply script (bash) |

## Auto-apply script (`core-scripts/apply.sh`)

Mendeteksi apakah SUSFS sudah diapply (cek `fs/susfs.c`), apply main patch dengan `--fuzz=5`, fallback ke `wiggle`, lalu apply semua `patches/*.patch`, dan semua fixup scripts. Menerima flag `--mtk` dan `--xiaomi-vermagic` untuk perbaikan vendor khusus. **Idempotent** — skip jika `fs/susfs.c` sudah ada.

## Upstream

- Original: `simonpunk/susfs4ksu` branch `kernel-4.19`
- Reference clones: `upstream-419/` (branch kernel-4.19), `upstream-latest/` (branch `main` — kernel 5.x/6.x, jangan dicampur)
