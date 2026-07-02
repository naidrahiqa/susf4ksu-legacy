# Build Tester - SUSFS Backport

## Overview
Tests the SUSFS backport by running `core-scripts/apply.sh` and performing a kernel build validation. Verifies that SUSFS features (root hiding, SELinux hooking, module loading) work correctly on legacy 4.19 kernels. Generates build logs and validation reports.

## Core Responsibilities
- Execute `core-scripts/apply.sh --dry-run` for pre-application validation
- Run full kernel build with `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`
- Verify SUSFS config symbols: `CONFIG_SUSFS=y`, `CONFIG_SUSFS_HOOKS=y`
- Validate kernel boot via QEMU or fastboot test harness
- Confirm SELinux context hiding: `cat /proc/self/attr/current` should show `u:r:su:s0`
- Generate test report with patch application status and build results

## When This Skill Activates
| Trigger | Event | Condition |
|---|---|---|
| Push | `refs/heads/main` | After patches applied via `core-scripts/apply.sh` |
| Manual | `workflow_dispatch` | `test_scope: dry_run|build|boot|all` |

## Tech Stack
- **Build**: `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`, `fire_defconfig`
- **Emulation**: QEMU (aarch64), fastboot (physical device)
- **Config check**: `CONFIG_SUSFS`, `CONFIG_SECURITY_SELINUX`, `CONFIG_KSU` in `.config`
- **Key scripts**: `core-scripts/apply.sh`, `core-scripts/verify.sh`
- **Artifacts**: `build.log`, `.config`, `test-report.txt`

## Automated Checks
```yaml
checks:
  - id: "BTF-001"
    name: "Apply Script Dry-Run"
    command: |
      bash core-scripts/apply.sh --dry-run 2>&1 | head -20 && echo "DRY_RUN_DONE"
    severity: "critical"
  - id: "BTF-002"
    name: "Full Kernel Build"
    command: |
      make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- 2>&1 | tee build.log
      [ -f arch/arm64/boot/Image ] && echo "BUILD_OK"
    severity: "critical"
  - id: "BTF-003"
    name: "SUSFS Config Verification"
    command: |
      grep -q "CONFIG_SUSFS=y" .config && echo "SUSFS_ENABLED"
      grep -q "CONFIG_SUSFS_HOOKS=y" .config && echo "SUSFS_HOOKS_ENABLED"
    severity: "critical"
  - id: "BTF-004"
    name: "SELinux Context Validation"
    command: |
      [ -f .config ] && grep -q "CONFIG_SECURITY_SELINUX=y" .config && echo "SELINUX_ENABLED"
    severity: "high"
```

## Input/Output Schema
```json
{
  "inputs": [
    {"name": "test_scope", "type": "string", "enum": ["dry_run", "build", "boot", "all"]},
    {"name": "target_config", "type": "string", "default": "fire_defconfig"}
  ],
  "outputs": {
    "dry_run_passed": "boolean",
    "build_success": "boolean",
    "susfs_enabled": "boolean",
    "selinux_enabled": "boolean",
    "build_errors": "integer",
    "build_warnings": "integer",
    "kernel_image_size": "integer"
  }
}
```

## Error Recovery
- **Apply.sh dry-run fails**: Check `core-scripts/apply.sh` for missing phases; re-run with `bash -x core-scripts/apply.sh --dry-run`
- **Build fails after SUSFS apply**: Check `.rej` files; verify all patches applied; check `kernel/patches/4.19/` ordering
- **SUSFS not in .config**: Run `make menuconfig`; ensure `CONFIG_SUSFS=y` is selected; check Kconfig dependencies
- **QEMU boot fails**: Verify `-kernel arch/arm64/boot/Image` and `-initrd` paths; check serial console for panic
