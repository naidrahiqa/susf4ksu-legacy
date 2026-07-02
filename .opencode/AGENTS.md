# AGENTS.md — SUSFS Backport Team Orchestrator

> Master coordinator for `backport-susf4ksu-legacy` project skills.
> Routes workflows, assigns skills, orchestrates team operations.

---

## 👥 Team Registry

| Role | ID | Members | Assigned Skills | Status |
|------|----|---------|-----------------|--------|
| Technical Lead | `lead` | _(open)_ | `backport-validator`, `release-publisher` | Active |
| Code Reviewer | `reviewer` | _(open)_ | `backport-validator`, `apply-susfs-patches` | Active |
| Build Engineer | `devops` | _(open)_ | `apply-susfs-patches`, `backport-validator` | Active |

### Role Definitions

#### Technical Lead (`lead`)
- **Responsibilities**: Architecture decisions, patch approval, release management, kernel compatibility
- **Skills**: backport-validator, release-publisher
- **Escalation**: All critical findings

#### Code Reviewer (`reviewer`)
- **Responsibilities**: Code quality review, security audit of patches, fixup script validation
- **Skills**: backport-validator, apply-susfs-patches
- **Escalation**: High-severity issues

#### Build Engineer (`devops`)
- **Responsibilities**: CI/CD pipeline, build system, patch application automation
- **Skills**: apply-susfs-patches, backport-validator
- **Escalation**: Build failures, patch apply errors

---

## 🔧 Available Skills

### Skill: Apply SUSFS Patches
- **ID**: `apply-susfs-patches`
- **File**: `skills/apply-susfs-patches/SKILL.md`
- **Responsibility**: Apply SUSFS kernel patches, run fixup scripts, verify patch state on 4.19 NON-GKI kernel source
- **Triggers**: `patch_apply_request`, `pr_opened` (kernel paths), `manual_request`
- **Input Type**: `directory` (kernel source tree path)
- **Output Type**: `json` (patch status, .rej files, verification report)
- **Dependencies**: None
- **Estimated Runtime**: 30–120 seconds
- **Severity Levels**: Critical, High, Medium, Low
- **Owner Role**: `devops`
- **Key Commands**:
  ```bash
  bash pollux/apply.sh <kernel_dir> [--mtk] [--xiaomi-vermagic]
  bash pollux/verify.sh <kernel_dir>
  ```
- **Critical Constraints**:
  - Kernel 4.19 ONLY
  - CONFIG_FUSE_PASSTHROUGH must be disabled
  - MTK vendor files need `--fuzz=5` patching

### Skill: Backport Validator
- **ID**: `backport-validator`
- **File**: `skills/backport-susf4ksu-legacy/SKILL.md`
- **Responsibility**: Validate SUSFS backport integrity — universal patches, vendor patches, fixup scripts, core apply pipeline
- **Triggers**: `push_to_main`, `pr_opened`, `schedule_daily`, `manual_request`
- **Input Type**: `git-context` (diff paths, branch state)
- **Output Type**: `json` (CHK-001 through CHK-007 findings, quality score)
- **Dependencies**: None
- **Estimated Runtime**: 60–300 seconds
- **Severity Levels**: Critical, High, Medium, Low
- **Owner Role**: `reviewer`
- **Automated Checks**:
  - CHK-001: Universal patch directory integrity
  - CHK-002: Vendor patch dry-run validation
  - CHK-003: Fixup script syntax correctness
  - CHK-004: Core apply script end-to-end check
  - CHK-005: SELinux security hook audit
  - CHK-006: Patch application ordering
  - CHK-007: Backport completeness score

---

## 🔄 Workflow Definitions

### Workflow: Patch Application
**ID**: `patch-apply`
**Trigger**: Manual invocation, PR merge to main
**Trigger Conditions**: `kernel_dir provided`, `patch target (universal|vendor|both)`

#### Steps:

