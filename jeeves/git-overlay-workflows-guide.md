# Git Local Changes Management Guide: Alternative Workflows Comparison

## Overview
This guide compares different approaches for managing local development changes (tools, configs, personal notebooks) alongside your main development work, addressing the challenges of patch queue management, history preservation, and conflict resolution.

## Current Situation Assessment
Ted maintains two patch queues using stgit:
1. **Tools queue**: Development tools (urma script, Claude config, MCP installations, React resources)
2. **Vault queue**: Obsidian-vault notebook (planned for eventual release integration)

### Pain Points
1. Difficulty segregating changes by subject matter
2. Managing two separate patch queues
3. Git conflicts when switching branches
4. No history preservation (patches are stateless)

---

## Solution Comparison

### 1. Git-Series (Versioned Patch Queue)

#### Usage Model
Git-series treats your patches as a first-class versioned entity, tracking how your patch series evolves over time.

#### Daily Workflow
```bash
# Start a new series for your tools
git series start tools-overlay
git series base main

# Make changes to your tools
vim .mcp/config.json
git add .mcp/
git commit -m "Add MCP configuration"

# Make more changes
vim urma-script.sh
git add urma-script.sh
git commit -m "Add urma development script"

# Save the current state of your patch series
git series commit -a -m "Initial tools overlay setup"

# Later, after rebasing or reorganizing
git series rebase -i
git series commit -a -m "Reorganized after feedback"

# View history of your patch series
git series log
```

#### Switching Between Work
```bash
# Your patches exist as commits on top of base
# To work without patches:
git checkout main

# To work with patches:
git series checkout tools-overlay
```

#### Pros
- Full history of how patches evolved
- Can track multiple iterations
- Designed for patch-based workflows

#### Cons
- Still fundamentally patch-based
- Requires learning new commands
- Need to manually commit series changes
- Requires Rust/Cargo installation

---

### 2. Git Worktrees + Overlay Branches

#### Usage Model
Multiple working directories, each with its own branch, eliminating the need to switch branches in your main work area.

#### Initial Setup
```bash
# From your main project directory
cd ~/projects/myproject

# Create persistent overlay branches
git branch tools-overlay main
git branch vault-overlay main

# Create separate worktrees
git worktree add ../myproject-tools tools-overlay
git worktree add ../myproject-vault vault-overlay
```

#### Daily Workflow
```bash
# Work on main feature in main directory
cd ~/projects/myproject
git checkout feature-branch
# ... make changes ...

# Need to update tools? Switch directories, not branches
cd ~/projects/myproject-tools
vim .mcp/config.json
git add .mcp/
git commit -m "Update MCP config"

# Update vault separately
cd ~/projects/myproject-vault
vim obsidian-vault/notes.md
git commit -am "Update notes"

# Apply overlays to current feature branch
cd ~/projects/myproject
git cherry-pick tools-overlay
git cherry-pick vault-overlay~3..vault-overlay  # last 3 commits
```

#### Sync Script Example
```bash
#!/bin/bash
# sync-overlays.sh
cd ~/projects/myproject
git cherry-pick tools-overlay
git cherry-pick vault-overlay
```

#### Pros
- No branch switching conflicts
- Full git history in each overlay
- Can work on all three simultaneously
- Clean separation of concerns

#### Cons
- Multiple directories to manage
- More disk space usage
- Need to remember which directory you're in
- **Vault not current with working copy changes**

---

### 3. YADM-Style Overlay Management

#### Usage Model
Treats your project directory like a home directory with overlay files managed separately.

#### Setup
```bash
# Initialize yadm-style repo for overlays
mkdir .overlay-git
git init --bare .overlay-git
alias ogit='git --git-dir=.overlay-git --work-tree=.'

# Add overlay files
ogit add .mcp/ urma-script.sh CLAUDE.md
ogit commit -m "Initial overlay setup"
```

