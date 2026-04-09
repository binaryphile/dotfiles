{ config, pkgs, ... }:

let
  # Wrapper around notify-send that also pushes to ntfy.sh, providing
  # phone notifications for any tool that calls notify-send. The wrapper
  # statically references libnotify's notify-send via store path so it
  # does not recurse into itself.
  notify-send-bridge = pkgs.stdenv.mkDerivation {
    name = "notify-send-bridge";
    src = ../scripts/notify-send;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      install -Dm755 $src $out/bin/notify-send
      substituteInPlace $out/bin/notify-send \
        --replace-fail '@notify-send@' '${pkgs.libnotify}/bin/notify-send'
      wrapProgram $out/bin/notify-send \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.curl pkgs.coreutils ]}
    '';
  };
in
{
  imports = [ ../shared.nix ];

  home.packages = [ notify-send-bridge ];

  # Calendar: vdirsyncer syncs ICS from OWA, khal reads it.
  # ICS URL stored in ~/secrets/calendar-ics.url (not committed).
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

  # Calendar reminders: notify-send at 5min and 1min before events.
  # Phone push happens transparently via the notify-send-bridge wrapper.
  systemd.user.services.khal-notify = {
    Unit.Description = "Calendar event reminder notifications";
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/dotfiles/scripts/khal-notify";
      Environment = [
        "PATH=${pkgs.bash}/bin:${pkgs.khal}/bin:${notify-send-bridge}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin"
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
