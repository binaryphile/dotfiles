# bash-tools.nix -- nix derivations for bash dev tool libraries and executables.
#
# Libraries install to $out/lib/ (dependency-only, not on PATH).
# Executables install to $out/bin/ (on PATH via home.packages).
# Nix-packaged scripts that source libs use explicit store paths (pure).
# Unpackaged scripts use env vars (TASK_BASH_LIB, MK_BASH_LIB) set by
# home.sessionVariables in shared.nix.

# When called from flake.nix, sources come from lockfile-pinned flake inputs.
# When called standalone (NixOS path via shared.nix), falls back to
# fetchFromGitHub. Hashes here must match flake.lock pins -- bump both
# together. This fallback goes away when nixos-config consumes flake outputs.
{ pkgs
, task-bash-src ? pkgs.fetchFromGitHub {
    owner = "binaryphile"; repo = "task.bash";
    rev = "fa9bd4a56662652598aa44a0532646fecfa09730";
    hash = "sha256-Y2nS1NBbkdEwCOtQ7qB7Jhnh2cqbP84ipoKjL6jOQ7A=";
  }
, mk-bash-src ? pkgs.fetchFromGitHub {
    owner = "binaryphile"; repo = "mk.bash";
    rev = "8c074a9f831002cb4a4d7294e458743809790aae";
    hash = "sha256-iEpYRtKPYjlQwKprCqYrbosbrxXqoMbS5zz54B1/h2k=";
  }
, tesht-src ? pkgs.fetchFromGitHub {
    owner = "binaryphile"; repo = "tesht";
    rev = "8f5848ee3fe469eb4d3a288bdda7b8c5b09f3465";
    hash = "sha256-Jt/n7S+fxHvL5Gq0U5RbD2pm2o2krTFXQF1kxRJAhpQ=";
  }
}:

{
  taskBash = pkgs.stdenvNoCC.mkDerivation {
    pname = "task-bash";
    version = task-bash-src.shortRev or "unknown";
    src = task-bash-src;
    dontBuild = true;
    installPhase = ''
      install -Dm644 task.bash $out/lib/task.bash
    '';
  };

  mkBash = pkgs.stdenvNoCC.mkDerivation {
    pname = "mk-bash";
    version = mk-bash-src.shortRev or "unknown";
    src = mk-bash-src;
    dontBuild = true;
    installPhase = ''
      install -Dm644 mk.bash $out/lib/mk.bash
      install -Dm755 mk-example $out/bin/mk
      substituteInPlace $out/bin/mk \
        --replace-fail \
          "source ~/.local/lib/mk.bash 2>/dev/null || { echo 'fatal: mk.bash not found' >&2; exit 1; }" \
          "source $out/lib/mk.bash"
    '';
  };

  tesht = pkgs.stdenvNoCC.mkDerivation {
    pname = "tesht";
    version = tesht-src.shortRev or "unknown";
    src = tesht-src;
    dontBuild = true;
    installPhase = ''
      install -Dm755 tesht $out/bin/tesht
    '';
  };
}
