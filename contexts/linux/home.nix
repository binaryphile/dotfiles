{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    claude-code
    coreutils
    diff-so-fancy
    direnv
    firefox
    git
    globalprotect-openconnect
    highlight
    htop
    jira-cli-go
    jq
    mnemonicode
    ncdu
    neovim
    nodePackages.prettier
    obsidian
    pandoc
    ranger
    rsync
    scc
    silver-searcher
    stgit
    tmux
    tree
    zip

    # not available on mac
    libnotify
    asciinema
    asciinema-agg
    kcov
    wl-clipboard
  ];

  home.file = { };
  home.sessionVariables = { };
  programs.home-manager.enable = true;
}
