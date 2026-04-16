# bash-tools.nix -- nix derivations for bash dev tool libraries and executables.
#
# Libraries install to $out/lib/ (dependency-only, not on PATH).
# Executables install to $out/bin/ (on PATH via home.packages).
# Nix-packaged scripts that source libs use explicit store paths (pure).
# Unpackaged scripts use env vars (TASK_BASH_LIB, MK_BASH_LIB) set by
# home.sessionVariables in shared.nix.

{ pkgs }:

{
  taskBash = pkgs.stdenvNoCC.mkDerivation {
    pname = "task-bash";
    version = "574e475";
    src = pkgs.fetchFromGitHub {
      owner = "binaryphile";
      repo = "task.bash";
      rev = "574e4750531cebfbb1ca79d75640322c1e17aa7e";
      hash = "sha256-7m+/H+DajEjJUtZz1u9WxPSDtnee5lGuL3VSrcFOVqs=";
    };
    dontBuild = true;
    installPhase = ''
      install -Dm644 task.bash $out/lib/task.bash
    '';
  };

  mkBash = pkgs.stdenvNoCC.mkDerivation {
    pname = "mk-bash";
    version = "8c074a9";
    src = pkgs.fetchFromGitHub {
      owner = "binaryphile";
      repo = "mk.bash";
      rev = "8c074a9f831002cb4a4d7294e458743809790aae";
      hash = "sha256-iEpYRtKPYjlQwKprCqYrbosbrxXqoMbS5zz54B1/h2k=";
    };
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
    version = "8f5848e";
    src = pkgs.fetchFromGitHub {
      owner = "binaryphile";
      repo = "tesht";
      rev = "8f5848ee3fe469eb4d3a288bdda7b8c5b09f3465";
      hash = "sha256-Jt/n7S+fxHvL5Gq0U5RbD2pm2o2krTFXQF1kxRJAhpQ=";
    };
    dontBuild = true;
    installPhase = ''
      install -Dm755 tesht $out/bin/tesht
    '';
  };
}
