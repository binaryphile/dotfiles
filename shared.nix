{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    claude-code
    coreutils
    diff-so-fancy

    gh
    git
    highlight
    htop
    jira-cli-go
    jq
    keychain
    mnemonicode
    ncdu
    neovim
    obsidian
    openconnect
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
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less";
    CFGDIR = "$HOME/.config";
    SECRETS = "$HOME/secrets";
    XDG_CONFIG_HOME = "$HOME/.config";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.local/lib"
    "/usr/local/bin"
  ];

  programs.direnv = {
    enable = true;
    enableBashIntegration = false;
    nix-direnv.enable = true;
  };

  programs.bat = {
    enable = true;
    config = {
      style = "numbers";
    };
  };

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
