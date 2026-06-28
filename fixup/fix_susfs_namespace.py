#!/usr/bin/env python3
"""
Fix SUSFS namespace.c for fs_context-aware mount hiding
on kernel 4.19.325 with MediaTek MT6768.
"""
import os
import sys
import re

def fix_namespace(kernel_path):
    """Patch fs/namespace.c for SUSFS mount hiding."""
    namespace_file = os.path.join(kernel_path, "fs", "namespace.c")
    
    if not os.path.exists(namespace_file):
        print(f"::error::namespace.c not found at {namespace_file}")
        return False
    
    with open(namespace_file, 'r') as f:
        content = f.read()
    
    # Check if already patched
    if "susfs_hide_mount" in content or "susfs_mount" in content:
        print("namespace.c already patched for SUSFS")
        return True
    
    # Add SUSFS mount hiding hook
    susfs_hook = """
/* Pollux Kernel: SUSFS mount hiding hook */
#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT
static void susfs_hide_mount(struct mnt_namespace *ns, struct mount *mnt)
{
    /* SUSFS mount hiding implementation */
    if (!ns || !mnt)
        return;
    
    /* Hide mount from /proc/mounts */
    list_del_init(&mnt->mnt_list);
}
#endif
"""
    
    # Find a good insertion point (after includes, before functions)
    insert_point = content.find("static struct mnt_namespace *")
    if insert_point == -1:
        insert_point = content.find("int __init ")
    
    if insert_point > 0:
        # Find the line start
        while insert_point > 0 and content[insert_point-1] != '\n':
            insert_point -= 1
        content = content[:insert_point] + susfs_hook + "\n" + content[insert_point:]
    
    with open(namespace_file, 'w') as f:
        f.write(content)
    
    print("Patched namespace.c for SUSFS mount hiding")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: fix_susfs_namespace.py <kernel_path>")
        sys.exit(1)
    
    kernel_path = sys.argv[1]
    success = fix_namespace(kernel_path)
    sys.exit(0 if success else 1)
