# Secrets Lifecycle

Operational companion to [design.md](design.md). SSH keys and secrets are encrypted with [age](https://github.com/FiloSottile/age) (a file encryption tool) and stored in the repo. design.md covers the three-tier restore model, trust model, archive validation, and hostname identity ([SSH Key Bootstrap](design.md#ssh-key-bootstrap-uc-4), [Secrets Bundling](design.md#secrets-bundling-uc-4)). This doc covers operator workflows: bootstrap, rotation, recovery, decommission.

**When to read which doc:**

| Question | Doc |
|----------|-----|
| How does the three-tier restore work? | [design.md](design.md#ssh-key-bootstrap-uc-4) |
| Why is the mount cache trusted? | [design.md](design.md#ssh-key-bootstrap-uc-4) (trust model) |
| How do I rotate my SSH key? | This doc ([Key rotation](#key-rotation)) |
| I hit a fingerprint mismatch | This doc ([Fingerprint mismatch](#fingerprint-mismatch)) |
| How do I add a new secret? | This doc ([Add, update, remove](#add-update-remove)) |
| How does archive validation work? | [design.md](design.md#secrets-bundling-uc-4) |

For how `update-env` decides which restore action to take, see the [decision table](design.md#ssh-key-bootstrap-uc-4) and `SshKeyStatus` values in design.md.

## SSH Key Workflows

**Hostname:** procedures below use `$HOST`. Set it before running any procedure:
```
HOST=$(cd ~/dotfiles && source scripts/lib.bash && lib.MachineHostname)
```
On Crostini this reads `$CrostiniDir/hostname`, not the system hostname. Always use this rather than bare `hostname`.

### Zero-bootstrap

Path: Tier 4 -> `generate`.

1. Run `update-env`
2. `sshKeyGenerate` prompts for SSH passphrase, creates `~/.ssh/id_ed25519`
3. If age available: prompts for age passphrase, encrypts to `ssh/id_ed25519_<hostname>.{age,pub}`
4. If on Crostini: caches to `$CrostiniDir/ssh/<hostname>/`
5. `authPreflight` reports "key not registered" for all providers

**Post-steps (manual):**
- `cd ~/dotfiles && git add ssh/id_ed25519_<hostname>.{age,pub} && git commit && git push`
- Register `~/.ssh/id_ed25519.pub` with GitHub, Codeberg, Bitbucket settings
- If age was unavailable: `SshKeyStatus=generated_local_only` -- key will be lost on wipe. Install age, then re-run `update-env` to capture.

**Machine replacement** is the same workflow. New hostname = no repo state for that hostname. Old hostname's .age/.pub remain in repo until decommissioned ([Cleanup and decommission](#cleanup-and-decommission)).

### Normal restore

Two Crostini sub-scenarios:

**Powerwash** (ChromeOS reset, Crostini container recreated):
- Mount cache at `$CrostiniDir/ssh/<hostname>/` survives (lives on ChromeOS MyFiles)
- Path: Tier 2 -> `restore_from_cache` -- no passphrase prompt

**Container reset** (Crostini container deleted and recreated):
- Mount cache lost
- Path: Tier 3 -> `restore_from_age` -- prompts for age passphrase
- After restore: cache is repopulated automatically

Both paths validate the restored key's fingerprint against the repo .pub sidecar.

### Key rotation

Manual procedure. Ordering matters -- do not destroy the only copy.

1. Verify current key is backed up: `ls ~/dotfiles/ssh/id_ed25519_$HOST.age`. If missing, **stop** -- you have no repo backup. First capture the current key: `rm ~/dotfiles/ssh/id_ed25519_$HOST.{age,pub} 2>/dev/null`, then run `update-env` to trigger `capture_to_repo`, commit, and restart this procedure.
2. Delete local key: `rm ~/.ssh/id_ed25519{,.pub}`
3. Delete repo key: `rm ~/dotfiles/ssh/id_ed25519_$HOST.{age,pub}`
4. Clear cache (Crostini): `rm -rf $CrostiniDir/ssh/$HOST/`
5. Run `update-env` -- hits Tier 4 -> `generate`
6. Commit new .age/.pub: `cd ~/dotfiles && git add ssh/ && git commit && git push`
7. Register new .pub with forges, deregister old .pub

No automated rotation command exists. This is a known gap.

### Collision recovery

**Symptom:** `update-env` prints "collision: local key fingerprint does not match repo"

**Cause:** `~/.ssh/id_ed25519` and `ssh/id_ed25519_<hostname>.pub` have different fingerprints. Typically happens if a key was generated outside `update-env`.

**Resolution:**
1. Compare fingerprints: `ssh-keygen -lf ~/.ssh/id_ed25519.pub` vs `ssh-keygen -lf ~/dotfiles/ssh/id_ed25519_$HOST.pub`
2. Check forge registrations (GitHub/Codeberg/Bitbucket SSH key settings) to determine which fingerprint is registered
3. If local is authoritative: `rm ~/dotfiles/ssh/id_ed25519_$HOST.{age,pub}`, re-run `update-env` (captures local to repo)
4. If repo is authoritative: `rm ~/.ssh/id_ed25519{,.pub}`, re-run `update-env` (restores from repo)
5. If neither is registered: either key works -- keep local (simpler), then register it with forges
6. If both are registered on different forges: pick one, deregister the other from its forge, then follow step 3 or 4
7. If you cannot determine authority: **stop**. Do not delete either key. Back up both, then consult git log for which was committed most recently.

### Cleanup and decommission

Remove a retired machine's key material:

```
git rm --ignore-unmatch ssh/id_ed25519_<hostname>.{age,pub}
git rm --ignore-unmatch secrets/<hostname>.tar.age
rm -rf $CrostiniDir/ssh/<hostname>/ $CrostiniDir/secrets/<hostname>/  # if Crostini
git commit -m "Decommission <hostname>" && git push
```

Also deregister the old .pub from forge settings.

## Constraints and Caveats

- **Non-interactive (CI/CD):** pre-provision `~/.ssh/id_ed25519` or populate the mount cache. No passphrase prompts are possible without TTY.
- **NixOS:** credential restore is skipped. SSH keys are system-managed via `nixos-config`.
- **macOS / generic Linux:** no mount cache. Only local key and age decrypt are available.

## Secrets Bundle Procedures

For snapshot semantics, restore behavior, and archive validation, see [design.md Secrets Bundling](design.md#secrets-bundling-uc-4). Key point: restore never overwrites existing local secrets; always re-encrypt and commit after adding a secret to ensure it survives across machines.

### Add, update, remove

**Add:** place the file in `~/secrets/`. Name must match `lib.ValidSecretName`: `^[a-zA-Z0-9][a-zA-Z0-9._-]*$`. No dotfiles, no paths, no spaces.

**Update:** edit the file in `~/secrets/`.

**Remove:** delete the file from `~/secrets/`.

**After any change:** re-encrypt and commit:
```
scripts/encrypt-secrets
cd ~/dotfiles && git add secrets/ && git commit && git push
```

Old bundles persist in git history (encrypted). No automated history rewrite -- the ciphertext is age-encrypted so history exposure is low-risk.

### Stale bundle warning

If `update-env` prints "secrets may be stale": re-encrypt local (`scripts/encrypt-secrets`) if local is authoritative, or restore from repo (`update-env -2`) if repo is authoritative. A stale warning after re-encryption is expected (age uses a random salt); commit to resolve.

## Recovery Procedures

### Age passphrase forgotten

**Symptom:** age decrypt prompts repeatedly; all attempts fail.

**Check first:** does a plaintext copy exist?
- Local key: `ls ~/.ssh/id_ed25519`
- Cache: `ls $CrostiniDir/ssh/$HOST/id_ed25519`
- Local secrets: `ls ~/secrets/`

**Path A** (plaintext exists): re-encrypt with a new passphrase.
- Secrets: `scripts/encrypt-secrets` (re-encrypts from `~/secrets/`, prompts for new passphrase)
- SSH key re-encryption (full procedure):
  ```
  cd ~/dotfiles
  HOST=$(source scripts/lib.bash && lib.MachineHostname)
  tmp=$(mktemp -d) && chmod 700 "$tmp"
  trap 'rm -rf "$tmp"' EXIT INT TERM
  cp ~/.ssh/id_ed25519 "$tmp/id_ed25519" && chmod 600 "$tmp/id_ed25519"
  cp ~/.ssh/id_ed25519.pub "$tmp/id_ed25519.pub"
  agetmp=$(mktemp ssh/id_ed25519_${HOST}.age.XXXXXX)
  tar cf - -C "$tmp" . | age -p -o "$agetmp"
  test -s "$agetmp" || { echo "encryption failed"; rm -f "$agetmp"; exit 1; }
  mv "$agetmp" ssh/id_ed25519_${HOST}.age
  cp ~/.ssh/id_ed25519.pub ssh/id_ed25519_${HOST}.pub
  git add ssh/id_ed25519_${HOST}.{age,pub} && git commit && git push
  ```

**Path B** (only .age remains): irrecoverable. Generate a new SSH key ([Zero-bootstrap](#zero-bootstrap)), recreate secrets manually.

**Caution:** do NOT clear the mount cache before checking if it holds the only plaintext copy.

### Fingerprint mismatch

**Symptom:** "decrypted key doesn't match repo .pub" during age restore.

**Cause:** `.pub` sidecar was replaced without re-encrypting the private key, or the `.age` was re-encrypted with a different key pair.

**Path A** (private key accessible locally or in cache):
1. Regenerate .pub from private: `ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub`
2. Update repo sidecar: `cp ~/.ssh/id_ed25519.pub ~/dotfiles/ssh/id_ed25519_$HOST.pub`
3. Re-encrypt the pair using the "SSH key re-encryption" procedure in [Age passphrase forgotten](#age-passphrase-forgotten), Path A

**Path B** (can decrypt .age but local key is absent or suspect):
1. Extract the bundle: `age --decrypt ssh/id_ed25519_$HOST.age | tar xf - -C /tmp/sshfix/`
2. Compare fingerprints to determine which half is correct:
   - Bundled: `ssh-keygen -lf /tmp/sshfix/id_ed25519.pub`
   - Repo sidecar: `ssh-keygen -lf ~/dotfiles/ssh/id_ed25519_$HOST.pub`
   - Forge-registered: check GitHub/Codeberg/Bitbucket SSH key settings
3. If the bundled private key is correct, regenerate .pub from it: `ssh-keygen -y -f /tmp/sshfix/id_ed25519 > /tmp/sshfix/id_ed25519.pub`
4. Install: `cp /tmp/sshfix/id_ed25519 ~/.ssh/ && chmod 600 ~/.ssh/id_ed25519 && cp /tmp/sshfix/id_ed25519.pub ~/.ssh/`
5. Re-encrypt per [Age passphrase forgotten](#age-passphrase-forgotten), Path A (SSH key re-encryption)
6. Clean up: `rm -rf /tmp/sshfix/`

**Path C** (cannot decrypt, no local/cache): regenerate ([Zero-bootstrap](#zero-bootstrap)).

### Corrupt secrets archive

**Symptom:** `validateSecretsArchive` rejects with "not a valid tar archive", "invalid member name", or "unexpected file type" errors.

**Path A** (local `~/secrets/` files intact): `scripts/encrypt-secrets && git add secrets/ && git commit`

**Path B** (local empty, cache exists): `rm ~/secrets/.bundle-hash`, run `update-env -2` to restore from cache

**Path C** (neither local nor cache): recreate secret files manually, re-encrypt.

### Cache invalidation

**When:** after key rotation, host decommission, or suspected cache compromise.

**Procedure:**
```
rm -rf $CrostiniDir/ssh/$HOST/
rm -rf $CrostiniDir/secrets/$HOST/
```

**Effect:** next `update-env` falls through to Tier 3 (age decrypt with passphrase prompt).

**Caution:** verify that either local files or repo .age exist before invalidating. The cache may be the only plaintext copy after a partial restore failure.

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

The age passphrase is not stored in `~/secrets/`. It exists only in the operator's memory or password manager. There is no escrow or recovery mechanism for a forgotten passphrase (see [Age passphrase forgotten](#age-passphrase-forgotten)).

## Maintenance

- **Code is authoritative** for branching behavior. The decision table and workflow descriptions are reading aids.
- **Known secrets table** is manually maintained. Audit with the grep command above when adding consumers.
- **Update triggers:** changes to `sshKeyAction`, restore functions, `encrypt-secrets`, or new `~/secrets/` consumers.
