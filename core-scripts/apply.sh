#!/bin/bash
# SUSFS Universal Backport: Auto-apply script
# Applies SUSFS patches and fixups to kernel source

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL_DIR=""
APPLY_MTK=false
APPLY_VERMAGIC=false
KSU_NEXT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mtk)
            APPLY_MTK=true
            shift
            ;;
        --xiaomi-vermagic)
            APPLY_VERMAGIC=true
            shift
            ;;
        --kernelsu-next)
            KSU_NEXT=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: $0 <kernel_dir> [--mtk] [--xiaomi-vermagic] [--kernelsu-next]"
            exit 1
            ;;
        *)
            if [ -z "$KERNEL_DIR" ]; then
                KERNEL_DIR="$1"
            else
                echo "Error: Multiple kernel directories specified"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$KERNEL_DIR" ]; then
    KERNEL_DIR="."
fi

echo "=== SUSFS Universal Auto-Apply ==="
echo "Kernel: $KERNEL_DIR"
echo ""

# Check kernel source
if [ ! -f "$KERNEL_DIR/Makefile" ]; then
    echo "Error: Not a kernel source directory"
    exit 1
fi

# Get kernel version
KERNEL_VERSION=$(grep -m1 "VERSION" "$KERNEL_DIR/Makefile" | cut -d' ' -f3)
KERNEL_PATCHLEVEL=$(grep -m1 "PATCHLEVEL" "$KERNEL_DIR/Makefile" | cut -d' ' -f3)
KERNEL_SUBLEVEL=$(grep -m1 "SUBLEVEL" "$KERNEL_DIR/Makefile" | cut -d' ' -f3)
echo "Kernel version: $KERNEL_VERSION.$KERNEL_PATCHLEVEL.$KERNEL_SUBLEVEL"

# Check if SUSFS already applied
if [ -f "$KERNEL_DIR/fs/susfs.c" ]; then
    echo "SUSFS already applied (fs/susfs.c exists)"
    echo "Skipping patch application"
else
    echo "Applying SUSFS kernel patch..."
    
    # Find the patch file
    PATCH_FILE="$SCRIPT_DIR/../kernel/50_add_susfs_in_kernel-4.19.patch"
    if [ ! -f "$PATCH_FILE" ]; then
        echo "Error: SUSFS patch not found at $PATCH_FILE"
        exit 1
    fi
    
    # Apply patch with fuzz
    cd "$KERNEL_DIR"
    if patch -p1 --fuzz=5 < "$PATCH_FILE"; then
        echo "SUSFS patch applied successfully"
    else
        echo "Warning: Patch failed with --fuzz=5"
        echo "Attempting wiggle fallback..."
        
        # Try wiggle if available
        if command -v wiggle &>/dev/null; then
            while IFS= read -r -d '' rej; do
                echo "Attempting wiggle merge: $rej"
                wiggle --replace "$rej" 2>/dev/null || true
                rm -f "$rej"
            done < <(find . -name "*.rej" -maxdepth 3 -print0 2>/dev/null)
            echo "Wiggle fallback completed"
        else
            echo "Warning: wiggle not available, check .rej files"
        fi
    fi
    cd "$SCRIPT_DIR"
fi

# Apply KernelSU integration patch
echo ""
if [ "$KSU_NEXT" = true ]; then
    echo "Applying KernelSU-Next SUSFS integration patch..."
    KSU_PATCH="$SCRIPT_DIR/../kernel/KernelSU-Next/007-susfs-for-kernelsu-next.patch"
    # Detect KernelSU-Next directory
    KSU_DIR=""
    for candidate in "$KERNEL_DIR/KernelSU" "$KERNEL_DIR/drivers/kernelsu" "$KERNEL_DIR/kernel/KernelSU"; do
        if [ -d "$candidate" ]; then
            KSU_DIR="$candidate"
            break
        fi
    done
    if [ -n "$KSU_DIR" ] && [ -f "$KSU_PATCH" ]; then
        cd "$KSU_DIR"
        if patch -p1 --fuzz=3 < "$KSU_PATCH"; then
            echo "  ✓ KernelSU-Next patch applied"
        else
            echo "  ⚠ KernelSU-Next patch had issues (check .rej files)"
        fi
        cd "$SCRIPT_DIR"
    else
        echo "  ⚠ KernelSU directory or patch not found, skipping"
        echo "    KSU_DIR=$KSU_DIR KSU_PATCH=$KSU_PATCH"
    fi
