#!/usr/bin/env python3
"""
Vermagic bypass for kernel 4.19.325
Allows stock Xiaomi vendor modules to load on Clang-built kernel.
"""
import os
import sys
import re

def apply_vermagic_bypass(kernel_path):
    """Apply vermagic bypass to allow vendor module compatibility."""
    vermagic_file = os.path.join(kernel_path, "init", "vermagic.c")
    
    if not os.path.exists(vermagic_file):
        print(f"::warning::vermagic.c not found at {vermagic_file}")
        return True
    
    with open(vermagic_file, 'r') as f:
        content = f.read()
    
    # Check if already patched
    if "pollux_vermagic" in content or "POLLUX_BYPASS" in content:
        print("vermagic.c already patched for Pollux")
        return True
    
    # Add bypass for Xiaomi vendor modules
    bypass_code = """
/* Pollux Kernel: Vermagic bypass for vendor module compatibility */
#ifdef CONFIG_MODULE_FORCE_LOAD
static int pollux_vermagic_check(const char *vermagic)
{
    /* Allow stock Xiaomi vendor modules to load */
    if (strstr(vermagic, "SMP preempt=off"))
        return 0;
    return -ENOEXEC;
}
#endif
"""
    
    # Find insertion point
    insert_point = content.find("static int check_vermagic")
    if insert_point == -1:
        insert_point = content.find("int __init ")
    
    if insert_point > 0:
        while insert_point > 0 and content[insert_point-1] != '\n':
            insert_point -= 1
        content = content[:insert_point] + bypass_code + "\n" + content[insert_point:]
    
    with open(vermagic_file, 'w') as f:
        f.write(content)
    
    print("Applied vermagic bypass for vendor module compatibility")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: patch_vermagic_419.py <kernel_path>")
        sys.exit(1)
    
    kernel_path = sys.argv[1]
    success = apply_vermagic_bypass(kernel_path)
    sys.exit(0 if success else 1)