#### Daily Workflow
```bash
# Work normally in main repo
git add src/
git commit -m "Feature work"

# Update overlay files using ogit
vim .mcp/config.json
ogit add .mcp/config.json
ogit commit -m "Update MCP config"

# Check overlay status
ogit status

# Push overlays to separate remote
ogit remote add origin git@github.com:me/project-overlays.git
ogit push
```

#### Template Support
```bash
# Create OS-specific versions
cp config.json config.json##os.Linux
cp config.json config.json##os.Darwin
# YADM would auto-select based on OS
```

#### Pros
- No symlinks needed
- Overlays coexist with main repo
- Can track overlay history separately

#### Cons
- Two git commands to remember (git vs ogit)
- Can be confusing which repo tracks what
- Not standard YADM (custom implementation)

---

### 4. Template + Local Config Pattern

#### Usage Model
Maintain template files in git, actual configs in gitignored files.

#### Setup
```bash
# Create templates
cp .mcp/config.json .mcp/config.json.template
cp urma-script.sh urma-script.sh.template

# Add to .gitignore
echo ".mcp/config.json" >> .gitignore
echo "urma-script.sh" >> .gitignore
echo "obsidian-vault/" >> .gitignore

# Commit templates
git add .mcp/config.json.template urma-script.sh.template
git commit -m "Add configuration templates"
```

#### Daily Workflow
```bash
# First time setup
cp .mcp/config.json.template .mcp/config.json
cp urma-script.sh.template urma-script.sh

# Edit local configs freely
vim .mcp/config.json  # This won't be committed

# When adding new config options
vim .mcp/config.json.template  # Update template
git add .mcp/config.json.template
git commit -m "Add new config option to template"
```

#### Automation Script
```bash
#!/bin/bash
# setup-local-configs.sh
for template in $(find . -name "*.template"); do
    target="${template%.template}"
    if [ ! -f "$target" ]; then
        cp "$template" "$target"
        echo "Created $target from template"
    fi
done
```

#### Pros
- Dead simple
- No special tools required
- Clear separation between tracked/untracked

#### Cons
- No history for local configs
- Manual template synchronization
- Can forget to update templates

---

### 5. Git Filter Drivers

#### Usage Model
Automatic transformation of files on commit/checkout using git's clean/smudge filters.

#### Setup
```bash
# Define filter in .git/config
git config filter.config.clean 'sed -f clean-config.sed'
git config filter.config.smudge 'sed -f smudge-config.sed'

# Apply to files via .gitattributes
echo ".mcp/config.json filter=config" >> .gitattributes
echo "urma-script.sh filter=config" >> .gitattributes
```

#### Clean Script (clean-config.sed)
```sed
# Replace personal values with placeholders
s/api_key=.*/api_key=YOUR_API_KEY/
s/workspace=.*/workspace=YOUR_WORKSPACE/
```

#### Smudge Script (smudge-config.sed)
```sed
# Replace placeholders with actual values
s/YOUR_API_KEY/abc123def456/
s/YOUR_WORKSPACE/ted-workspace/
```

#### Daily Workflow
```bash
# Edit files normally
vim .mcp/config.json  # Contains real values

# Git automatically cleans on add
git add .mcp/config.json  # Placeholders stored

# On checkout, git automatically smudges
git checkout other-branch  # Real values restored
```

#### Pros
- Completely automatic
- No manual intervention needed
- Prevents accidental secret commits

#### Cons
- Complex setup
- Debugging can be difficult
- Filter scripts need maintenance
- Not portable across clones without setup

---

### 6. Guilt (Git-based MQ Clone)

#### Usage Model
Mercurial-style patch queue management built on git.

#### Setup
```bash
# Install guilt
git clone git://github.com/jeffpc/guilt.git
cd guilt
make install

# Initialize in your project
cd ~/projects/myproject
guilt init
```

