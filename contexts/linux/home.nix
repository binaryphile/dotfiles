{ config, pkgs, dotfiles, ... }:

{
  home.packages = with pkgs; [
    btop
    claude-code
    coreutils
    diff-so-fancy
    dig
    direnv

    gh
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
    signal-desktop
    silver-searcher
    stgit
    tmux
    tree
    vpn-slice
    zip

    # not available on mac
    cliphist
    libnotify
    asciinema
    asciinema-agg
    wl-clipboard
  ];

  home.file.".claude/settings.json".source = "${dotfiles}/claude/settings.json";
  home.sessionVariables = { };
  programs.firefox = {
    enable = true;
    policies = {
      SearchEngines = {
        Default = "DuckDuckGo";
      };
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          private_browsing = true;
        };
        "jid1-MnnxcxisBPnSXQ@jetpack" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
          private_browsing = true;
        };
        "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
          private_browsing = true;
        };
      };
    };
  };

  programs.home-manager.enable = true;
}
