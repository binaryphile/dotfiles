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

### As a library

Source it to get individual task functions. Set `ProjectDirW` before calling them.

```bash
source ~/dotfiles/scripts/scaffold

ProjectDirW=~/projects/myapp
scaffold.NixWrapperTask          # install/update bin/nix-wrapper
scaffold.EnvrcTask               # install/update .envrc
# scaffold.FlakeNixTask          # only for new projects; overwrites existing flake.nix

# Add tool symlinks
each task.Ln <<'END'
  nix-wrapper ~/projects/myapp/bin/go
  nix-wrapper ~/projects/myapp/bin/node
END
```

This is how update-env uses scaffold for the era project -- it calls `scaffold.NixWrapperTask` and `scaffold.EnvrcTask` but skips `scaffold.FlakeNixTask` because era has its own flake with custom shellHook and many packages.

## Public API

| Function | Purpose |
|----------|---------|
| `scaffold.MkdirTask` | Create a directory (idempotent) |
| `scaffold.NixWrapperTask` | Install/update `bin/nix-wrapper` |
| `scaffold.EnvrcTask` | Install/update `.envrc` |
| `scaffold.FlakeNixTask` | Install/update `flake.nix` (destructive -- overwrites) |
| `scaffold.NixWrapperContent` | Emit nix-wrapper script content to stdout |
| `scaffold.EnvrcContent` | Emit .envrc content to stdout |
| `scaffold.FlakeNixContent` | Emit flake.nix content to stdout (uses `PackagesW`) |

## Globals

| Name | Purpose |
|------|---------|
| `ProjectDirW` | Target project directory. Set before calling task functions. |
| `PackagesW` | Array of nix package names for `scaffold.FlakeNixContent`. Set before calling `scaffold.FlakeNixTask`. |

## How nix-wrapper works

When called as (say) `go build ./...`:

1. Resolves its own name from `$0` (e.g., `go`)
2. Checks if already inside `nix develop` (`IN_NIX_SHELL=impure`)
3. If yes, or no `flake.nix` found: runs the real `go` directly
4. If no: runs `nix develop -c go build ./...`

This means the first invocation outside `nix develop` is slow (nix evaluation), but subsequent calls in the same session are fast if direnv has already activated.
