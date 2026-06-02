{ config, pkgs, lib, bashTools ? null, shellcheckFork ? null, shellcheckPlugin ? null, ... }:

let
  effectiveBashTools = if bashTools != null then bashTools else import ./bash-tools.nix { inherit pkgs; };

  # Fallback: any importer that doesn't pass shellcheckFork gets stock pkgs.shellcheck.
  # Silent downgrade -- every configured importer SHOULD pass it explicitly via
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

  # Global shellcheck config — the user-wide bash style conventions Ted
  # adopts across personal scripts. shellcheck reads this from
  # ~/.shellcheckrc before falling through to per-repo $PWD/.shellcheckrc
  # files. ALL repos (personal AND open-source binaryphile/*) rely on
  # this global; no per-repo .shellcheckrc files. If an external
  # contributor / CI environment needs discoverability without Ted's
  # home-manager profile, re-add a per-repo file at that point.
  home.file.".shellcheckrc".source = ./.shellcheckrc;

  home.sessionVariables = {
    EDITOR = "nvim";
    PAGER = "less";
    SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    CFGDIR = "$HOME/.config";
    SECRETS = "$HOME/secrets";
    XDG_CONFIG_HOME = "$HOME/.config";
    TASK_BASH_LIB = "${effectiveBashTools.taskBash}/lib/task.bash";
    MK_BASH_LIB = "${effectiveBashTools.mkBash}/lib/mk.bash";
    # ERA_STATE_DIR intentionally NOT set. The prior override at
    # ~/.local/share/era-telemetry pointed era-serve at a non-canonical
    # path while era-soak.service (infra/era-soak.service:7) and the
    # Grafana stack continued to use the canonical $XDG_STATE_HOME/era
    # fallback (~/.local/state/era). The override therefore caused the
    # exact divergence it was written to prevent — era-serve's startup
    # WARN ("ERA_STATE_DIR override detected") catches this failure mode
    # post-#5274. Leaving the env unset lets era's default resolution
    # (XDG_STATE_HOME ? $XDG_STATE_HOME/era : ~/.local/state/era) align
    # all three consumers on the canonical path.
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
