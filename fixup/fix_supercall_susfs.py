#!/usr/bin/env python3
"""
Fix type conflicts in supercall.c when SUSFS is enabled.
"""
import os
import sys
import re

def fix_supercall(supercall_path):
    """Patch supercall.c for SUSFS type compatibility."""
    if not os.path.exists(supercall_path):
        print(f"::error::supercall.c not found at {supercall_path}")
        return False
    
    with open(supercall_path, 'r') as f:
        content = f.read()
    
    # Check if already patched
    if "susfs_type_compat" in content or "SUSFS_COMPAT" in content:
        print("supercall.c already patched for SUSFS")
        return True
    
    # Add type compatibility
    type_compat = """
/* Pollux Kernel: SUSFS type compatibility */
#ifndef SUSFS_TYPE_COMPAT
#define SUSFS_TYPE_COMPAT
typedef int (*susfs_call_t)(void __user *arg);
#endif
"""
    
    # Insert after includes
    include_end = content.find("#include")
    if include_end > 0:
        pos = include_end
        while pos < len(content) and content[pos] != '\n':
            pos += 1
        content = content[:pos+1] + type_compat + content[pos+1:]
    
    with open(supercall_path, 'w') as f:
        f.write(content)
    
    print("Patched supercall.c for SUSFS type compatibility")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: fix_supercall_susfs.py <supercall_path>")
        sys.exit(1)
    
    supercall_path = sys.argv[1]
    success = fix_supercall(supercall_path)
    sys.exit(0 if success else 1)
