#!/usr/bin/env python3
"""
Fix MediaTek include compatibility for Clang builds.
Patches MTK headers to work with Clang 16.0.6+.
"""
import os
import sys
import re

def fix_mtk_includes(kernel_path):
    """Fix MediaTek include files for Clang compatibility."""
    fixed = 0
    
    # Fix 1: mach/mt6768/mtk_platform.h — missing types
    mtk_platform = os.path.join(kernel_path, "arch", "arm64", "mach", "mt6768", "mtk_platform.h")
    if os.path.exists(mtk_platform):
        with open(mtk_platform, 'r') as f:
            content = f.read()
        if "pollux_compat" not in content:
            compat = """
/* Pollux Kernel: Clang compatibility fixes */
#ifndef POLLUX_COMPAT_TYPES
#define POLLUX_COMPAT_TYPES
typedef unsigned long long u64_compat;
#endif
"""
            content = compat + content
            with open(mtk_platform, 'w') as f:
                f.write(content)
            fixed += 1
            print(f"Fixed: {mtk_platform}")
    
    # Fix 2: drivers/misc/mediatek/video/mt6768/ — missing includes
    video_dir = os.path.join(kernel_path, "drivers", "misc", "mediatek", "video", "mt6768")
    if os.path.isdir(video_dir):
        for root, dirs, files in os.walk(video_dir):
            for fname in files:
                if fname.endswith('.c') or fname.endswith('.h'):
                    fpath = os.path.join(root, fname)
                    with open(fpath, 'r') as f:
                        content = f.read()
                    if "linux/compiler.h" not in content and "#include" in content:
                        # Add missing compiler.h include
                        first_include = content.find("#include")
                        if first_include > 0:
                            content = content[:first_include] + '#include <linux/compiler.h>\n' + content[first_include:]
                            with open(fpath, 'w') as f:
                                f.write(content)
                            fixed += 1
    
    print(f"Fixed {fixed} MediaTek include files")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: fix_mtk_includes.py <kernel_path>")
        sys.exit(1)
    
    kernel_path = sys.argv[1]
    success = fix_mtk_includes(kernel_path)
    sys.exit(0 if success else 1)
