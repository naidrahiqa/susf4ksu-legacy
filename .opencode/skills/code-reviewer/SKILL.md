# Code Reviewer - SUSFS Backport

## Overview
Reviews all code in the SUSFS backport repository: kernel patches, vendor-specific patches, Shell fixup scripts, and the `core-scripts/apply.sh` pipeline. Enforces patch ordering conventions (numeric prefix), correct fixup semantics, and no-regression against 4.19 baseline.

## Core Responsibilities
- Review patch files: verify numeric ordering prefix (`0001-`, `0002-`), `Signed-off-by`, `From`, `Date`
- Review Shell scripts: `core-scripts/apply.sh`, `fixup/*.sh` for POSIX compliance and error handling
- Ensure patch order is strictly enforced: Main → KSU → Additional → Fixups
- Verify vendor patches are tagged with platform identifier (xiaomi, mediatek)
- Check SUSFS integration doesn't break SELinux enforcement
- Enforce no binary blobs in patches without corresponding source

## When This Skill Activates
| Trigger | Event | Condition |
|---|---|---|
| PR | `opened` or `synchronize` | Any path change |
| Manual | `workflow_dispatch` | `review_scope: patches|scripts|fixups|all` |

## Tech Stack
- **Review targets**: `kernel/patches/4.19/*.patch`, `vendor/*/patches/*.patch`, `fixup/*.sh`, `core-scripts/*.sh`
- **Tools**: `shellcheck`, `diffstat`, `checkpatch.pl`, `colordiff`
- **Standards**: Linux kernel patch format; POSIX shell; numeric patch ordering
- **Key constraints**: Patch order is critical; wiggle fallback allowed; `.rej` files are blocking

## Automated Checks
```yaml
checks:
  - id: "CRS-001"
    name: "Patch Ordering Convention"
    command: |
      ISSUES=0
      for d in kernel/patches/4.19 vendor/xiaomi/patches vendor/mediatek/patches; do
        [ -d "$d" ] || continue
        for f in "$d"/*.patch; do
          [ -f "$f" ] || continue
          echo "$(basename $f)" | grep -qP '^\d+' || ISSUES=$((ISSUES+1))
        done
      done; [ "$ISSUES" -eq 0 ] && echo "PATCH_ORDERING_OK"
    severity: "critical"
  - id: "CRS-002"
    name: "Patch Header Validation"
    command: |
      ISSUES=0; for f in $(find kernel/patches vendor -name "*.patch"); do
        grep -q "^Signed-off-by:" "$f" || ISSUES=$((ISSUES+1))
      done; [ "$ISSUES" -eq 0 ] && echo "ALL_PATCHES_SIGNED"
    severity: "high"
  - id: "CRS-003"
    name: "Shell Script Lint"
    command: |
      shellcheck core-scripts/apply.sh fixup/*.sh 2>&1 | grep -c "error" | xargs
      [ "$(shellcheck core-scripts/apply.sh fixup/*.sh 2>&1 | grep -c error)" -eq 0 ] && echo "SHELLCHECK_CLEAN"
    severity: "high"
  - id: "CRS-004"
    name: "No Binary Blobs"
    command: |
      for f in $(find kernel/patches vendor -name "*.patch"); do
        grep "^Binary files" "$f" && { echo "BINARY_BLOB: $f"; exit 1; }
      done; echo "NO_BINARY_BLOBS"
    severity: "medium"
```

## Input/Output Schema
```json
{
  "inputs": [
    {"name": "review_scope", "type": "string", "enum": ["patches", "scripts", "fixups", "all"]},
    {"name": "diff_ref", "type": "string", "default": "origin/main"}
  ],
  "outputs": {
    "shell_errors": "integer",
    "patches_without_order": "integer",
    "patches_without_signoff": "integer",
    "binary_blobs": "integer",
    "review_status": "pass|fail"
  }
}
```

## Error Recovery
- **Patch missing numeric prefix**: Rename file to `NNNN-{descriptive-name}.patch` where NNNN = application order
- **Fixup script ShellCheck error**: Fix common issues (unquoted variables, missing `set -e`, unused vars)
- **Patch Signed-off-by missing**: Author must add `Signed-off-by: Name <email>` to all patches
- **Binary blob detected**: Remove binary data from patch; provide source file or reference to original
