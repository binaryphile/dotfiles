# op-run

Credentialed-tool launcher. Wraps `op run` to resolve secrets from 1Password at invocation time and inject them into the child process's environment via `execve`.

The launcher itself is `scripts/op-run`. It is packaged via `mkScriptBin` in `contexts/linux-base.nix` and ends up on PATH after `home-manager switch`.

Architecture, deployment procedures, failure modes, and operational details are documented in the 1Password-stored canonical doc set (security.md, threat-model.md, secrets-lifecycle.md).
