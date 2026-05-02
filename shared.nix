{ config, pkgs, bashTools ? null, ... }:

let
  effectiveBashTools = if bashTools != null then bashTools else import ./bash-tools.nix { inherit pkgs; };
in {
  home.packages = with pkgs; [
    bottom
    claude-code
    coreutils
    diff-so-fancy
    dig

    gh
    git
    highlight
    htop
    jira-cli-go
    _1password-cli
    jq
    liquidprompt
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
    tree
    vpn-slice
    zip
  ] ++ [ effectiveBashTools.mkBash effectiveBashTools.tesht ];

  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less";
    SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    CFGDIR = "$HOME/.config";
    SECRETS = "$HOME/secrets";
    XDG_CONFIG_HOME = "$HOME/.config";
    TASK_BASH_LIB = "${effectiveBashTools.taskBash}/lib/task.bash";
    MK_BASH_LIB = "${effectiveBashTools.mkBash}/lib/mk.bash";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
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
      EncryptedMediaExtensions = {
        Enabled = false;
        Locked = true;
      };
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
