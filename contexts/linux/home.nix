{ config, pkgs, dotfiles, gpoc, ... }:

let
  mkScriptBin = import ../mkScriptBin.nix { inherit pkgs; };

  vpn-connect = mkScriptBin {
    name = "vpn-connect";
    src = ../../scripts/vpn-connect;
    substitutions = {
      "vpn-slice" = "${pkgs.vpn-slice}/bin/vpn-slice";
      "gpclient" = "${gpoc}/bin/gpclient";
    };
    runtimeInputs = [ gpoc ];
  };
in
{
  imports = [ ../linux-base.nix ../claude.nix ];

  home.packages = with pkgs; [
    cliphist
    asciinema
    asciinema-agg
    wl-clipboard
  ] ++ [ gpoc vpn-connect ];
}
