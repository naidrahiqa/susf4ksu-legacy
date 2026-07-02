# AGENTS.md — SUSFS Backport (Legacy/Universal)

Backport SUSFS v2.2.0+ features to legacy 4.19 NON-GKI kernels. Universal — not device-specific.

---

## Team Registry

| Role | ID | Core Skill |
|------|-----|------------|
| Patcher | `patcher` | `susfs-backport-validator` |
| Build Tester | `builder` | `susfs-backport-validator` |
| Troubleshooter | `troubleshooter` | `susfs-backport-validator` |
| Auditor | `auditor` | `susfs-backport-validator` |

## Core Skill

### SUSFS Backport Validator Developer Skill
- **ID**: `susfs-backport-validator`
- **File**: `SKILL.md`
- **Responsibility**: Validate kernel patch sequence, vendor patches (Xiaomi/MediaTek), fixup/ scripts, core-scripts/apply.sh pipeline, SUSFS-SELinux integration
- **Triggers**: Push to main (patches/**), PR, manual
- **Input Type**: git-context / code-diff
- **Output Type**: json
- **Runtime**: ~300s
- **Owner**: patcher, auditor

## Role Skills

| Role | Skill File | Responsibility |
|------|-----------|----------------|
| Kernel Patcher (SUSFS) | `../../.opencode/skills/kernel-patcher-susfs/SKILL.md` | Apply SUSFS universal/vendor patches; wiggle fallback; fixup scripts; .rej detection |
| Build Tester | `../../.opencode/skills/build-tester/SKILL.md` | Run apply.sh dry-run; full kernel build; verify SUSFS/SELinux config; QEMU boot test |
| Code Reviewer | `../../.opencode/skills/code-reviewer/SKILL.md` | Review patch order/headers; shellcheck fixup scripts; enforce no binary blobs |

## Workflow Definitions

### Workflow: SUSFS Apply
**ID**: `susfs-apply`
**Trigger**: Push to main

**Steps (sequential):**
1. **Main Patch** → `susfs-backport-validator` (50_add_susfs) → on failure: halt
2. **KSU Patch** → `susfs-backport-validator` (10_enable_susfs_for_ksu) → on failure: halt
3. **Extra Patches** → `susfs-backport-validator` (004, 005) → on failure: halt
4. **Fixups** → `susfs-backport-validator` (Python fixups) → on failure: halt
5. **Verify** → `susfs-backport-validator` (verify.sh) → on failure: halt
6. **Build Test** → `susfs-backport-validator` → on failure: notify_only

**Est. Duration**: ~900 seconds

## Critical Constraints

- **Patch order is critical**: Main → KSU → Additional → Fixups
- **Kernel 4.19 ONLY**
- **wiggle fallback** if `--fuzz=5` fails
- **Check .rej files** after each patch step

## Project Context

```json
{
  "project_name": "SUSFS Backport",
  "project_type": "kernel",
  "primary_languages": ["C", "Shell", "Python"],
  "ci_cd_platform": "github-actions",
  "stage": "maintenance"
}
```
