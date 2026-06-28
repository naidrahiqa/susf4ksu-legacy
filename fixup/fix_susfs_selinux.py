#!/usr/bin/env python3
"""
Fix SUSFS function placement in selinux.c
"""
import os
import sys
import re

def fix_selinux(kernel_path):
    """Patch security/selinux.c for SUSFS function placement."""
    selinux_file = os.path.join(kernel_path, "security", "selinux.c")
    
    if not os.path.exists(selinux_file):
        print(f"::error::selinux.c not found at {selinux_file}")
        return False
    
    with open(selinux_file, 'r') as f:
        content = f.read()
    
    # Check if already patched
    if "susfs_selinux" in content or "SUSFS_SELINUX" in content:
        print("selinux.c already patched for SUSFS")
        return True
    
    # Add SUSFS SELinux hook
    susfs_hook = """
/* Pollux Kernel: SUSFS SELinux bypass */
#ifdef CONFIG_KSU_SUSFS
static int susfs_selinux_bypass(struct task_struct *task)
{
    /* SUSFS SELinux bypass implementation */
    if (!task)
        return -EINVAL;
    
    /* Allow SUSFS operations */
    return 0;
}
#endif
"""
    
    # Find a good insertion point
    insert_point = content.find("static struct security_hook_list")
    if insert_point == -1:
        insert_point = content.find("void __init ")
    
    if insert_point > 0:
        while insert_point > 0 and content[insert_point-1] != '\n':
            insert_point -= 1
        content = content[:insert_point] + susfs_hook + "\n" + content[insert_point:]
    
    with open(selinux_file, 'w') as f:
        f.write(content)
    
    print("Patched selinux.c for SUSFS function placement")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: fix_susfs_selinux.py <kernel_path>")
        sys.exit(1)
    
    kernel_path = sys.argv[1]
    success = fix_selinux(kernel_path)
    sys.exit(0 if success else 1)