| Step | Skill | Condition | On Failure | Parallel With |
|------|-------|-----------|------------|---------------|
| `preflight` | `backport-validator` | always | halt | — |
| `apply-main` | `apply-susfs-patches` | on_success | halt | — |
| `apply-ksu` | `apply-susfs-patches` | on_success | halt | — |
| `apply-v220` | `apply-susfs-patches` | on_success | halt | — |
| `run-fixups` | `apply-susfs-patches` | on_success | retry(2) | — |
| `fix-includes` | `apply-susfs-patches` | on_success | retry(2) | — |
| `verify` | `backport-validator` | always | halt | — |

#### Flow:
```
Start → preflight(validate) → apply-main → apply-ksu → apply-v220 → run-fixups → fix-includes → verify → Done
```

**Output Action**: `report artifact` + `PR comment if triggered by PR`

---

### Workflow: Backport Validation
**ID**: `backport-validation`
**Trigger**: PR opened, push to main, schedule daily
**Trigger Conditions**: `paths match kernel/**, fixup/**, vendor/**, core-scripts/**`

#### Steps (parallel):

| Step | Skill | Condition | On Failure | Parallel |
|------|-------|-----------|------------|----------|
| `universal-check` | `backport-validator` | always | halt | yes |
| `vendor-check` | `backport-validator` | always | halt | yes |
| `fixup-check` | `backport-validator` | always | notify_only | yes |
| `core-script-check` | `backport-validator` | always | halt | yes |
| `security-check` | `backport-validator` | always | halt | yes |
| `ordering-check` | `backport-validator` | always | notify_only | yes |
| `completeness` | `backport-validator` | always | notify_only | yes |
| `report-gen` | `backport-validator` | always | notify_only | — |

#### Flow:
```
Trigger
    ↓
Run 7 checks PARALLEL ──────────────────┐
├─ universal-check (if fail → HALT)      │
├─ vendor-check (if fail → HALT)         │
├─ fixup-check (if fail → notify)        │
├─ core-script-check (if fail → HALT)    │
├─ security-check (if fail → HALT)       │
├─ ordering-check (if fail → notify)     │
└─ completeness (if fail → notify)       │
    ↓                                     │
All complete ←───────────────────────────┘
    ↓
report-gen → Create PR comment + artifact
```

**Output Action**: `create_pr_comment` with findings table + quality score

---

### Workflow: Release Build
**ID**: `release-build`
**Trigger**: Tag created matching `v*`
**Trigger Conditions**: `tag matches semver`

#### Steps:

| Step | Skill | Condition | On Failure | Parallel |
|------|-------|-----------|------------|----------|
| `full-validation` | `backport-validator` | always | halt | yes |
| `userspace-build` | `apply-susfs-patches` | always | notify_only | yes |
| `release-notes` | `release-publisher` | always | notify_only | — |
| `publish` | `release-publisher` | on_success | halt | — |

#### Flow:
```
Tag created
    ↓
run 2 steps PARALLEL:
├─ full-validation (strict mode) → halt on fail
└─ userspace-build (ndk-build) → notify on fail
    ↓
release-notes → publish → GitHub Release
    ↓
Notify team: slack + email
```

**Output Action**: `create_github_release` + notify team

---

### Workflow: Daily Audit
**ID**: `daily-audit`
**Trigger**: Schedule daily at 03:00 UTC
**Trigger Conditions**: `repository not archived`

#### Steps:

| Step | Skill | Condition | On Failure |
|------|-------|-----------|------------|
| `full-scan` | `backport-validator` | always | notify_only |
| `metrics-collect` | `backport-validator` | always | skip |
| `summary-report` | `backport-validator` | always | notify_only |

**Output Action**: `send_summary_email` to team + archive metrics

---

## 🎯 Skill Routing Logic

### Event-Based Routing

```yaml
triggers:
  push_to_main:
    - skills: [backport-validator]
      mode: full_scan
      parallel: false
      on_failure: halt
  
  pr_opened:
    - skills: [backport-validator]
      mode: pr_scan
      parallel: false
      on_failure: halt
  
  patch_apply_request:
    - skills: [apply-susfs-patches]
      on_failure: halt
      retry: 2
  
  tag_created_v*:
    - skills: [backport-validator, apply-susfs-patches]
      parallel: true
      on_failure: halt
  
  schedule_daily:
    - skills: [backport-validator]
      mode: health_check
      on_failure: notify_only
```

