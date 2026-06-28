# SUSFS Backport — Legacy / Universal

> **Backport** [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu.git) v2.2.0+ ke kernel lawas (4.19, NON-GKI).  
> Universal — tidak terikat device tertentu.

---

## Daftar Isi

- [Deskripsi](#deskripsi)
- [Fitur](#fitur)
- [Struktur Proyek](#struktur-proyek)
- [Cara Penggunaan](#cara-penggunaan)
  - [Auto (via apply.sh)](#auto-via-applysh)
  - [Manual](#manual)
  - [Verifikasi](#verifikasi)
- [Integrasi KernelSU](#integrasi-kernelsu)
- [Build Susfs CLI](#build-susfs-cli)
- [Referensi Clone](#referensi-clone)
- [Kredit](#kredit)

---

## Deskripsi

Repositori ini menyediakan kumpulan **patch kernel, fixup script, dan konfigurasi** untuk membawa SUSFS (SUS Filesystem) ke kernel 4.19 NON-GKI.

SUSFS adalah modul kernel untuk KernelSU yang menyediakan:

- **Path hiding** — sembunyikan path dari deteksi root
- **Mount hiding** — sembunyikan mount point dari `/proc/self/mounts`
- **Kstat spoofing** — spoof stat file/directory
- **Memory map hiding (SUS_MAP)** — sembunyikan library yang di-mmap
- **AVC log spoofing** — spoof SELinux audit log
- **Sus-SU** — non-kprobe root shell tanpa deteksi
- **Uname / cmdline spoofing** — spoof informasi kernel
- **Open redirect** — redirect akses file
- **Try-umount** — umount path secara otomatis

---

## Fitur

| Fitur | Kconfig | Deskripsi |
|-------|---------|-----------|
| SUS_PATH | `CONFIG_KSU_SUSFS_SUS_PATH` | Hidden path dari lookup/filldir |
| SUS_MOUNT | `CONFIG_KSU_SUSFS_SUS_MOUNT` | Hidden mount dari /proc/mounts |
| SUS_KSTAT | `CONFIG_KSU_SUSFS_SUS_KSTAT` | Spoof file stat |
| SUS_MAP | `CONFIG_KSU_SUSFS_SUS_MAP` | Hidden memory mapping (v2.2.0) |
| SPOOF_UNAME | `CONFIG_KSU_SUSFS_SPOOF_UNAME` | Spoof uname syscall |
| SPOOF_CMDLINE | `CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG` | Spoof /proc/cmdline |
| OPEN_REDIRECT | `CONFIG_KSU_SUSFS_OPEN_REDIRECT` | Redirect file open |
| HIDE_SYMBOLS | `CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS` | Hidden ksu/susfs symbol |
| TRY_UMOUNT | `CONFIG_KSU_SUSFS_TRY_UMOUNT` | Umount path otomatis |
| SUS_OVERLAYFS | `CONFIG_KSU_SUSFS_SUS_OVERLAYFS` | Spoof kstat overlay |
| SUS_SU | `CONFIG_KSU_SUSFS_SUS_SU` | Non-kprobe root shell |
| AVC_SPOOF | (built-in via #ifdef) | Spoof SELinux audit log |
| ENABLE_LOG | `CONFIG_KSU_SUSFS_ENABLE_LOG` | Logging kernel susfs |
| AUTO_ADD_BIND | `CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT` | Auto-hide bind mount |
| AUTO_ADD_KSU | `CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT` | Auto-hide KSU mount |

---

## Struktur Proyek

```
backport-susf4ksu-legacy/
├── kernel/                          # Kernel patch
│   ├── 50_add_susfs_in_kernel-4.19.patch   # Main SUSFS patch (15+ file)
│   ├── fs/susfs.c                   # Implementasi SUSFS module (1118 baris)
│   ├── include/linux/
│   │   ├── susfs.h                  # Header utama SUSFS
│   │   └── susfs_def.h              # Flag definitions
│   └── KernelSU/
│       └── 10_enable_susfs_for_ksu.patch   # Patch KernelSU-Next + Kconfig
├── patches/
│   ├── 004-sus_map-proc-maps.patch  # SUS_MAP: hidden /proc/pid/maps
│   └── 005-avc-log-spoofing.patch   # AVC: spoof selinux audit log
├── fixup/
│   ├── fix_susfs_sched.py           # MTK KABI compat
│   ├── fix_susfs_namespace.py       # Mount hiding hooks
│   ├── fix_supercall_susfs.py       # Type conflicts
│   ├── fix_susfs_selinux.py         # Function placement
│   └── gen_extra_hunks.py           # [gitignored] Generate v2.2.0 hunks
├── pollux/
│   ├── apply.sh                     # Auto-apply script (idempotent)
│   ├── verify.sh                    # Verification script
│   ├── fix_mtk_includes.py          # Clang compat MTK headers
│   └── patch_vermagic.py            # Vermagic bypass (Xiaomi modules)
├── userspace/
│   ├── arm64/susfs                  # Pre-built binary
│   └── src/
│       ├── Android.mk               # NDK build file
│       ├── Application.mk           # APP_ABI = arm64-v8a
│       └── main.c                   # ksu_susfs CLI source (878 baris)
├── upstream-419/                    # [gitignored] Reference clone 4.19
├── upstream-latest/                 # [gitignored] Reference clone 5.x/6.x
├── legacy-target/                   # [gitignored] Target kernel clone
├── AGENTS.md                        # Instruksi untuk AI agent
├── README.md                        # Dokumentasi ini
└── .gitignore
```

---

## Cara Penggunaan

### Prasyarat

- Kernel source **4.19** dengan KernelSU-Next sudah terintegrasi
- `patch`, `python3`, `findutils`, `sed` tersedia
- (Opsional) `wiggle` untuk fallback patch conflict

### Auto (via apply.sh)

```
bash pollux/apply.sh /path/to/kernel/source
```

Script ini **idempotent** — jika `fs/susfs.c` sudah ada, patch akan di-skip.

Urutan yang dilakukan:

1. Apply main SUSFS patch (`--fuzz=5`)
2. Fallback ke `wiggle` jika ada rejected hunks
3. Apply `patches/*.patch` (v2.2.0 features)
4. Jalankan 5 fixup scripts
5. Fix `susfs_def.h` → `susfs.h` di KernelSU source
6. (tidak otomatis) Vermagic bypass — jalankan manual jika perlu

### Manual

Lihat [AGENTS.md](./AGENTS.md) untuk langkah manual lengkap dengan perintah exact.

### Verifikasi

```
bash pollux/verify.sh /path/to/kernel/source
```

Memeriksa:
- `fs/susfs.c` exists
- `include/linux/susfs.h` exists
- No stale `susfs_def.h` includes di KernelSU source
- No `.rej` files (patch failure)
- Defconfig SUSFS options
- `userspace/arm64/susfs` binary exists

---

## Integrasi KernelSU

Patch `kernel/KernelSU/10_enable_susfs_for_ksu.patch` harus di-apply ke **`drivers/kernelsu/`**, bukan root kernel source. Patch ini:

- Menambahkan Kconfig menu "KernelSU - SUSFS" di `kernel/Kconfig`
- Backport `path_umount`, `get_cred_rcu`, `can_umount` untuk kernel 4.19
- Menambahkan hooks di `core_hook.c`, `selinux.c`, `ksu.c`, dll.
- Memperbaiki nama fungsi bentrok dengan KSU_NAMESPACE (prefix `ksu_`)

---

## Build Susfs CLI

```
cd userspace/src && ndk-build
```

Output: `ksu_susfs` binary untuk `arm64-v8a`.  
Pre-built binary sudah tersedia di `userspace/arm64/susfs`.

CLI commands yang didukung:
- `add_sus_path`, `add_sus_path_loop`
- `add_sus_mount`, `hide_sus_mnts_for_non_su_procs`
- `add_sus_kstat`, `update_sus_kstat`, `add_sus_kstat_statically`
- `add_try_umount`, `run_try_umount`
- `set_uname`, `set_cmdline_or_bootconfig`
- `add_open_redirect`
- `add_sus_map`
- `enable_avc_log_spoofing`
- `sus_su <mode>` — non-kprobe root shell
- `enable_log`, `show <version|enabled_features|variant>`

---

## Referensi Clone

| Direktori | Branch | Deskripsi |
|-----------|--------|-----------|
| `upstream-419/` | `kernel-4.19` | Upstream SUSFS untuk 4.19 |
| `upstream-latest/` | `main` | Upstream SUSFS untuk 5.x/6.x |
| `legacy-target/` | — | Target kernel spesifik device |

Direktori ini **gitignored** dan diisi saat `prepare_build.sh` dijalankan.

---

## Kredit

- [simonpunk](https://gitlab.com/simonpunk) — Pengembang asli SUSFS
- [KernelSU](https://kernelsu.org) — KernelSU project
- [Pollux Kernel](https://github.com/dereference) — Consumer kernel (Redmi 12)

---

<p align="center"><sub>SUSFS Backport — GPLv2</sub></p>
