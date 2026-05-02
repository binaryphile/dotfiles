# Handoff: Keychain/Age Removal — Doc Updates Remaining

## What happened

Commit `cdc58f7` removed keychain, ssh-agent, age encryption, and on-disk SSH key infrastructure from dotfiles. The code is complete: keychain package removed from shared.nix, bash hook removed, update-env functions removed (~320 lines), age scripts and .age files deleted, sshAgentPreflight added.

## What's left

The docs still reference the removed infrastructure. Each doc needs updating to reflect the new state: 1Password SSH agent is the sole auth path, no on-disk private keys, no age encryption.

### Policy

- No persistent on-disk private key material
- No encrypted material in git (age or otherwise)
- Sensitive docs stored as 1Password secure documents (already uploaded: dotfiles/security.md, dotfiles/secrets-lifecycle.md, dotfiles/threat-model.md)
- 1Password SSH agent via IdentityAgent in ssh/config + SSH_AUTH_SOCK in sessionVariables
- sshAgentPreflight gates credential phase with actionable error messages
- Headless/remote sessions without 1Password require SSH agent forwarding

### Task 1: docs/design.md

Search for and remove/update these references:
- `keychain` — architecture description, hook ordering, startup performance notes
- `loadSshKey`, `restoreSshKey`, `restoreSshKeyImpl`, `sshKeyAction` — function descriptions
- `sshKeyEpilogue`, `SshKeyStatus` — epilogue flow
- `installKey`, `pubFingerprint`, `sshKeygenTask` — helper descriptions
- `age`, `.age`, `encrypt-secrets`, `with-secret`, `security-docs` — age encryption workflow
- `ssh/*.age`, `secrets/` — structure listing (remove DEPRECATED lines)
- Migration notes referencing keychain removal — replace with "Migration complete"
- Deployment flow step 4 — update to: sshAgentPreflight -> deploySigningPub -> restoreSecrets -> agentTomlTask -> authPreflight -> runSigningKeyPreflight
- Document unsupported environments: headless/remote without 1Password needs agent forwarding
- `SSH_AGENT_PID` — remove from any descriptions
- Startup performance section (~line 658) — remove keychain timing, update budget

Approximate references: ~20. Run `grep -n 'keychain\|loadSshKey\|restoreSshKey\|sshKeyAction\|sshKeyEpilogue\|SshKeyStatus\|installKey\|pubFingerprint\|sshKeygenTask\|encrypt-secrets\|with-secret\|security-docs\|\.age\b\|ssh-agent\|SSH_AGENT_PID' docs/design.md` to find them all.

### Task 2: docs/security.md

This is a sensitive doc (stored in 1Password, local plaintext in docs/security.md, gitignored). If it exists on disk, update it. If not, retrieve from 1Password first.

Remove/update:
- keychain threat model entries (lines ~62, 98, 243, 280, 297, 307, 310)
- on-disk key material risk analysis (lines ~270-272)
- `loadSshKey`, `with-secret`, `encrypt-secrets` references
- `SSH_AGENT_PID`, `ssh-agent` references
- Age encryption threat model
- Update ssh-agent socket entry (~line 457) — only 1Password agent, no keychain
- PATH-dependent command analysis — remove keychain from the list

Run `grep -n 'keychain\|ssh-agent\|SSH_AGENT_PID\|loadSshKey\|with-secret\|encrypt-secrets\|\.age\b' docs/security.md`.

### Task 3: docs/uc-init.md, docs/use-cases.md, docs/environment-lifecycle.md

- uc-init.md line ~287: remove "Keychain retained as break-glass fallback" — replace with 1Password SSH agent as sole auth path
- use-cases.md UC-4: remove key restore step, note sshAgentPreflight. Update UC-4a (rotation is vault-only). Update migration note to reflect completion.
- environment-lifecycle.md line ~74: remove "Decrypt and review security.md" — security.md is now in 1Password, not age-encrypted in repo

### Task 4: claude/CLAUDE.md, TESHT_WISHLIST.md, lib_test.bash, update-env comments

- claude/CLAUDE.md lines ~25-27: remove references to `.age` files and `scripts/security-docs decrypt`
- TESHT_WISHLIST.md lines ~40-67: remove installKey, restoreSigningKey, sshKeyGenerate, pubFingerprint test wishlists (functions no longer exist)
- lib_test.bash line ~121: remove encrypt-secrets/restoreSecrets cross-reference comment
- update-env line ~584: check `with-secret` comment, line ~993: check `encrypt-secrets` reference in restoreSecrets message
- scripts/archive/Rakefile line ~195: keychain reference (if still tracked)

### Task 5: Strip removed files from git history

Run git-filter-repo to strip .age files and removed scripts from all git history:
```
nix shell nixpkgs#git-filter-repo --command git-filter-repo --force --invert-paths \
  --path docs/security.md.age \
  --path docs/secrets-lifecycle.md.age \
  --path docs/threat-model.md.age \
  --path docs/.age-recipients \
  --path scripts/encrypt-secrets \
  --path scripts/with-secret \
  --path scripts/security-docs \
  --path-glob 'ssh/*.age' \
  --path-glob 'secrets/*.tar.age'
```

Then re-add origin and force push. Requires VPN or appropriate SSH agent for stash repos. This repo is on github.com:binaryphile/dotfiles.git.

## Verification (run after all tasks complete)

```bash
grep -rn 'keychain\|ssh-agent\|SSH_AGENT_PID\|\.age\b\|encrypt-secrets\|with-secret\|security-docs\|loadSshKey\|restoreSshKey\|sshKeyAction\|sshKeygenTask\|installKey\|pubFingerprint\|SshKeyStatus\|sshKeyEpilogue' ~/dotfiles/ | grep -v .git/ | grep -v update-environment | grep -v .gitignore
```

Expected: zero results.