### Context-Based Routing

| Changed Path | Route To | Severity |
|-------------|----------|----------|
| `kernel/fs/susfs.c` | `apply-susfs-patches` (verify) | critical |
| `kernel/patches/**` | `backport-validator` (CHK-001, CHK-006) | high |
| `vendor/*/patches/**` | `backport-validator` (CHK-002) | high |
| `fixup/*` | `backport-validator` (CHK-003) | high |
| `core-scripts/apply.sh` | `backport-validator` (CHK-004) | critical |
| `kernel/include/linux/susfs.h` | `backport-validator` (CHK-005) | critical |
| `userspace/src/**` | `apply-susfs-patches` (build) | medium |

### Severity-Based Routing

| Severity | Action | Route To |
|----------|--------|----------|
| Critical | Halt workflow, alert Technical Lead | `lead` |
| High | Halt step, create issue, notify reviewer | `reviewer` |
| Medium | PR comment only, continue workflow | `reviewer` |
| Low | Include in summary report | `devops` |

---

## 🤝 Team Workflow Orchestration

### Developer Workflow
```
1. Developer clones kernel source
2. Runs `bash core-scripts/apply.sh <kernel_dir>`
3. AGENTS.md triggers:
   → backport-validator (preflight check)
   → apply-susfs-patches (patch application)
   → backport-validator (post-apply verification)
4. If all pass → Kernel ready for build
5. If .rej files found → Run fixup scripts, re-verify
```

### Code Review Workflow
```
1. PR opened with patch changes
2. AGENTS.md triggers backport-validation workflow
3. backport-validator runs CHK-001 through CHK-007
4. Results posted as PR comment:
   - Patch directory: OK/FAIL
   - Vendor patches: OK/FAIL
   - Fixup scripts: OK/FAIL
   - SELinux hooks: OK/FAIL (critical)
   - Backport score: X/10
5. Reviewer reviews PR + automated findings
6. Merge if all critical checks pass
```

### Release Workflow
```
1. Tag pushed (v*)
2. AGENTS.md triggers release-build workflow
3. Full validation runs (strict mode)
4. Userspace binary builds
5. Release notes generated
6. GitHub Release created
7. Team notified via channels
```

---

## 🔗 Skill Chaining

### Chain: Preflight → Apply → Verify

```yaml
backport-validator (preflight)
    ↓ (passes kernel_dir to)
apply-susfs-patches (apply all patches)
    ↓ (reports patch state)
backport-validator (post-verify)
    ↓ (generates final report)
```

### Data Flow

```yaml
Skill Outputs:
  backport-validator:
    preflight:
      output: { status, kernel_dir, patches_found }
      target: apply-susfs-patches
  
    verify:
      output: { status, rej_files, failed_hunks }
      target: report-generator (internal)
  
  apply-susfs-patches:
    apply_result:
      output: { applied, failed, rej_list }
      target: backport-validator (for verify)
```

---

## 💻 CLI Interface

### Manual Skill Invocation

```bash
# Apply SUSFS patches manually
opencode-agent run apply-susfs-patches \
  --kernel-dir ../kernel-source \
  --mtk \
  --xiaomi-vermagic

# Validate backport
opencode-agent run backport-validator \
  --mode full \
  --output json

# Run specific checks only
opencode-agent run backport-validator \
  --checks CHK-001,CHK-004,CHK-005
```

### Workflow Invocation

```bash
# Run full patch application workflow
opencode-agent workflow run patch-apply \
  --kernel-dir ../kernel-source

# Run backport validation on PR
opencode-agent workflow run backport-validation \
  --pr 123

# Run release build
opencode-agent workflow run release-build \
  --tag v2.2.0

# Run daily audit
opencode-agent workflow run daily-audit
```

