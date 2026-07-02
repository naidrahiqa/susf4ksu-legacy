# Kernel Patcher (SUSFS patches/fixups) - SUSFS Backport

## Overview
Applies the SUSFS (SUS-FS) root-hiding patch suite to legacy 4.19 NON-GKI kernels. Universal — not device-specific. Follows strict patch order: Main → KSU → Additional → Fixups. Uses `wiggle` fallback if `--fuzz=5` fails. Validates via `core-scripts/apply.sh` and vendor-specific patches (Xiaomi, MediaTek).

## Core Responsibilities
- Apply universal kernel patches from `kernel/patches/4.19/` in numeric order (50_add_susfs, 10_enable_susfs_for_ksu, 004_*, 005_*)
- Apply vendor-specific patches from `vendor/xiaomi/patches/`, `vendor/mediatek/patches/`
- Run fixup scripts: `fixup/selinux_fixup.sh`, `fixup/mtk_fixup.sh`, `fixup/kconfig_fixup.sh`
- Use `wiggle` when `patch --fuzz=5` fails on context mismatch
- Check for `.rej` files after EVERY patch step; halt if any found
- Run `core-scripts/apply.sh` end-to-end dry-run before real apply

## When This Skill Activates
| Trigger | Event | Condition |
|---|---|---|
| Push | `refs/heads/main` | Changes to `kernel/patches/`, `core-scripts/`, `fixup/` |
| PR | `opened` | Paths match `vendor/*/patches/**` or `fixup/*.sh` |
| Manual | `workflow_dispatch` | `backport_check: universal|vendor|fixup|all` |

## Tech Stack
- **Patch tools**: `patch`, `wiggle`, `diffstat`, `colordiff`
- **Sources**: `kernel/patches/4.19/*.patch`, `vendor/*/patches/*.patch`
- **Fixups**: `fixup/selinux_fixup.sh`, `fixup/mtk_fixup.sh`, `fixup/kconfig_fixup.sh`
- **Core**: `core-scripts/apply.sh` (5-phase pipeline)
- **Target**: 4.19.325 NON-GKI; MT6768; SUSFS v2.2.0+

## Automated Checks
```yaml
checks:
  - id: "PSF-001"
    name: "Universal Patch Dry-Run"
    command: |
      FAIL=0; for f in kernel/patches/4.19/*.patch; do
        patch --dry-run -p1 < "$f" >/dev/null 2>&1 || FAIL=$((FAIL+1))
      done; [ "$FAIL" -eq 0 ] && echo "UNIVERSAL_OK"
    severity: "critical"
  - id: "PSF-002"
    name: "Vendor Patch Dry-Run"
    command: |
      FAIL=0; for f in vendor/*/patches/*.patch; do
        patch --dry-run -p1 < "$f" >/dev/null 2>&1 || FAIL=$((FAIL+1))
      done; [ "$FAIL" -eq 0 ] && echo "VENDOR_OK"
    severity: "critical"
  - id: "PSF-003"
    name: "Fixup Script Syntax"
    command: |
      FAIL=0; for s in fixup/*.sh; do
        bash -n "$s" 2>/dev/null || { echo "SYNTAX_ERR: $s"; FAIL=$((FAIL+1)); }
      done; [ "$FAIL" -eq 0 ] && echo "FIXUP_SCRIPTS_OK"
    severity: "high"
  - id: "PSF-004"
    name: "Post-Patch .rej Detection"
    command: |
      REJ=$(find . -name "*.rej" 2>/dev/null | wc -l)
      [ "$REJ" -eq 0 ] && echo "NO_REJ_FILES" || echo "REJ_FOUND: $REJ"
    severity: "critical"
```

## Input/Output Schema
```json
{
  "inputs": [
    {"name": "backport_check", "type": "string", "enum": ["universal", "vendor", "fixup", "all"]},
    {"name": "use_wiggle", "type": "boolean", "default": false},
    {"name": "vendor_filter", "type": "string", "default": "xiaomi,mediatek"}
  ],
  "outputs": {
    "universal_patches": "integer",
    "vendor_patches": "integer",
    "patches_applied": "integer",
    "patches_failed": "integer",
    "rej_files": ["string"],
    "fixup_scripts_executed": "integer"
  }
}
```

## Error Recovery
- **Patch fails with fuzz error**: Retry with `wiggle` fallback: `wiggle --replace <file> <patch>`
- **.rej file created**: Inspect `*.rej` for context; manually apply hunk; re-run `core-scripts/apply.sh` from failed step
- **Vendor patch not applicable**: Check vendor filter; verify kernel source matches expected version
- **SELinux fixup script fails**: Check `security/selinux/hooks.c` for existence; verify `susfs_*` hook function signatures
