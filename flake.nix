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
      url = "github:yuezk/GlobalProtect-openconnect";
    };

    # Bash dev tool sources -- flake = false gives lockfile pinning without
    # requiring the repos to be flakes. nix flake update <name> bumps pins.
    task-bash-src = { url = "github:binaryphile/task.bash"; flake = false; };
    mk-bash-src   = { url = "github:binaryphile/mk.bash";  flake = false; };
    tesht-src     = { url = "github:binaryphile/tesht";     flake = false; };
  };

  outputs = { self, nixpkgs, home-manager, globalprotect-openconnect
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

    commonSpecialArgs = {
      inherit bashTools;
    };

    # Multi-system outputs for dev shell (used on NixOS, Crostini, macOS).
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
  in {
    homeConfigurations.crostini = home-manager.lib.homeManagerConfiguration {
      pkgs = linuxPkgs;
      modules = [ ./contexts/crostini/home.nix ];
      extraSpecialArgs = commonSpecialArgs;
    };

    # Debian uses crostini config -- both are Debian-based, same package set.
    # Crostini-specific services (tinyproxy, vpn-pac) are harmless on bare Debian.
    homeConfigurations.debian = self.homeConfigurations.crostini;

    homeConfigurations.linux = home-manager.lib.homeManagerConfiguration {
      pkgs = linuxPkgs;
      modules = [ ./contexts/linux/home.nix ];
      extraSpecialArgs = commonSpecialArgs // { inherit gpoc; };
    };

    homeConfigurations.macos = home-manager.lib.homeManagerConfiguration {
      pkgs = macosPkgs;
      modules = [ ./contexts/macos/home.nix ];
      extraSpecialArgs = { bashTools = macosBashTools; };
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
