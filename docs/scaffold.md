# scaffold

Creates and maintains nix-wrapper infrastructure for projects that use nix flakes for their dev environment.

## What it does

Given a project directory, scaffold ensures three things exist and are up to date:

1. **`bin/nix-wrapper`** -- a generic wrapper that transparently runs commands inside `nix develop`. Symlink any nix-provided tool to it (e.g., `ln -s nix-wrapper go`) and the tool works outside `nix develop` without the user typing `nix develop -c`.

2. **`.envrc`** -- puts `bin/` on PATH so nix-wrapped tools are available from the project root.

3. **`flake.nix`** -- a minimal nix flake with the requested packages (only when creating a new project; existing flakes with custom config are left alone by consumers).

## Usage

### As a standalone script

```bash
scaffold <project-dir> [packages...]
# Default packages: bash coreutils git
scaffold ~/projects/myapp go nodejs
```

Creates the project directory structure if needed, installs nix-wrapper, .envrc, flake.nix, and symlinks `bin/claude` to nix-wrapper.

### Sourced by update-env

Source it to get individual task functions. Set `ProjectDir` before calling them.

```bash
source ~/dotfiles/scripts/scaffold

ProjectDir=~/projects/myapp
NixWrapperTask          # install/update bin/nix-wrapper
EnvrcTask               # install/update .envrc
# FlakeNixTask          # only for new projects; overwrites existing flake.nix

# Add tool symlinks
each task.Ln <<'END'
  nix-wrapper ~/projects/myapp/bin/go
  nix-wrapper ~/projects/myapp/bin/node
END
```

This is how update-env uses scaffold for the era project -- it calls `NixWrapperTask` and `EnvrcTask` but skips `FlakeNixTask` because era has its own flake with custom shellHook and many packages.

## Public API

| Function | Purpose |
|----------|---------|
| `MkdirTask` | Create a directory (idempotent) |
| `NixWrapperTask` | Install/update `bin/nix-wrapper` (skips if git-tracked) |
| `EnvrcTask` | Install/update `.envrc` |
| `FlakeNixTask` | Install/update `flake.nix` (destructive -- overwrites) |
| `NixWrapperContent` | Emit nix-wrapper script content to stdout |
| `EnvrcContent` | Emit .envrc content to stdout |
| `FlakeNixContent` | Emit flake.nix content to stdout (uses `Packages`) |

## Globals

| Name | Purpose |
|------|---------|
| `ProjectDir` | Target project directory. Set before calling task functions. |
| `Packages` | Array of nix package names for `FlakeNixContent`. Set before calling `FlakeNixTask`. |

## NixWrapperTask behavior

`NixWrapperTask` checks `git ls-files --error-unmatch bin/nix-wrapper` before installing. If the file is already git-tracked (committed to the repo), the task reports "ok" and leaves the file alone -- the repo manages it. If not git-tracked (workgroup repos where `bin/` is git-excluded), the task installs from the template and keeps it up to date.

This means: for personal repos, `bin/nix-wrapper` is committed to git and distributed with the repo. For workgroup repos (urma, dal, pepin, cloud-services), `bin/nix-wrapper` is scaffold-managed and not pushed upstream.

## How nix-wrapper works

When called as (say) `go build ./...`:

1. Resolves its own name from `$0` (e.g., `go`)
2. Checks if already inside `nix develop` (`IN_NIX_SHELL=impure`)
3. If yes, or no `flake.nix` found: runs the real `go` directly
4. If no: runs `nix develop -c go build ./...`

This means the first invocation outside `nix develop` is slow (nix evaluation), but subsequent calls in the same session are fast if direnv has already activated.
