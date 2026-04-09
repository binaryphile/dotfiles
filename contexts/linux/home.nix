{ config, pkgs, dotfiles, ... }:

{
  imports = [ ../linux-base.nix ];

  home.packages = with pkgs; [
    cliphist
    asciinema
    asciinema-agg
    wl-clipboard
  ];

  home.file.".claude/settings.json" = {
    source = "${dotfiles}/claude/settings.json";
    force = true;
  };
  home.file.".claude/CLAUDE.md" = {
    source = "${dotfiles}/claude/CLAUDE.md";
    force = true;
  };
}
