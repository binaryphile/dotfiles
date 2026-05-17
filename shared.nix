{ config, pkgs, lib, bashTools ? null, shellcheckFork ? null, shellcheckPlugin ? null, ... }:

let
  effectiveBashTools = if bashTools != null then bashTools else import ./bash-tools.nix { inherit pkgs; };

  # Fallback: any importer that doesn't pass shellcheckFork gets stock pkgs.shellcheck.
  # Silent downgrade — every configured importer SHOULD pass it explicitly via
  # extraSpecialArgs in flake.nix; criterion #5 (SC9001+ identity probe) catches
  # the configured path, but unconfigured ad-hoc importers won't be flagged.
  effectiveShellcheck = if shellcheckFork != null then shellcheckFork else pkgs.shellcheck;
in {
  home.packages = (with pkgs; [
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
    uv
    vpn-slice
    zip
  ]) ++ [ effectiveShellcheck effectiveBashTools.mkBash effectiveBashTools.tesht ];

  # Deploy the shellcheck-convention-plugin .so into the fork's XDG discovery
  # path. lib.mkIf guards against unconfigured importers (matches the
  # effectiveShellcheck fallback above).
  xdg.dataFile."shellcheck/plugins/libconvention-checks.so" = lib.mkIf (shellcheckPlugin != null) {
    source = "${shellcheckPlugin}/lib/shellcheck/plugins/libconvention-checks.so";
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less";
    SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    CFGDIR = "$HOME/.config";
    SECRETS = "$HOME/secrets";
    XDG_CONFIG_HOME = "$HOME/.config";
    TASK_BASH_LIB = "${effectiveBashTools.taskBash}/lib/task.bash";
    MK_BASH_LIB = "${effectiveBashTools.mkBash}/lib/mk.bash";
    # Align all era telemetry consumers on one path: era-serve's slog
    # appender, era-soak's drip JSONL, and `./mk grafana-up`'s Promtail
    # tailer all read this env var. Mismatch yields silently-empty Loki
    # (UC-27). era-soak.service hardcodes the same path; era-serve.service
    # currently does not — tracked upstream as tasks.era #5021.
    ERA_STATE_DIR = "$HOME/.local/share/era-telemetry";
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
    configPath = ".config/mozilla/firefox";
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
