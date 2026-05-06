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

  # Panel sibling files: probe-lib.bash and load-sparkline, installed to
  # a store path so the nix-packaged panel can reference them via @here@
  # substitution. Shared source -- waybar on NixOS sources probe-lib
  # from the dotfiles tree independently.
  panel-lib = pkgs.runCommand "panel-lib" {} ''
    mkdir -p $out
    cp ${../scripts/probe-lib.bash} $out/probe-lib.bash
    cp ${../scripts/load-sparkline} $out/load-sparkline
  '';

  # Panel: tmux status bar renderer. Nix-packaged with runtime deps on
  # PATH and @here@ pointing to panel-lib for probe-lib.bash and
  # load-sparkline. See design.md Status widgets (UC-10).
  panel = mkScriptBin {
    name = "panel";
    src = ../scripts/panel;
    substitutions."here" = "${panel-lib}";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.gnugrep
      pkgs.iproute2
      pkgs.jq
      pkgs.openssh
      pkgs.procps
      pkgs.systemd
    ];
  };

  # Tmux with panel on PATH. Overlaid via symlinkJoin so tmux's status
  # bar commands (#(panel ...)) find the panel binary regardless of the
  # session's PATH state. macOS does not need panel (no headless tmux
  # sessions); it uses plain tmux from shared.nix.
  tmux-with-panel = pkgs.symlinkJoin {
    name = "tmux-with-panel";
    paths = [ pkgs.tmux ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/tmux \
        --prefix PATH : ${pkgs.lib.makeBinPath [ panel ]}
    '';
  };

in
{
  imports = [ ../shared.nix ];

  home.packages = [ notify-send-bridge tmux-with-panel pkgs._1password-gui ];

  # After switching generations, update the running tmux server's PATH so
  # #(panel ...) status commands resolve the new nix store path. Without
  # this, tmux keeps the stale PATH from when the server started and panel
  # never picks up rebuilt derivations.
  home.activation.updateTmuxPath = config.lib.dag.entryAfter [ "installPackages" ] ''
    if command -v tmux >/dev/null 2>&1 && tmux has-session 2>/dev/null; then
      tmux set-environment -g PATH "${config.home.profileDirectory}/bin:$PATH" || true
    fi
  '';

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
    ".ssh/id_ed25519_signing.pub".source = linkDotfile "ssh/id_ed25519_signing.pub";
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
  systemd.user.services.vdirsyncer.Unit.ConditionPathExists = "%h/secrets/calendar-ics.url";

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
