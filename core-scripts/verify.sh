#!/bin/bash
# SUSFS Universal Backport: Verification script
# Checks if SUSFS patches are properly applied

set -euo pipefail

KERNEL_DIR="${1:-.}"
DEFCONFIG_ARG="${2:-}"

echo "=== SUSFS Universal Verification ==="
echo "Kernel: $KERNEL_DIR"
echo ""

ERRORS=0
WARNINGS=0

# 1. Check kernel source exists
if [ ! -f "$KERNEL_DIR/Makefile" ]; then
    echo "✗ ERROR: Not a kernel source directory"
    exit 1
fi

# 2. Check SUSFS kernel patch applied
if [ -f "$KERNEL_DIR/fs/susfs.c" ]; then
    echo "✓ fs/susfs.c exists (SUSFS patch applied)"
else
    echo "✗ ERROR: fs/susfs.c not found"
    ERRORS=$((ERRORS + 1))
fi

# 3. Check susfs.h exists
if [ -f "$KERNEL_DIR/include/linux/susfs.h" ]; then
    echo "✓ include/linux/susfs.h exists"
else
    echo "✗ ERROR: include/linux/susfs.h not found"
    ERRORS=$((ERRORS + 1))
fi

# 4. Check susfs_def.h is gone (should be patched to susfs.h in KernelSU source, but kept in kernel include)
if [ -f "$KERNEL_DIR/include/linux/susfs_def.h" ]; then
    echo "✓ susfs_def.h exists in kernel include (kept for flag definitions)"
else
    echo "⚠ WARNING: susfs_def.h not found (might cause build issues if flags are missing)"
    WARNINGS=$((WARNINGS + 1))
fi

# 5. Check KernelSU source includes susfs.h instead of susfs_def.h
KSU_DIR="$KERNEL_DIR/drivers/kernelsu"
if [ -d "$KSU_DIR" ]; then
    BAD_INCLUDES=$(grep -r "susfs_def\.h" "$KSU_DIR" 2>/dev/null | wc -l)
    if [ "$BAD_INCLUDES" -gt 0 ]; then
        echo "✗ ERROR: $KSU_DIR still includes susfs_def.h ($BAD_INCLUDES occurrences)"
        ERRORS=$((ERRORS + 1))
    else
        echo "✓ KernelSU source uses susfs.h"
    fi
else
    echo "⚠ WARNING: drivers/kernelsu not found"
    WARNINGS=$((WARNINGS + 1))
fi

# 6. Check defconfig dynamically
DEFCONFIG=""
if [ -n "$DEFCONFIG_ARG" ]; then
    if [ -f "$KERNEL_DIR/arch/arm64/configs/$DEFCONFIG_ARG" ]; then
        DEFCONFIG="$KERNEL_DIR/arch/arm64/configs/$DEFCONFIG_ARG"
    elif [ -f "$DEFCONFIG_ARG" ]; then
        DEFCONFIG="$DEFCONFIG_ARG"
    else
        echo "✗ ERROR: Specified defconfig '$DEFCONFIG_ARG' not found"
        ERRORS=$((ERRORS + 1))
    fi
else
    # Auto-detect defconfig containing CONFIG_KSU or CONFIG_KSU_SUSFS
    echo "Auto-detecting defconfig with KSU/SUSFS..."
    while IFS= read -r -d '' config_file; do
        if grep -q "CONFIG_KSU" "$config_file" 2>/dev/null; then
            DEFCONFIG="$config_file"
            break
        fi
    done < <(find "$KERNEL_DIR/arch/arm64/configs" -name "*_defconfig" -print0 2>/dev/null)
    
    if [ -n "$DEFCONFIG" ]; then
        echo "Auto-detected defconfig: $(basename "$DEFCONFIG")"
    else
        # Fallback to any defconfig
        DEFCONFIG=$(find "$KERNEL_DIR/arch/arm64/configs" -name "*_defconfig" 2>/dev/null | head -n 1 || true)
        if [ -n "$DEFCONFIG" ]; then
            echo "⚠ WARNING: No defconfig with CONFIG_KSU found, checking fallback: $(basename "$DEFCONFIG")"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
fi

if [ -n "$DEFCONFIG" ] && [ -f "$DEFCONFIG" ]; then
    echo "✓ defconfig found: $(basename "$DEFCONFIG")"
    # SUSFS options
    for opt in KSU_SUSFS SUSFS_SUS_PATH SUSFS_SUS_MOUNT SUSFS_SUS_KSTAT SUSFS_SPOOF_UNAME; do
        if grep -q "CONFIG_KSU_${opt#KSU_}=y" "$DEFCONFIG" 2>/dev/null || grep -q "CONFIG_${opt}=y" "$DEFCONFIG" 2>/dev/null; then
            echo "  ✓ CONFIG_$opt=y"
        else
            echo "  ⚠ CONFIG_$opt not set"
        fi
    done
else
    echo "⚠ WARNING: No defconfig file checked"
    WARNINGS=$((WARNINGS + 1))
fi

# 7. Check for .rej files (failed patches)
REJ_COUNT=$(find "$KERNEL_DIR" -name "*.rej" -maxdepth 3 2>/dev/null | wc -l)
if [ "$REJ_COUNT" -gt 0 ]; then
    echo "✗ ERROR: $REJ_COUNT .rej files found (failed patches)"
    find "$KERNEL_DIR" -name "*.rej" -maxdepth 3 2>/dev/null | head -5
    ERRORS=$((ERRORS + 1))
else
    echo "✓ No .rej files (all patches applied)"
fi

# 8. Check susfs CLI binary
CLI_BIN="$(dirname "$0")/../userspace/arm64/susfs"
if [ -f "$CLI_BIN" ]; then
    echo "✓ susfs CLI binary exists"
else
    echo "⚠ WARNING: susfs CLI binary not found"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "=== Summary ==="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [ "$ERRORS" -gt 0 ]; then
    echo "✗ VERIFICATION FAILED"
    exit 1
else
    echo "✓ VERIFICATION PASSED"
    exit 0
fi
