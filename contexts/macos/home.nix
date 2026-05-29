{ config, pkgs, ... }:

{
  imports = [ ../../shared.nix ];

  home.username = "tlilley";
  home.homeDirectory = "/Users/tlilley";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    nodePackages.prettier
    tmux  # plain tmux -- macOS has no headless tmux sessions needing panel
  ];

  home.file.".claude/settings.json" = {
    source = ../../claude/settings.json;
    force = true;
  };
  home.file.".claude/CLAUDE.md" = {
    source = ../../claude/CLAUDE.md;
    force = true;
  };

  # gitconfig + gitignore_global: macOS doesn't import contexts/linux-base.nix
  # (which Linux uses to deploy these via ctxDir-relative paths), so declare
  # them explicitly here. Source paths are nix-relative-to-this-file:
  #   ./gitconfig             -> contexts/macos/gitconfig (this dir's gitconfig)
  #   ../../gitignore_global  -> dotfiles/gitignore_global (repo root)
  # Both files are shared across all contexts; macOS-specific deltas (e.g.,
  # hooksPath = /Users/tlilley/dotfiles/githooks, excludesfile pointing at
  # the deployed gitignore_global) live in contexts/macos/gitconfig directly.
  # UC-14 binary-commit guard depends on this deployment to activate on macOS.
  home.file.".gitconfig".source = ./gitconfig;
  home.file.".gitignore_global".source = ../../gitignore_global;
}
