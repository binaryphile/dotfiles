{ config, pkgs, dotfiles, ... }:

{
  imports = [ ../../shared.nix ];

  home.packages = with pkgs; [
    bottom
    dig
    # not available on mac
    cliphist
    libnotify
    asciinema
    asciinema-agg
    wl-clipboard
  ];

  home.file.".claude/settings.json" = {
    source = "${dotfiles}/claude/settings.json";
    force = true;
  };
  home.file.".claude/CLAUDE.md" = {
    source = "${dotfiles}/claude/CLAUDE.md";
    force = true;
  };

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
        urlCommand = [ "${pkgs.coreutils}/bin/cat" "${config.home.homeDirectory}/secrets/calendar-ics.url" ];
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

  # Calendar reminders: notify-send at 5min and 1min before events
  systemd.user.services.khal-notify = {
    Unit.Description = "Calendar event reminder notifications";
    Service = {
      Type = "oneshot";
      ExecStart = "${dotfiles}/scripts/khal-notify";
      Environment = [
        "PATH=${pkgs.bash}/bin:${pkgs.khal}/bin:${pkgs.libnotify}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin"
        "DISPLAY=:0"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
      ];
    };
  };

  systemd.user.timers.khal-notify = {
    Unit.Description = "Calendar event reminder timer";
    Timer = {
      OnCalendar = "minutely";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
