# op-run

Credentialed-tool launcher. Wraps `op run` to resolve secrets from 1Password at invocation time and inject them into the child process's environment via `execve`.

The launcher itself is `scripts/op-run`. It is packaged via `mkScriptBin` in `contexts/linux-base.nix` and ends up on PATH after `home-manager switch`.

## Integrity check (UC-11)

`op-run/checksums` carries committed SHA-256 hashes of `scripts/op-run`, `op-run/projects.bash`, and every `op-run/machines/*.allow`. Two enforcement paths use the file:

- **At interactive-shell init**, `OpRunIntegrityCheck` (`bash/lib/op-run-integrity.bash`, called from `bash/init.bash`) runs `sha256sum --check op-run/checksums` and verifies that `command -v op-run` resolves under `/nix/store/`. Mismatches emit a single warning to stderr; shell startup is not blocked (rationale in `~/projects/jeeves/security/threat-model.md`).
- **At commit time**, `.githooks/pre-commit` refuses commits when a hashed file is staged without a matching `op-run/checksums` update.

When the launcher, registry, or an allowlist is edited deliberately, regenerate with:

```sh
bash scripts/op-run-checksum-update
git add op-run/checksums
```

Verify against current sources at any time:

```sh
( cd ~/dotfiles && sha256sum --check op-run/checksums )
```

Bypass (for the rare cycle that needs it): `git commit --no-verify`.

Architecture, deployment procedures, failure modes, and operational details are documented in the canonical doc set in ~/projects/jeeves/security/ (security.md, threat-model.md, secrets-lifecycle.md).
