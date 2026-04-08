{ config, pkgs, ... }:

{
  imports = [ ../../shared.nix ];

  home.username = "tlilley";
  home.homeDirectory = "/Users/tlilley";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    btop
    nodePackages.prettier
  ];

  home.file.".claude/settings.json" = {
    source = ../../claude/settings.json;
    force = true;
  };
  home.file.".claude/CLAUDE.md" = {
    source = ../../claude/CLAUDE.md;
    force = true;
  };
}