#### Daily Workflow
```bash
# Create new patches
guilt new tools-config.patch
# ... make changes ...
guilt refresh  # Save changes to patch

guilt new vault-integration.patch
# ... make changes ...
guilt refresh

# View patch stack
guilt series
guilt applied
guilt unapplied

# Modify existing patch
guilt push tools-config.patch
# ... make changes ...
guilt refresh

# Remove patches before commit
guilt pop -a
git commit -m "Feature work"

# Reapply patches
guilt push -a
```

#### Managing Multiple Queues
```bash
# Create separate queue for vault
mkdir .git/patches/vault-queue
guilt branch vault-queue

# Switch between queues
guilt branch tools-queue
guilt branch vault-queue
```

#### Pros
- Familiar if you know Mercurial's MQ
- Powerful patch manipulation
- Can maintain multiple queues

#### Cons
- Still patch-based (same fundamental issues)
- No built-in history tracking
- Learning curve for commands
- Can lose work if not careful

---

## Single Working Copy Solutions for Integrated Vault

Since the Obsidian vault needs to stay current with active development changes in the working copy, here are solutions that keep everything in one place:

### Solution A: **Dual-Repository Overlay** (RECOMMENDED)

#### Concept
Run two git repositories in the same directory - main repo ignores vault, overlay repo tracks vault.

#### Setup
```bash
# In your project directory
cd ~/projects/myproject

# Main repo ignores vault
echo "obsidian-vault/" >> .gitignore
git add .gitignore
git commit -m "Ignore obsidian vault"

# Create overlay repo for vault and tools
git init --bare .overlay
alias ogit='git --git-dir=.overlay --work-tree=.'

# Track vault and tools in overlay
ogit add obsidian-vault/ .mcp/ urma-script.sh CLAUDE.md
ogit commit -m "Initial overlay with vault"

# Create branches in overlay repo
ogit branch tools-overlay
ogit branch vault-overlay
```

#### Daily Workflow
```bash
# Work normally, vault updates automatically reflect current state
vim src/component.jsx
git add src/
git commit -m "Update component"

# Claude updates vault based on current code
# Vault sees real-time changes

# Periodically commit vault changes to overlay
ogit add obsidian-vault/
ogit commit -m "Vault updates from feature work"

# When ready to integrate vault to release
ogit log --oneline vault-overlay  # Review vault commits
# Cherry-pick or merge specific vault commits to main repo
```

#### Integration Script
```bash
#!/bin/bash
# sync-vault-to-release.sh
# Run when vault is ready for release branch

# Export vault commits as patches
ogit format-patch --stdout vault-overlay > vault-changes.patch

# Apply to release branch in main repo
git checkout release
git am vault-changes.patch
```

#### Pros
- Vault stays current in working directory
- Clean separation of concerns
- Full history in both repos
- Easy integration when ready
- No conflicts between repos
- Works seamlessly with Claude

#### Cons
- Two git commands to manage
- Need to remember which repo for which files

### Solution B: **Smart Stashing Strategy**

#### Concept
Use git's stash with custom scripts to manage vault separately while keeping it in working directory.

#### Setup
```bash
# Create stash management scripts
cat > stash-vault.sh << 'EOF'
#!/bin/bash
# Stash only vault changes
git add -A
git stash push -m "vault-$(date +%Y%m%d-%H%M%S)" -- obsidian-vault/
EOF

cat > pop-vault.sh << 'EOF'
#!/bin/bash
# Restore latest vault stash
git stash list | grep "vault-" | head -1 | cut -d: -f1 | xargs git stash pop
EOF
```

#### Daily Workflow
```bash
# Before committing feature work
./stash-vault.sh  # Temporarily remove vault
git add .
git commit -m "Feature work"
./pop-vault.sh    # Restore vault to working directory

# Vault continues reflecting current state
```

#### Pros
- Simple concept
- Vault always current
- Uses standard git features

#### Cons
- Manual stash/pop required
- Can lose stashes if not careful
- No real version history

### Solution C: **Git Submodule as Overlay**

#### Concept
Vault as a submodule that you don't commit in feature branches.

