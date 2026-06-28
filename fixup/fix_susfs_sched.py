#!/usr/bin/env python3
"""
Fix SUSFS compatibility with MTK KABI fields in sched.h
for kernel 4.19.325 on MediaTek MT6768.
"""
import os
import sys
import re

def fix_sched_header(kernel_path):
    """Patch include/linux/susfs.h for MTK KABI compatibility."""
    susfs_header = os.path.join(kernel_path, "include", "linux", "susfs.h")
    
    if not os.path.exists(susfs_header):
        print(f"::error::susfs.h not found at {susfs_header}")
        return False
    
    with open(susfs_header, 'r') as f:
        content = f.read()
    
    # Check if already patched
    if "MTK_KABI" in content or "mtk_kabi" in content.lower():
        print("susfs.h already patched for MTK KABI")
        return True
    
    # Add MTK KABI compatibility
    kabi_compat = """
/* Pollux Kernel: MTK KABI compatibility for MT6768 */
#ifdef CONFIG_MTK_SCHED_EXTENSION
struct mtk_kabi_info {
    unsigned int reserved[16];
};
#endif
"""
    
    # Insert after includes
    include_end = content.find("#include")
    if include_end > 0:
        # Find the end of include block
        pos = include_end
        while pos < len(content) and content[pos] != '\n':
            pos += 1
        content = content[:pos+1] + kabi_compat + content[pos+1:]
    
    with open(susfs_header, 'w') as f:
        f.write(content)
    
    print("Patched susfs.h for MTK KABI compatibility")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: fix_susfs_sched.py <kernel_path>")
        sys.exit(1)
    
    kernel_path = sys.argv[1]
    success = fix_sched_header(kernel_path)
    sys.exit(0 if success else 1)