### Management Commands

```bash
# List available skills
opencode-agent skills list

# Show skill details
opencode-agent skills info apply-susfs-patches

# List workflows
opencode-agent workflows list

# Check workflow status
opencode-agent workflow status patch-apply

# View logs
opencode-agent logs apply-susfs-patches
opencode-agent logs backport-validator

# Validate AGENTS.md
opencode-agent validate-agents
```

---

## ⚙️ Configuration

### workflow-config.yaml

```yaml
team:
  name: "SUSFS Backport Development Team"
  size: 3
  project: "backport-susf4ksu-legacy"
  leads: []

skills:
  apply-susfs-patches:
    timeout_seconds: 180
    retry_count: 2
    fuzz_level: 5
    fallback_wiggle: true
  
  backport-validator:
    timeout_seconds: 300
    retry_count: 1
    strict_mode: false
    required_patches_min: 3
    severity_cutoff: medium

workflows:
  patch-apply:
    enabled: true
    strict_mode: false
    notify_on_complete: true
    notify_channels: [github-pr-comment]
  
  backport-validation:
    enabled: true
    strict_mode: false
    notify_on_complete: true
    notify_channels: [github-pr-comment]
    auto_run_on_pr: true
  
  release-build:
    enabled: true
    strict_mode: true
    notify_channels: [github, email]
    require_full_pass: true
  
  daily-audit:
    enabled: true
    schedule: "0 3 * * *"
    notify_channels: [email]

notifications:
  critical_issues:
    channels: [email]
    recipients: [team@project.dev]
    auto_create_issue: true
  
  summary_reports:
    channels: [github-pr-comment]
    frequency: per-workflow

paths:
  kernel_patches: "kernel/"
  fixup_scripts: "fixup/"
  vendor_dir: "vendor/"
  core_scripts: "core-scripts/"
  userspace: "userspace/src/"
```

---

## 📊 Monitoring & Metrics

### Skill Execution Metrics

```json
{
  "skill_id": "apply-susfs-patches",
  "last_execution": "2026-06-29T10:30:00Z",
  "execution_count_total": 0,
  "success_rate": 0.0,
  "average_runtime_seconds": 0,
  "patches_applied": 0,
  "patches_failed": 0,
  "rej_files_found": 0
}

{
  "skill_id": "backport-validator",
  "last_execution": "2026-06-29T10:30:00Z",
  "execution_count_total": 0,
  "success_rate": 0.0,
  "average_runtime_seconds": 0,
  "checks_passed": 0,
  "checks_failed": 0,
  "issues_by_severity": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0
  }
}
```

### Workflow Metrics

```json
{
  "workflow_id": "patch-apply",
  "execution_count": 0,
  "success_rate": 0.0,
  "average_duration_seconds": 0,
  "successful_applies": 0,
  "failed_applies": 0
}

{
  "workflow_id": "backport-validation",
  "execution_count": 0,
  "success_rate": 0.0,
  "average_duration_seconds": 0,
  "blocked_prs": 0,
  "critical_issues_caught": 0
}
```

### Dashboard Queries

```sql
-- Skill success rate
SELECT skill_id, success_rate, avg_runtime
FROM skill_metrics
ORDER BY success_rate ASC;

-- Pending workflows
SELECT workflow_id, status, started_at
FROM workflow_runs
WHERE status = 'running';

-- Issues by severity
SELECT severity, COUNT(*) as count
FROM issues
WHERE created_at > date('now', '-7 days')
GROUP BY severity;
```

---

## 🔧 Troubleshooting

### Common Issues

| Issue | Likely Cause | Solution |
|-------|-------------|----------|
| Patch fails with `.rej` files | Kernel source mismatch (wrong version, MTK conflicts) | Retry with `--fuzz=5`, fallback to `wiggle` |
| `susfs_def.h` not found | Include path mismatch | Run `sed -i 's|susfs_def\.h|susfs.h|g'` on KernelSU source |
| Fixup script fails | Missing target file (patches changed kernel structure) | Run `fixup/gen_extra_hunks.py` manually |
| Validation CHK-001 fails | No patches in `kernel/patches/` | Verify patch directory exists and has `.patch` files |
| Validation CHK-004 fails | `core-scripts/apply.sh` missing phases | Check apply.sh has: patch_prep, apply_universal, apply_vendor, run_fixup, verify |