#### Setup
```bash
# Create separate vault repo
mkdir ~/projects/vault-repo
cd ~/projects/vault-repo
git init
echo "# Vault" > README.md
git add .
git commit -m "Initial vault"

# Add as submodule to main project
cd ~/projects/myproject
git submodule add ../vault-repo obsidian-vault
git commit -m "Add vault submodule"

# Configure to not track submodule changes in feature branches
git update-index --skip-worktree .gitmodules
git update-index --skip-worktree obsidian-vault
```

#### Daily Workflow
```bash
# Work in main repo - vault changes ignored
vim src/file.js
git add src/
git commit -m "Feature work"  # Vault changes not included

# Commit vault changes separately
cd obsidian-vault
git add .
git commit -m "Update vault"
cd ..

# When ready for release
git update-index --no-skip-worktree obsidian-vault
git add obsidian-vault
git commit -m "Update vault pointer for release"
```

#### Pros
- Vault has separate history
- Clean git integration
- Standard git feature

#### Cons
- Submodules can be confusing
- Need to manage skip-worktree flags
- Extra steps for vault commits

---

## Comparison Matrix

| Aspect | Git-Series | Worktrees | YADM-Style | Template | Filter Drivers | Guilt | Dual-Repo |
|--------|------------|-----------|------------|----------|----------------|-------|-----------|
| **History Tracking** | Excellent | Excellent | Good | None | None | None | Excellent |
| **Conflict Prevention** | Moderate | Excellent | Good | Excellent | Good | Poor | Excellent |
| **Learning Curve** | High | Low | Moderate | Very Low | High | High | Low |
| **Automation** | Moderate | High | Moderate | Low | Excellent | Low | Moderate |
| **Disk Space** | Low | High | Low | Low | Low | Low | Low |
| **Segregation Ease** | Good | Excellent | Good | Excellent | Moderate | Moderate | Excellent |
| **Collaboration** | Good | Excellent | Moderate | Excellent | Poor | Poor | Good |
| **Recovery** | Excellent | Excellent | Good | Poor | Poor | Poor | Excellent |
| **Vault Integration** | Poor | Poor | Good | N/A | Poor | Poor | Excellent |

---

## Final Recommendation

For Ted's specific use case with requirements for:
- Two patch queues (tools and vault)
- Vault needing to see current working copy changes
- History preservation
- Clean separation of concerns
- Eventual vault integration to release

**Recommended Solution: Dual-Repository Overlay**

This approach:
1. Eliminates patch queue complexity
2. Maintains full git history for safety
3. Keeps vault current with working changes
4. Provides clean path to release integration
5. Prevents conflicts through separation
6. Works seamlessly with Claude Code

### Migration Plan from stgit

1. **Backup current patches**
   ```bash
   stg export --dir ~/patch-backup
   ```

2. **Setup dual-repository**
   ```bash
   echo "obsidian-vault/" >> .gitignore
   echo ".mcp/" >> .gitignore
   echo "urma-script.sh" >> .gitignore
   git commit -am "Prepare for overlay setup"
   
   git init --bare .overlay
   echo "alias ogit='git --git-dir=.overlay --work-tree=.'" >> ~/.bashrc
   ```

3. **Import patches to overlay**
   ```bash
   ogit add obsidian-vault/ .mcp/ urma-script.sh CLAUDE.md
   ogit commit -m "Import from stgit patches"
   ```

4. **Test workflow for one week**

5. **Remove stgit when comfortable**
   ```bash
   stg branch --delete --force
   ```

---

## Alternative: Different Tool Entirely

If none of these git-based solutions appeal, consider:

1. **Fossil** - Different VCS with better branch management
2. **Mercurial with MQ** - Native patch queue support
3. **Perforce** - Professional shelving system
4. **PlasticSCM** - Advanced branching model

But given your existing git infrastructure and tooling, the dual-repository overlay provides the best balance of power, simplicity, and integration with your current workflow.