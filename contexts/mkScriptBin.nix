# mkScriptBin -- build a wrapped script binary from a file in scripts/.
#
# Substitutes `@key@` placeholders with store paths (for binaries invoked
# under sudo, which strips PATH) and wraps the result with runtimeInputs
# on PATH (for binaries invoked normally).
#
# Used by linux-base.nix (notify-send-bridge) and crostini/home.nix
# (vpn-connect).

{ pkgs }:

{ name, src, substitutions ? {}, runtimeInputs ? [] }:

let
  lib = pkgs.lib;
  subFlags = lib.concatStringsSep " \\\n        "
    (lib.mapAttrsToList (k: v: "--replace-fail '@${k}@' '${v}'") substitutions);
in pkgs.stdenv.mkDerivation {
  inherit name src;
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  installPhase = ''
    install -Dm755 $src $out/bin/${name}
    ${lib.optionalString (substitutions != {}) ''
      substituteInPlace $out/bin/${name} \
        ${subFlags}
    ''}
    wrapProgram $out/bin/${name} \
      --prefix PATH : ${lib.makeBinPath runtimeInputs}
  '';
}
