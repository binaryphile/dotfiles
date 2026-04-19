{
  description = "Ted's dotfiles -- home-manager configs and bash dev tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Bash dev tool sources -- flake = false gives lockfile pinning without
    # requiring the repos to be flakes. nix flake update <name> bumps pins.
    task-bash-src = { url = "github:binaryphile/task.bash"; flake = false; };
    mk-bash-src   = { url = "github:binaryphile/mk.bash";  flake = false; };
    tesht-src     = { url = "github:binaryphile/tesht";     flake = false; };
  };

  outputs = { self, nixpkgs, home-manager
            , task-bash-src, mk-bash-src, tesht-src, ... }:
  let
    # Crostini home-manager configs are x86_64-linux only.
    hmSystem = "x86_64-linux";
    hmPkgs = import nixpkgs {
      system = hmSystem;
      config.allowUnfree = true;
    };

    bashTools = import ./bash-tools.nix {
      pkgs = hmPkgs;
      inherit task-bash-src mk-bash-src tesht-src;
    };

    commonSpecialArgs = {
      inherit bashTools;
    };

    # Multi-system outputs for dev shell (used on NixOS, Crostini, macOS).
    supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
  in {
    homeConfigurations.crostini = home-manager.lib.homeManagerConfiguration {
      pkgs = hmPkgs;
      modules = [ ./contexts/crostini/home.nix ];
      extraSpecialArgs = commonSpecialArgs;
    };

    # Debian uses crostini config -- both are Debian-based, same package set.
    # Crostini-specific services (tinyproxy, vpn-pac) are harmless on bare Debian.
    homeConfigurations.debian = self.homeConfigurations.crostini;

    # Deprecated alias -- remove after confirming no downstream consumers.
    homeConfigurations.penguin = self.homeConfigurations.crostini;

    packages.${hmSystem} = {
      inherit (bashTools) taskBash mkBash tesht;
      home-manager = home-manager.packages.${hmSystem}.default;
    };

    devShells = forEachSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        default = pkgs.mkShellNoCC {
          buildInputs = with pkgs; [
            coreutils git jq scc
          ] ++ (if pkgs.stdenv.isLinux then [ kcov vscode ] else [ code-cursor ]);
          shellHook = ''
            export IN_NIX_DEVELOP=1
            echo "Welcome to the development shell!"
          '';
        };
      }
    );
  };
}