else
    echo "Applying official KernelSU SUSFS integration patch..."
    KSU_PATCH="$SCRIPT_DIR/../kernel/KernelSU/10_enable_susfs_for_ksu.patch"
    KSU_DIR=""
    for candidate in "$KERNEL_DIR/KernelSU" "$KERNEL_DIR/drivers/kernelsu" "$KERNEL_DIR/kernel/KernelSU"; do
        if [ -d "$candidate" ]; then
            KSU_DIR="$candidate"
            break
        fi
    done
    if [ -n "$KSU_DIR" ] && [ -f "$KSU_PATCH" ]; then
        cd "$KSU_DIR"
        if patch -p1 --fuzz=3 < "$KSU_PATCH"; then
            echo "  ✓ KernelSU patch applied"
        else
            echo "  ⚠ KernelSU patch had issues (check .rej files)"
        fi
        cd "$SCRIPT_DIR"
    else
        echo "  ⚠ KernelSU directory or patch not found, skipping"
    fi
fi

# Apply additional SUSFS patches (v2.2.0 features)
echo ""
echo "Applying additional SUSFS v2.2.0 patches..."

for patch in "$SCRIPT_DIR/../patches/"*.patch; do
    if [ -f "$patch" ]; then
        pname=$(basename "$patch")
        echo "  Applying $pname..."
        cd "$KERNEL_DIR"
        if patch -p1 --fuzz=3 < "$patch"; then
            echo "  ✓ $pname applied"
        else
            echo "  ⚠ $pname had issues (check .rej files)"
        fi
        cd "$SCRIPT_DIR"
    fi
done

# Apply fixup scripts
echo ""
echo "Applying SUSFS fixup scripts..."

# 1. Fix sched.h
echo "1. Fixing susfs.h for MTK KABI..."
python3 "$SCRIPT_DIR/../fixup/fix_susfs_sched.py" "$KERNEL_DIR" || true

# 2. Fix namespace.c
echo "2. Fixing namespace.c for mount hiding..."
python3 "$SCRIPT_DIR/../fixup/fix_susfs_namespace.py" "$KERNEL_DIR" || true

# 3. Fix supercall.c
echo "3. Fixing supercall.c type conflicts..."
SUPERCALL_FILE=""
if [ "$KSU_NEXT" = true ]; then
    # KernelSU-Next: try multiple possible locations
    for candidate in \
        "$KERNEL_DIR/drivers/kernelsu/supercall/supercall.c" \
        "$KERNEL_DIR/KernelSU/kernel/supercall/supercall.c" \
        "$KERNEL_DIR/kernel/KernelSU/supercall/supercall.c"; do
        if [ -f "$candidate" ]; then
            SUPERCALL_FILE="$candidate"
            break
        fi
    done
else
    SUPERCALL_FILE="$KERNEL_DIR/drivers/kernelsu/supercall/supercall.c"
fi
if [ -n "$SUPERCALL_FILE" ] && [ -f "$SUPERCALL_FILE" ]; then
    python3 "$SCRIPT_DIR/../fixup/fix_supercall_susfs.py" "$SUPERCALL_FILE" || true
else
    echo "Warning: supercall.c not found, skipping"
fi

# 4. Fix selinux.c
echo "4. Fixing selinux.c function placement..."
python3 "$SCRIPT_DIR/../fixup/fix_susfs_selinux.py" "$KERNEL_DIR" || true

# Fix susfs_def.h → susfs.h includes
echo "5. Fixing susfs_def.h to susfs.h includes..."
if [ "$KSU_NEXT" = true ]; then
    # KernelSU-Next: try multiple possible locations
    for ksu_dir in \
        "$KERNEL_DIR/drivers/kernelsu" \
        "$KERNEL_DIR/KernelSU/kernel" \
        "$KERNEL_DIR/kernel/KernelSU"; do
        if [ -d "$ksu_dir" ]; then
            find -L "$ksu_dir" -type f \( -name '*.c' -o -name '*.h' \) \
                -exec sed -i 's|susfs_def\.h|susfs.h|g' {} + 2>/dev/null || true
        fi
    done
else
    find -L "$KERNEL_DIR/drivers/kernelsu" -type f \( -name '*.c' -o -name '*.h' \) \
        -exec sed -i 's|susfs_def\.h|susfs.h|g' {} + 2>/dev/null || true
fi
echo "   (also fixing include guards in susfs_def.h if present)"

# Optional Vendor specific fixes
if [ "$APPLY_MTK" = true ]; then
    echo ""
    echo "Applying MediaTek specific fixes..."
    python3 "$SCRIPT_DIR/../vendor/mediatek/fix_mtk_includes.py" "$KERNEL_DIR" || true
fi

if [ "$APPLY_VERMAGIC" = true ]; then
    echo ""
    echo "Applying Xiaomi vermagic bypass..."
    python3 "$SCRIPT_DIR/../vendor/xiaomi/patch_vermagic.py" "$KERNEL_DIR" || true
fi

echo ""
echo "=== SUSFS Universal Apply Complete ==="
echo "Check for .rej files if any patches failed"
