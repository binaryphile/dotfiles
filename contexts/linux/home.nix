{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    claude-code
    coreutils
    diff-so-fancy
    direnv
    firefox
    git
    gp-saml-gui
    highlight
    htop
    jira-cli-go
    jq
    mnemonicode
    ncdu
    neovim
    nodePackages.prettier
    openconnect
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
    cliphist
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
