{
  description = "Ted's dotfiles -- home-manager configs and bash dev tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # GlobalProtect VPN client (yuezk Rust rewrite). Used by linux/home.nix
    # for vpn-connect wrapper. Crostini uses apt-installed gpoc instead.
    globalprotect-openconnect = {
      # See ~/nixos-config/flake.nix for why this pins past v2.6.3 to
      # main HEAD: the tagged flake's prebuilt-asset hashes don't match
      # the floating `snapshot` release URLs they reference.
      url = "github:yuezk/GlobalProtect-openconnect/49f410e6";
    };

    # ShellCheck fork (binaryphile/shellcheck) with dynamic plugin loading
    # via $XDG_DATA_HOME/shellcheck/plugins/. Replaces nixpkgs shellcheck
    # so the convention-plugin's .so (next input) is actually loadable.
    # Uses its own pinned nixpkgs (NO follows) -- the Haskell build relies on
    # a specific GHC version; following dotfiles' nixpkgs breaks compilation.
    shellcheck-fork = {
      url = "github:binaryphile/shellcheck";
    };

    # IFS/noglob convention plugin (SC9001-SC9006) for the fork above.
    # Builds libconvention-checks.so under $out/lib/shellcheck/plugins/;
    # deployed via xdg.dataFile in shared.nix to the fork's discovery path.
    # Uses its own pinned nixpkgs (NO follows) -- same GHC pinning reason.
    shellcheck-convention-plugin = {
      url = "github:binaryphile/shellcheck-convention-plugin";
    };

    # Bash dev tool sources -- flake = false gives lockfile pinning without
    # requiring the repos to be flakes. nix flake update <name> bumps pins.
    task-bash-src = { url = "github:binaryphile/task.bash"; flake = false; };
    mk-bash-src   = { url = "github:binaryphile/mk.bash";  flake = false; };
    tesht-src     = { url = "github:binaryphile/tesht";     flake = false; };
  };

  outputs = { self, nixpkgs, home-manager, globalprotect-openconnect
            , shellcheck-fork, shellcheck-convention-plugin
            , task-bash-src, mk-bash-src, tesht-src, ... }:
  let
    linuxSystem = "x86_64-linux";
    macosSystem = "aarch64-darwin";

    linuxPkgs = import nixpkgs {
      system = linuxSystem;
      config.allowUnfree = true;
    };

    macosPkgs = import nixpkgs {
      system = macosSystem;
      config.allowUnfree = true;
    };

    bashTools = import ./bash-tools.nix {
      pkgs = linuxPkgs;
      inherit task-bash-src mk-bash-src tesht-src;
    };

    macosBashTools = import ./bash-tools.nix {
      pkgs = macosPkgs;
      inherit task-bash-src mk-bash-src tesht-src;
    };

    gpoc = globalprotect-openconnect.packages.${linuxSystem}.default;

    # PAN GlobalProtect (proprietary) -- workaround client for the gpoc
    # CVE-2026-0257 breakage (see pangp.nix header for context).
    #
    # Resolved via requireFile against the tarball's content hash, not by
    # absolute filesystem path. Pure-eval safe: nix-store searches by
    # content address, so no --impure flag needed at the call site.
    #
    # First-time bootstrap on a new machine:
    #   1. Download PanGPLinux-<ver>.tgz from PAN's customer portal
    #      (proprietary; not redistributable, so cannot be fetchurl'd).
    #   2. Add to the nix-store with its content hash:
    #        nix-store --add-fixed sha256 PanGPLinux-6.3.3-c31.tgz
    #   3. Re-run home-manager switch -- no --impure needed.
    #
    # If the file is missing, requireFile fails at evaluation with an
    # actionable message rather than producing a silently broken pangp.
    pangp = import ./pangp.nix {
      pkgs = linuxPkgs;
      src = linuxPkgs.requireFile {
        name = "PanGPLinux-6.3.3-c31.tgz";
        sha256 = "0z4n73hx27717i8p92r4ad2xbbi1l8w5nfsx20yqbx3irwhyvdba";
        message = ''
          PanGPLinux-6.3.3-c31.tgz is not in the nix-store.
          Download from PAN's customer portal, then:
            nix-store --add-fixed sha256 PanGPLinux-6.3.3-c31.tgz
          and re-run.
        '';
      };
    };

    commonSpecialArgs = {
      inherit bashTools;
      shellcheckFork   = shellcheck-fork.packages.${linuxSystem}.default;
      shellcheckPlugin = shellcheck-convention-plugin.packages.${linuxSystem}.default;
    };

    # Multi-system outputs for dev shell (used on NixOS, Crostini, macOS).
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
  in {
    homeConfigurations.crostini = home-manager.lib.homeManagerConfiguration {
      pkgs = linuxPkgs;
      modules = [ ./contexts/crostini/home.nix ];
      extraSpecialArgs = commonSpecialArgs // { inherit pangp; contextName = "crostini"; };
    };

    # Debian uses crostini config -- both are Debian-based, same package set.
    # Crostini-specific services (tinyproxy, vpn-pac) are harmless on bare Debian.
    homeConfigurations.debian = self.homeConfigurations.crostini;

    homeConfigurations.desktop = home-manager.lib.homeManagerConfiguration {
      pkgs = linuxPkgs;
      modules = [ ./contexts/desktop/home.nix ];
      extraSpecialArgs = commonSpecialArgs // { inherit gpoc pangp; contextName = "desktop"; };
    };

    homeConfigurations.macos = home-manager.lib.homeManagerConfiguration {
      pkgs = macosPkgs;
      modules = [ ./contexts/macos/home.nix ];
      extraSpecialArgs = {
        bashTools        = macosBashTools;
        shellcheckFork   = shellcheck-fork.packages.${macosSystem}.default;
        shellcheckPlugin = shellcheck-convention-plugin.packages.${macosSystem}.default;
      };
    };

    packages.${linuxSystem} = {
      inherit (bashTools) taskBash mkBash tesht;
      home-manager = home-manager.packages.${linuxSystem}.default;
    };

    devShells = forEachSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        devBashTools = import ./bash-tools.nix {
          inherit pkgs task-bash-src mk-bash-src tesht-src;
        };
      in {
        default = pkgs.mkShellNoCC {
          buildInputs = with pkgs; [
            coreutils git jq scc wl-clipboard
          ] ++ (if pkgs.stdenv.isLinux then [ kcov ] else [])
            ++ [ devBashTools.tesht devBashTools.mkBash ];
          shellHook = ''
            export IN_NIX_DEVELOP=1
            echo "Welcome to the development shell!"
          '';
        };
      }
    );
  };
}