### Recovery Procedures

```bash
# 1. Patch failure recovery
opencode-agent run apply-susfs-patches --force --fuzz 5

# 2. Check .rej files
find <kernel_dir> -name "*.rej" 2>/dev/null

# 3. Manual wiggle fallback
find <kernel_dir> -name "*.rej" -exec wiggle --replace {} +

# 4. Fix includes
find <kernel_dir>/drivers/kernelsu -type f -exec sed -i 's|susfs_def\.h|susfs.h|g' {} +

# 5. Re-verify
bash core-scripts/verify.sh <kernel_dir>
```

---

## 📚 Example Workflows

### Example 1: Apply SUSFS to Kernel Source

```bash
# Step 1: Preflight check
opencode-agent run backport-validator --mode preflight --kernel-dir ../kernel

# Step 2: Apply patches (auto)
opencode-agent workflow run patch-apply --kernel-dir ../kernel --mtk

# Step 3: Verify
opencode-agent run backport-validator --mode verify --kernel-dir ../kernel

# Step 4: Build userspace
cd userspace/src && ndk-build
```

### Example 2: Review PR with Patch Changes

```bash
# Triggered automatically on PR open
# Or run manually:
opencode-agent workflow run backport-validation --pr 42 --branch feature/susfs-v2.2

# Expected output: PR comment with:
# - CHK-001: UNIVERSAL_PATCHES_OK (6 patches)
# - CHK-002: VENDOR_PATCHES_OK (3 patches)
# - CHK-005: SELINUX_HOOKS_DONE (2 selinux patches)
# - CHK-007: BACKPORT_SCORE_OK (8/10)
```

### Example 3: Release v2.2.0

```bash
# Create tag
git tag -a v2.2.0 -m "SUSFS v2.2.0 backport release"

# Push tag (triggers release-build workflow)
git push origin v2.2.0

# Or run manually:
opencode-agent workflow run release-build --tag v2.2.0

# Verify release
opencode-agent run backport-validator --mode release --tag v2.2.0
```

### Example 4: Daily Health Check

```bash
# Scheduled at 03:00 UTC daily
# Or run manually:
opencode-agent workflow run daily-audit

# Check results:
opencode-agent logs backport-validator --date today
```

---

## 📋 Validation Checklist

Before running workflows, verify:

- [ ] All skills referenced exist in `skills/` directory
- [ ] `apply-susfs-patches/SKILL.md` exists and is complete
- [ ] `backport-susf4ksu-legacy/SKILL.md` exists and is complete
- [ ] Workflow step IDs reference valid skill IDs
- [ ] No circular dependencies in skill chaining
- [ ] Notification channels configured with valid recipients
- [ ] CLI examples match actual skill parameters
- [ ] Configuration file (`config/workflow-config.yaml`) created
- [ ] All severity levels defined per skill

---

## 🧩 Integration with SKILL.md

```
AGENTS.md (Orchestrator)                SKILL.md (Executor)
│                                       │
├─ Routes events to skills              ├─ Implements exact check logic
├─ Defines workflow ordering            ├─ Defines automated checks
├─ Sets failure behavior                ├─ Specifies input/output format
├─ Configures notifications             ├─ Includes error handling
└─ Tracks metrics                       └─ Documents edge cases

Example:
AGENTS.md: "When PR opened, run CHK-001 thru CHK-007"
    ↓
backport-susf4ksu-legacy/SKILL.md: Implements check logic for each CHK-NNN
    ↓
AGENTS.md: "Post results as PR comment, halt on critical failures"
```

---

*Generated: 2026-06-29 | Project: backport-susf4ksu-legacy | Kernel: 4.19 NON-GKI*
