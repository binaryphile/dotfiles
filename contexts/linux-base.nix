{ config, pkgs, ... }:

let
  # Live symlink to a path under $HOME, preserving edit-in-place semantics
  # for files we want to edit at the source rather than via home-manager
  # rebuilds.
  linkHome = relPath: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${relPath}";
  linkDotfile = path: linkHome "dotfiles/${path}";

  mkScriptBin = import ./mkScriptBin.nix { inherit pkgs; };

  # Wrapper around notify-send that also pushes to ntfy.sh, providing
  # phone notifications for any tool that calls notify-send. The wrapper
  # statically references libnotify's notify-send via store path so it
  # does not recurse into itself.
  notify-send-bridge = mkScriptBin {
    name = "notify-send";
    src = ../scripts/notify-send;
    substitutions."notify-send" = "${pkgs.libnotify}/bin/notify-send";
    runtimeInputs = [ pkgs.curl pkgs.coreutils ];
  };

in
{
  imports = [ ../shared.nix ];

  home.packages = [ notify-send-bridge ];

  # Dotfile symlinks migrated from update-env. mkOutOfStoreSymlink keeps
  # them as live symlinks into ~/dotfiles so edits take effect immediately,
  # matching update-env's task.Ln semantics. Bootstrap-critical files
  # (.bash*, nixpkgs config, home-manager config) stay in update-env so
  # they exist before home-manager runs.
  home.file = {
    ".gitconfig".source = linkDotfile "gitconfig";
    ".gitignore_global".source = linkDotfile "gitignore_global";
    ".tmux.conf".source = linkDotfile "tmux.conf";
    ".config/liquidprompt/liquid.theme".source = linkDotfile "liquidprompt/liquid.theme";
    ".config/liquidpromptrc".source = linkDotfile "liquidprompt/liquidpromptrc";
    ".ssh/config".source = linkDotfile "ssh/config";
    ".ssh/authorized_keys".source = linkDotfile "ssh/authorized_keys";
    ".config/ranger/rc.conf".source = linkDotfile "ranger/rc.conf";
    ".config/ranger/rifle.conf".source = linkDotfile "ranger/rifle.conf";
    ".config/ranger/scope.sh".source = linkDotfile "ranger/scope.sh";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Preserved from existing ~/.config/mimeapps.list (Claude Code deep links).
      "x-scheme-handler/claude-cli" = [ "claude-code-url-handler.desktop" ];
    };
  };

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
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus"
      ];
    };
  };

  systemd.user.timers.khal-notify = {
    Unit.Description = "Calendar event reminder timer";
    Timer = {
      OnCalendar = "*:0/5";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
