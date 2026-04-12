{ config, pkgs, dotfiles, ... }:

{
  imports = [ ../linux-base.nix ../claude.nix ];

  home.packages = with pkgs; [
    cliphist
    asciinema
    asciinema-agg
    wl-clipboard
  ];
}
