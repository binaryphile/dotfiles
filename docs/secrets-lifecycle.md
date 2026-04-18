# Secrets Lifecycle

Operational companion to [design.md](design.md) and [security.md](security.md). SSH keys and secrets are backed up to 1Password -- not to the repo. See [security.md](security.md) for the full security model, including why encrypted material must not be committed to a public repo.

Use cases for each workflow live in [use-cases.md](use-cases.md) (UC-4a through UC-4d). This doc covers the operational procedures that implement them.

**When to read which doc:**

| Question | Doc |
|----------|-----|
| Why can't we store .age files in the repo? | [security.md](security.md) (Core Constraint) |
| What are the trust boundaries? | [security.md](security.md) (Trust Boundaries) |
| How does the restore priority work? | [design.md](design.md#ssh-key-bootstrap-uc-4) |
| How do I rotate my SSH key? | This doc ([Key rotation](#key-rotation)) |
| I hit a fingerprint mismatch | This doc ([Fingerprint mismatch](#fingerprint-mismatch)) |
| How do I add a new secret? | This doc ([Add, update, remove](#add-update-remove)) |

For how `update-env` decides which restore action to take, see the [decision table](design.md#ssh-key-bootstrap-uc-4) and `SshKeyStatus` values in design.md.

## SSH Key Workflows

**Hostname:** procedures below use `$HOST`. Set it before running any procedure:
```
HOST=$(cd ~/dotfiles && source scripts/lib.bash && lib.MachineHostname)
```
On Crostini this reads `$CrostiniDir/hostname`, not the system hostname. Always use this rather than bare `hostname`.

### Zero-bootstrap

No key exists anywhere for this hostname. Path: `generate`.

1. Run `update-env`
2. `sshKeyGenerate` prompts for SSH passphrase, creates `~/.ssh/id_ed25519`
3. If on Crostini: caches to `$CrostiniDir/ssh/<hostname>/`
4. `authPreflight` reports "key not registered" for all providers

**Post-steps (manual):**
- Store private key in 1Password (vault item named `SSH <hostname>`)
- `cd ~/dotfiles && git add ssh/id_ed25519_<hostname>.pub && git commit && git push`
- Register `~/.ssh/id_ed25519.pub` with GitHub, Codeberg, Bitbucket settings

**Machine replacement** is the same workflow. New hostname = no state for that hostname.

### Normal restore

Restore priority (same order as [design.md](design.md#ssh-key-bootstrap-uc-4)):

1. **Local** -- `~/.ssh/id_ed25519` present, fingerprint matches repo `.pub` -> no action needed
2. **Mount cache** (Crostini only) -- powerwash: mount cache at `$CrostiniDir/ssh/<hostname>/` survives -> `restore_from_cache`, no passphrase. Validates fingerprint against repo `.pub`
3. **1Password** -- container reset (cache lost) or non-Crostini fresh machine -> retrieve via `op` CLI or manually from app, place at `~/.ssh/id_ed25519`, `chmod 600`, re-run `update-env`

### Key rotation

Manual procedure. Ordering matters -- do not destroy the only copy. See UC-4a in [use-cases.md](use-cases.md).

For either key type, the procedure is:

1. Verify current key is in 1Password. If not, store it now.
2. Delete local key and repo `.pub`. Clear mount cache if auth key on Crostini.
3. Run `update-env` -- generates new key.
4. Store new private key in 1Password.
5. Commit new `.pub`: `cd ~/dotfiles && git add ssh/ && git commit && git push`
6. Register new `.pub`, deregister old.

**Key-specific details:**

| Step | Auth key | Signing key |
|------|----------|-------------|
| Delete | `rm ~/.ssh/id_ed25519{,.pub}` `rm ~/dotfiles/ssh/id_ed25519_$HOST.pub` `rm -rf $CrostiniDir/ssh/$HOST/` | `rm ~/.ssh/id_ed25519_signing{,.pub}` `rm ~/dotfiles/ssh/id_ed25519_signing_$HOST.pub` |
| 1Password item | `$HOST SSH Key` or similar | `$HOST signing SSH Key` |
| Register | All registries (auth key) | GitHub + Codeberg only (signing key) |

No automated rotation command exists. This is a known gap.

### Collision recovery

**Symptom:** `update-env` prints "collision: local key fingerprint does not match repo"

**Cause:** `~/.ssh/id_ed25519` and `ssh/id_ed25519_<hostname>.pub` have different fingerprints. Typically happens if a key was generated outside `update-env`.

**Resolution:**
1. Compare fingerprints: `ssh-keygen -lf ~/.ssh/id_ed25519.pub` vs `ssh-keygen -lf ~/dotfiles/ssh/id_ed25519_$HOST.pub`
2. Check 1Password for the authoritative key
3. Check registered keys (GitHub/Codeberg/Bitbucket SSH key settings) to determine which fingerprint is registered
4. If local is authoritative: update repo `.pub`, store key in 1Password if not already there
5. If 1Password is authoritative: `rm ~/.ssh/id_ed25519{,.pub}`, retrieve from 1Password, re-run `update-env`
6. If neither is registered: either key works -- keep local (simpler), store in 1Password, register with registries
7. If you cannot determine authority: **stop**. Do not delete either key. Back up both, then consult 1Password and registry settings.

### Cleanup and decommission

Remove a retired machine's key material. See UC-4d in [use-cases.md](use-cases.md).

```
git rm --ignore-unmatch ssh/id_ed25519_<hostname>.pub ssh/id_ed25519_signing_<hostname>.pub
rm -rf $CrostiniDir/ssh/<hostname>/ $CrostiniDir/secrets/<hostname>/  # if Crostini
git commit -m "Decommission <hostname>" && git push
```

Also:
- Remove or archive both SSH key items in 1Password (auth and signing)
- Remove or archive secrets items for this hostname in 1Password
- Deregister the old `.pub` from registry settings

## Constraints and Caveats

- **Non-interactive (CI/CD):** pre-provision `~/.ssh/id_ed25519` or populate the mount cache. No passphrase prompts are possible without TTY. `op` CLI with service account token is an option but cannot access the Private vault.
- **NixOS:** credential restore is skipped. SSH keys are system-managed via `nixos-config`.
- **macOS / generic Linux:** no mount cache. Local key or 1Password only.

## Secrets Procedures

### Add, update, remove

See UC-4b in [use-cases.md](use-cases.md).

**Add:** place the file in `~/secrets/`. Name must match `lib.ValidSecretName`: `^[a-zA-Z0-9][a-zA-Z0-9._-]*$`. No dotfiles, no paths, no spaces.

**Update:** edit the file in `~/secrets/`.

**Remove:** delete the file from `~/secrets/`.

**After any change:**
1. Store updated secrets in 1Password (individual items or as a document)
2. On Crostini: re-run `update-env` to refresh the mount cache from `~/secrets/` (the cache stores plaintext copies, not encrypted material)
3. On other machines: retrieve from 1Password on next `update-env` or manually

### Stale cache warning

If `update-env` prints "secrets may be stale": the mount cache is out of sync. Re-run `update-env` to refresh the cache from `~/secrets/`, or retrieve fresh copies from 1Password.

## Recovery Procedures

See UC-4c in [use-cases.md](use-cases.md).

### Key not found

**Symptom:** no local key, no cache, `op` not available or key not in vault.

**Path A** (1Password accessible via app): retrieve manually, place at `~/.ssh/id_ed25519`, `chmod 600`.

**Path B** (key not in 1Password): irrecoverable for this key. Generate new key ([Zero-bootstrap](#zero-bootstrap)).

### Fingerprint mismatch

**Symptom:** "decrypted key doesn't match repo .pub" or "collision" during restore.

**Resolution:**
1. Check 1Password for the authoritative key
2. Compare fingerprints: local vs repo `.pub` vs 1Password
3. If 1Password is authoritative: replace local key from 1Password, update repo `.pub` if needed
4. If local is authoritative: update repo `.pub`, store in 1Password
5. If neither matches registries: determine which key is registered, keep that one, update everything else

### Corrupt secrets cache

**Symptom:** `validateSecretsArchive` rejects with "not a valid tar archive", "invalid member name", or "unexpected file type" errors.

**Path A** (local `~/secrets/` files intact): re-run `update-env` to rebuild cache from local files

**Path B** (local empty, 1Password has secrets): retrieve from 1Password, populate `~/secrets/`

**Path C** (neither local nor 1Password): recreate secret files manually, store in 1Password.

### Cache invalidation

**When:** after key rotation, host decommission, or suspected cache compromise (see [security.md](security.md#chromeos-host--shared-mount-consumer)).

**Procedure:**
```
rm -rf $CrostiniDir/ssh/$HOST/
rm -rf $CrostiniDir/secrets/$HOST/
```

**Effect:** next `update-env` falls through to 1Password retrieval (or prompts for manual restore).

**Caution:** verify that either local files or 1Password has the credentials before invalidating. The cache may be the only plaintext copy after a partial restore failure.

## Known Secrets

Audited from code as of 2026-04-14. Not exhaustive -- different hosts have different subsets. All secrets are optional; missing files degrade gracefully (skipped or warned). Audit command: `grep -rn 'secrets/' update-env scripts/ contexts/`

| File | Format | Used by | Notes |
|------|--------|---------|-------|
| ntfy-topic | plain text (topic string) | scripts/notify-send | phone push notifications; skipped if missing |
| calendar-ics.url | URL | linux-base.nix (vdirsyncer) | work calendar sync |
| stash.key | PAT token | update-env (.envrc scaffold) | Bitbucket Server repo access |
| confluence.key | PAT token | update-env (.envrc scaffold) | Confluence API access |
| fontawesome.key | license key | scripts/mk-urma | Font Awesome pro assets |
| netrc | machine/login/password lines | update-env (symlinked to ~/.netrc) | service credentials for curl/git |

## Maintenance

- **Code is authoritative** for branching behavior. The decision table and workflow descriptions are reading aids.
- **Known secrets table** is manually maintained. Audit with the grep command above when adding consumers.
- **Update triggers:** changes to `sshKeyAction`, restore functions, `encrypt-secrets`, new `~/secrets/` consumers, or changes to the 1Password integration.
- **Security model changes** belong in [security.md](security.md), not here.
