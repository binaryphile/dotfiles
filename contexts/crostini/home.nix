{ config, pkgs, ... }:

{
  imports = [ ../linux-base.nix ];

  home.username = "ted";
  home.homeDirectory = "/home/ted";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    ast-grep
    btop
    bubblewrap
    abcde
    asciinema
    asciinema-agg
    wl-clipboard
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
