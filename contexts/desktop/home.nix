{ config, lib, pkgs, dotfiles, gpoc, pangp, ... }:

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

  # vpn-mode toggles gpd.service on/off; vpn-connect dispatches on it.
  # Plain bash, no substitutions (systemctl/sudo from system PATH).
  vpn-mode = mkScriptBin {
    name = "vpn-mode";
    src = ../../scripts/vpn-mode;
    substitutions = {};
  };
in
{
  imports = [ ../linux-base.nix ../claude.nix ../pangp.nix ];

  # NixOS desktop: gpd.service is enabled from system-level
  # configuration.nix via `systemd.packages = [ pkgs.pangp ]`.
  # Leave the home-manager activation hook disabled here.
  services.pangp.enableSystemDaemonOnDebian = false;

  home.username = lib.mkDefault "ted";
  home.homeDirectory = lib.mkDefault "/home/ted";
  home.stateVersion = lib.mkDefault "24.11";

  home.packages = with pkgs; [
    cliphist
    asciinema
    asciinema-agg
    wl-clipboard
  ] ++ [ gpoc vpn-connect vpn-mode ];
}
