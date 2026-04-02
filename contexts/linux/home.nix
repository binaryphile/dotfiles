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

  # Calendar: vdirsyncer syncs ICS from OWA, khal reads it
  # ICS URL stored in ~/secrets/calendar-ics.url (not committed)
  accounts.calendar = {
    basePath = ".calendars";
    accounts.work = {
      primary = true;
      remote = {
        type = "http";
      };
      local = {
        type = "filesystem";
        fileExt = ".ics";
      };
      vdirsyncer = {
        enable = true;
        collections = null;
        urlCommand = [ "cat" "${config.home.homeDirectory}/secrets/calendar-ics.url" ];
      };
      khal = {
        enable = true;
        type = "calendar";
      };
    };
  };

  programs.vdirsyncer.enable = true;
  services.vdirsyncer.enable = true;

  programs.khal = {
    enable = true;
    locale = {
      local_timezone = "America/New_York";
      default_timezone = "America/New_York";
      timeformat = "%H:%M";
      dateformat = "%Y-%m-%d";
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

  # Calendar reminders: notify-send at 5min and 1min before events
  systemd.user.services.khal-notify = {
    Unit.Description = "Calendar event reminder notifications";
    Service = {
      Type = "oneshot";
      ExecStart = "${dotfiles}/scripts/khal-notify";
      Environment = [
        "PATH=${pkgs.khal}/bin:${pkgs.libnotify}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin"
        "DISPLAY=:0"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
      ];
    };
  };

  systemd.user.timers.khal-notify = {
    Unit.Description = "Calendar event reminder timer";
    Timer = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  programs.home-manager.enable = true;
}
