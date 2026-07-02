# SUSFS Backport Validator Developer Skill

## Overview
Validates the SUSFS backport for legacy 4.19 kernels targeting Xiaomi Redmi 12 (fire, MT6768). Audits universal kernel patches, fixup scripts, vendor-specific patches (Xiaomi, MediaTek), and the core-scripts/apply.sh installation pipeline. Ensures SUSFS root-hiding functionality correctly integrates with the 4.19 security framework.

## Core Responsibilities
- Validate universal kernel patch sequence in kernel/patches/
- Verify vendor-specific patches (Xiaomi, MediaTek) apply correctly
- Audit fixup/ scripts for post-patch kernel source corrections
- Test core-scripts/apply.sh end-to-end dry-run
- Confirm SUSFS hooks integrate with 4.19 SELinux/security framework

## When This Skill Activates
| Trigger Type | Event | Condition |
|---|---|---|
| Push | refs/heads/main | Changes to kernel/patches/, core-scripts/, or fixup/ |
| PR | opened or synchronize | Paths match vendor/*/patches/** or fixup/*.sh |
| Manual | workflow_dispatch | backport_check: universal|vendor|fixup|all parameter |
| Release | published | Pre-release validation of complete backport suite |

## Tech Stack Required
```yaml
languages:
  - "C (45%)"
  - "Python (20%)"
  - "Shell (20%)"
  - "Patch files (15%)"
directories:
  core_scripts: "core-scripts/"
  kernel_patches: "kernel/patches/"
  fixup_scripts: "fixup/"
  vendor_patches: "vendor/"
patch_sources:
  - "kernel/patches/4.19/"
  - "vendor/xiaomi/patches/"
  - "vendor/mediatek/patches/"
key_scripts:
  - "core-scripts/apply.sh"
  - "fixup/selinux_fixup.sh"
  - "fixup/mtk_fixup.sh"
kernel_target: "4.19.325"
platform: "MT6768 (Helio G88)"
dependencies:
  - "patch"
  - "diffstat"
  - "python3"
  - "colordiff"
```

## Workflow & Process Pipeline

### Phase 1: DETECTION & ANALYSIS
```bash
echo "[*] SUSFS backport audit"
UNIVERSAL_COUNT=$(ls kernel/patches/4.19/*.patch 2>/dev/null | wc -l)
echo "  Universal patches: $UNIVERSAL_COUNT"
VENDOR_COUNT=$(find vendor -name "*.patch" 2>/dev/null | wc -l)
echo "  Vendor patches: $VENDOR_COUNT"
FIXUP_COUNT=$(ls fixup/*.sh 2>/dev/null | wc -l)
echo "  Fixup scripts: $FIXUP_COUNT"
```

### Phase 2: DEEP DIVE INVESTIGATION
```bash
echo "[*] Analyzing patch ordering and fixup dependencies"
for f in $(ls kernel/patches/4.19/*.patch | sort); do
  PSTATS=$(grep -c '^diff --git' "$f")
  echo "  $(basename $f): $PSTATS files modified"
done
echo "[*] Checking fixup scripts for selinux hooks"
grep -l "selinux\|security\|susfs" fixup/*.sh 2>/dev/null
```

### Phase 3: VALIDATION & VERIFICATION
```bash
echo "[*] Dry-run core-scripts/apply.sh"
bash core-scripts/apply.sh --dry-run 2>&1 | head -30
echo "[*] Checking vendor patches for MT6768 compatibility"
for pf in $(find vendor/mediatek -name "*.patch" 2>/dev/null); do
  grep -q "mt6768\|MT6768\|fire" "$pf" && echo "  MTK: $(basename $pf)" || \
    echo "  MTK: $(basename $pf) (no platform match)"
done
```

### Phase 4: REPORT GENERATION
```bash
{
  echo "--- SUSFS Backport Validation Report ---"
  echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Universal patches: $UNIVERSAL_COUNT"
  echo "Vendor patches: $VENDOR_COUNT"
  echo "Fixup scripts: $FIXUP_COUNT"
  echo "Apply dry-run: $DRY_RUN_STATUS"
  echo "SELinux hooks patched: $SELINUX_HOOKS"
} | tee susfs-backport-report.txt
```

## AUTOMATED CHECKS (EXECUTABLE COMMANDS)
```yaml
quality_checks:
  - check_id: "CHK-001"
    name: "Universal Kernel Patch Directory"
    command: |
      PATCH_DIR="kernel/patches/4.19"
      if [ ! -d "$PATCH_DIR" ]; then
        echo "PATCH_DIR_MISSING"; exit 1
      fi
      PATCH_COUNT=$(ls "$PATCH_DIR"/*.patch 2>/dev/null | wc -l)
      if [ "$PATCH_COUNT" -lt 3 ]; then
        echo "INSUFFICIENT_PATCHES ($PATCH_COUNT)"; exit 1
      fi
      for pf in "$PATCH_DIR"/*.patch; do
        head -1 "$pf" | grep -q "^From:\|^Subject:\|^diff --git" || \
          echo "  BAD_HEADER: $(basename $pf)"
      done
      echo "UNIVERSAL_PATCHES_OK ($PATCH_COUNT patches)"
    expected_output: "UNIVERSAL_PATCHES_OK"
    failure_indicator: "Universal patch directory missing or malformed"
    severity: "critical"

  - check_id: "CHK-002"
    name: "Vendor Patch Validation"
    command: |
      ISSUES=0
      VENDOR_DIRS="vendor/xiaomi vendor/mediatek"
      for vdir in $VENDOR_DIRS; do
        PATCH_DIR="$vdir/patches"
        if [ ! -d "$PATCH_DIR" ]; then
          echo "NO_VENDOR_PATCHES: $vdir"
          continue
        fi
        PCOUNT=$(ls "$PATCH_DIR"/*.patch 2>/dev/null | wc -l)
        echo "  $vdir: $PCOUNT patches"
        if [ "$PCOUNT" -eq 0 ]; then
          echo "  EMPTY: $PATCH_DIR"
        fi
        for pf in "$PATCH_DIR"/*.patch; do
          [ -f "$pf" ] || continue
          patch --dry-run -p1 -d . < "$pf" >/dev/null 2>&1 || \
            { echo "  DRY_RUN_FAIL: $(basename $pf)"; ISSUES=$((ISSUES + 1)); }
        done
      done
      if [ "$ISSUES" -gt 0 ]; then exit 1; fi
      echo "VENDOR_PATCHES_OK"
    expected_output: "VENDOR_PATCHES_OK"
    failure_indicator: "Vendor patches fail dry-run application"
    severity: "critical"

  - check_id: "CHK-003"
    name: "Fixup Script Correctness"
    command: |
      FIXUP_DIR="fixup"
      if [ ! -d "$FIXUP_DIR" ]; then
        echo "FIXUP_DIR_MISSING"; exit 1
      fi
      ISSUES=0
      for s in "$FIXUP_DIR"/*.sh; do
        [ -f "$s" ] || continue
        bash -n "$s" 2>/dev/null || \
          { echo "SYNTAX_ERR: $(basename $s)"; ISSUES=$((ISSUES + 1)); }
        # Check for expected operations
        grep -q "sed\|patch\|cp\|mv" "$s" || \
          echo "  WARNING: $(basename $s) has no file modification commands"
      done
      if [ "$ISSUES" -gt 0 ]; then exit 1; fi
      echo "FIXUP_SCRIPTS_OK"
    expected_output: "FIXUP_SCRIPTS_OK"
    failure_indicator: "Fixup scripts have syntax errors or are missing"
    severity: "high"

  - check_id: "CHK-004"
    name: "Core Apply Script End-to-End"
    command: |
      if [ ! -f "core-scripts/apply.sh" ]; then
        echo "APPLY_SCRIPT_MISSING"; exit 1
      fi
      bash -n core-scripts/apply.sh || { echo "SYNTAX_ERR"; exit 1; }
      # Check for required phases
      for phase in "patch_prep" "apply_universal" "apply_vendor" "run_fixup" "verify"; do
        grep -q "$phase" core-scripts/apply.sh || \
          echo "  WARNING: Phase $phase not found"
      done
      # Check error handling
      grep -q "set -e\|set -o\|trap\|exit" core-scripts/apply.sh || \
        echo "  WARNING: No error handling found"
      echo "APPLY_SCRIPT_OK"
    expected_output: "APPLY_SCRIPT_OK"
    failure_indicator: "Core apply script missing phases or error handling"
    severity: "high"

  - check_id: "CHK-005"
    name: "SELinux Security Hook Audit"
    command: |
      if [ -d "kernel/patches/4.19" ]; then
        SELINUX_PATCHES=$(grep -l "selinux\|security/selinux" \
          kernel/patches/4.19/*.patch 2>/dev/null | wc -l)
        echo "  SELinux-related patches: $SELINUX_PATCHES"
      fi
      FIXUP_SELINUX=$(grep -l "selinux\|security" fixup/*.sh 2>/dev/null | wc -l)
      echo "  SELinux fixup scripts: $FIXUP_SELINUX"
      TOTAL=$((SELINUX_PATCHES + FIXUP_SELINUX))
      if [ "$TOTAL" -eq 0 ]; then
        echo "WARNING: No SELinux hooks found in patches or fixups"
      fi
      echo "SELINUX_HOOKS_DONE"
    expected_output: "SELINUX_HOOKS_DONE"
    failure_indicator: "No SELinux integration patches found for SUSFS"
    severity: "high"

  - check_id: "CHK-006"
    name: "Patch Application Ordering"
    command: |
      ISSUES=0
      # Check naming convention provides implicit ordering
      for d in kernel/patches/4.19 vendor/xiaomi/patches vendor/mediatek/patches; do
        [ -d "$d" ] || continue
        for pf in "$d"/*.patch; do
          [ -f "$pf" ] || continue
          BASENAME=$(basename "$pf")
          ORDER_NUM=$(echo "$BASENAME" | grep -oP '^\d+' || echo "NO_ORDER")
          if [ "$ORDER_NUM" = "NO_ORDER" ]; then
            echo "  NO_ORDER_PREFIX: $BASENAME"
            ISSUES=$((ISSUES + 1))
          fi
        done
      done
      if [ "$ISSUES" -gt 0 ]; then exit 1; fi
      echo "PATCH_ORDERING_OK"
    expected_output: "PATCH_ORDERING_OK"
    failure_indicator: "Patches missing numeric ordering prefix"
    severity: "medium"

  - check_id: "CHK-007"
    name: "Backport Completeness Score"
    command: |
      TOTAL_EXPECTED=10
      UNIVERSAL=$(ls kernel/patches/4.19/*.patch 2>/dev/null | wc -l)
      VENDOR=$(find vendor -name "*.patch" 2>/dev/null | wc -l)
      FIXUP=$(ls fixup/*.sh 2>/dev/null | wc -l)
      TOTAL=$((UNIVERSAL + VENDOR + FIXUP))
      SCORE=$((TOTAL * 10 / TOTAL_EXPECTED))
      [ "$SCORE" -gt 10 ] && SCORE=10
      echo "Universal: $UNIVERSAL, Vendor: $VENDOR, Fixup: $FIXUP"
      echo "Backport completeness score: $SCORE/10"
      if [ "$TOTAL" -lt 5 ]; then
        echo "INCOMPLETE_BACKPORT (total=$TOTAL)"; exit 1
      fi
      echo "BACKPORT_SCORE_OK"
    expected_output: "BACKPORT_SCORE_OK"
    failure_indicator: "Backport has insufficient patches or scripts"
    severity: "medium"
```

## INPUT SCHEMA
```json
{
  "schema_version": "1.0",
  "project": "backport-susf4ksu-legacy",
  "inputs": [
    {
      "name": "backport_repository",
      "type": "git_repository",
      "required": true,
      "source": "https://github.com/backport/susfs4ksu-legacy",
      "branch": "main",
      "description": "SUSFS backport for legacy 4.19 kernels"
    },
    {
      "name": "backport_check",
      "type": "string",
      "enum": ["universal", "vendor", "fixup", "all"],
      "required": false,
      "default": "all",
      "description": "Which patch category to validate"
    },
    {
      "name": "vendor_filter",
      "type": "string",
      "required": false,
      "default": "xiaomi,mediatek",
      "description": "Comma-separated vendor list for vendor patch validation"
    }
  ]
}
```

## OUTPUT SCHEMA
```json
{
  "schema_version": "1.0",
  "project": "backport-susf4ksu-legacy",
  "metadata": {
    "validation_id": "string (git SHA)",
    "backport_check": "all|universal|vendor|fixup",
    "timestamp": "string (ISO 8601)"
  },
  "findings": [
    {
      "check_id": "string (CHK-00X)",
      "status": "pass|fail|skip|warn",
      "category": "universal|vendor|fixup|core",
      "detail": "string",
      "affected_files": ["string"],
      "severity": "critical|high|medium|low"
    }
  ],
  "statistics": {
    "total_checks": "int",
    "passed": "int",
    "failed": "int",
    "skipped": "int",
    "universal_patches": "int",
    "vendor_patches": "int",
    "fixup_scripts": "int",
    "patch_dry_run_failures": "int",
    "selinux_patches": "int"
  },
  "quality_score": {
    "overall": "float (0.0 - 1.0)",
    "completeness_score": "int (0-10)"
  },
  "artifacts": {
    "validation_report": "string (path to report)",
    "dry_run_log": "string (path to log)"
  }
}
```

## INTEGRATION IMPLEMENTATIONS

### GitHub Actions
```yaml
name: SUSFS Backport Validation
on:
  push:
    branches: [main]
    paths:
      - 'kernel/patches/**'
      - 'core-scripts/**'
      - 'fixup/**'
      - 'vendor/**'
  pull_request:
    paths:
      - 'kernel/patches/**'
      - 'vendor/*/patches/**'
  workflow_dispatch:
    inputs:
      backport_check:
        description: 'Backport category to validate'
        required: true
        default: 'all'
        type: choice
        options: [universal, vendor, fixup, all]

jobs:
  validate-backport:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          submodules: recursive
      - name: Count Patches
        run: |
          echo "Universal: $(ls kernel/patches/4.19/*.patch 2>/dev/null | wc -l)"
          echo "Vendor: $(find vendor -name '*.patch' 2>/dev/null | wc -l)"
          echo "Fixup scripts: $(ls fixup/*.sh 2>/dev/null | wc -l)"
      - name: Vendor Patch Dry-Run
        run: |
          for pf in $(find vendor -name '*.patch' 2>/dev/null); do
            patch --dry-run -p1 < "$pf" && echo "OK: $(basename $pf)" || \
              echo "FAIL: $(basename $pf)"
          done
      - name: Fixup Script Syntax
        run: |
          for s in fixup/*.sh; do
            bash -n "$s" && echo "OK: $(basename $s)" || echo "FAIL: $(basename $s)"
          done
      - name: Core Apply Script Check
        run: |
          bash -n core-scripts/apply.sh && echo "Apply script: OK" || \
            echo "Apply script: FAIL"
      - name: Upload Validation Log
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: susfs-backport-log
          path: susfs-backport-report.txt

### CLI Interface
```bash
# Full backport validation
export KERNEL_DIR=$(pwd)
ls kernel/patches/4.19/*.patch | sort | xargs -I{} basename {}
bash core-scripts/apply.sh --dry-run 2>&1 | tee apply-dry-run.log
for s in fixup/*.sh; do bash -n "$s" && echo "OK: $s"; done
```

## ERROR HANDLING & RECOVERY
```yaml
recovery_strategies:
  - error: "Universal patch ordering conflict"
    recovery: |
      echo "Check patch numbering:"
      echo "ls -1 kernel/patches/4.19/*.patch | head -20"
      echo "Reorder patches by renaming numeric prefix:"
      echo "mv 0001-foo.patch 0002-foo.patch && mv 0003-bar.patch 0001-bar.patch"
      echo "Update series file if using quilt:"
      echo "cd kernel/patches/4.19 && quilt pop -a && quilt push -a"
    severity: "critical"

  - error: "Vendor patch fails dry-run against kernel source"
    recovery: |
      echo "Examine patch context:"
      echo "head -50 vendor/xiaomi/patches/failing.patch"
      echo "Recreate patch against current kernel:"
      echo "cd kernel-source && make relevant edits"
      echo "git diff > ../vendor/xiaomi/patches/0001-fixed.patch"
    severity: "critical"

  - error: "Fixup script fails with sed error"
    recovery: |
      echo "Debug line by line:"
      echo "bash -x fixup/selinux_fixup.sh 2>&1 | head -30"
      echo "Check if target files exist:"
      echo "grep 'sed\|patch' fixup/selinux_fixup.sh | head -10"
      echo "Verify file paths relative to kernel root:"
      echo "find . -name 'hooks.c' -path '*/selinux/*'"
    severity: "high"

  - error: "core-scripts/apply.sh missing phase"
    recovery: |
      echo "Required phases: patch_prep, apply_universal, apply_vendor, run_fixup, verify"
      echo "Add missing phase:"
      echo "echo '[PHASE: apply_vendor]'"
      echo "for pf in vendor/*/patches/*.patch; do patch -p1 < \$pf; done"
    severity: "high"

  - error: "SELinux hook patch not found for 4.19"
    recovery: |
      echo "Generate SUSFS SELinux hook patch:"
      echo "grep -rn 'selinux_' kernel/security/ --include='*.c' | head -10"
      echo "Check susfs4ksu upstream for 4.19 SELinux patches:"
      echo "curl -s https://raw.githubusercontent.com/susfs4ksu/ksu/main/kernel_patches/4.19/ | grep selinux"
    severity: "medium"
```

## CLI USAGE EXAMPLES
```bash
# Clone and validate SUSFS backport
git clone https://github.com/backport/susfs4ksu-legacy susfs-backport
cd susfs-backport
SKILL=../skills/backport-susf4ksu-legacy

# Run category-specific checks
bash $SKILL/checks/CHK-001_universal_patches.sh && \
bash $SKILL/checks/CHK-002_vendor_patches.sh && \
bash $SKILL/checks/CHK-003_fixup_scripts.sh

# Run core and security checks
bash $SKILL/checks/CHK-004_apply_script.sh && \
bash $SKILL/checks/CHK-005_selinux_hooks.sh && \
bash $SKILL/checks/CHK-006_patch_ordering.sh

# Generate report
python3 $SKILL/scripts/generate_backport_report.py \
  --patches-dir kernel/patches/4.19/ \
  --vendor-dir vendor/ \
  --fixup-dir fixup/ \
  --output backport-report.json
cat backport-report.json | jq .
```

## CONFIGURATION & SECURITY
```yaml
environment_variables:
  - name: "ARCH"
    value: "arm64"
    sensitive: false
  - name: "CROSS_COMPILE"
    value: "aarch64-linux-gnu-"
    sensitive: false
  - name: "KERNEL_DIR"
    value: "."
    sensitive: false
  - name: "BACKPORT_KERNEL"
    value: "4.19.325"
    sensitive: false

security_policies:
  - policy: "Vendor patches must not override universal patch security hooks"
  - policy: "Fixup scripts must not introduce insecure sysctl defaults"
  - policy: "All patches require Signed-off-by from the backport author"
  - policy: "SELinux policy updates must accompany SUSFS hook patches"
  - policy: "Vendor patches must be tagged with platform identifier (xiaomi, mediatek)"

backport_directories:
  universal:
    source: "kernel/patches/4.19/"
    ordering: "numeric prefix (0001-, 0002-, ...)"
    required_min: 3
  vendor:
    xiaomi:
      path: "vendor/xiaomi/patches/"
      required: true
    mediatek:
      path: "vendor/mediatek/patches/"
      required: true
  fixup:
    path: "fixup/"
    required_scripts:
      - "selinux_fixup.sh"
      - "mtk_fixup.sh"
      - "kconfig_fixup.sh"
