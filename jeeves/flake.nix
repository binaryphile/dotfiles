{
  description = "Jeeves personal assistant environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs_20
            nodePackages.npm
            chromium
          ];

          shellHook = ''
            echo "Jeeves environment activated"
            echo "Node version: $(node --version)"
            echo "NPM version: $(npm --version)"
            echo "Chromium path: $(which chromium)"
          '';
        };
      });
}