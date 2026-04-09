{ config, pkgs, ... }:

let
  inherit (pkgs) lib;

  # Live symlink to a path under $HOME, preserving edit-in-place semantics
  # for files we want to edit at the source rather than via home-manager
  # rebuilds. Used for dotfiles (~/dotfiles/...) and the garcon discovery
  # symlink (~/.nix-profile/...).
  linkHome = relPath: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${relPath}";
  linkDotfile = path: linkHome "dotfiles/${path}";

  # Build a wrapped script binary from a file in scripts/. Substitutes
  # `@key@` placeholders with the corresponding store paths and wraps the
  # result with `runtimeInputs` on PATH. Use substitutions for things the
  # script invokes under sudo (PATH is stripped) and runtimeInputs for
  # things invoked normally.
  mkScriptBin = { name, src, substitutions ? {}, runtimeInputs ? [] }:
    pkgs.stdenv.mkDerivation {
      inherit name src;
      dontUnpack = true;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      installPhase = let
        subFlags = lib.concatStringsSep " \\\n        "
          (lib.mapAttrsToList (k: v: "--replace-fail '@${k}@' '${v}'") substitutions);
      in ''
        install -Dm755 $src $out/bin/${name}
        ${lib.optionalString (substitutions != {}) ''
          substituteInPlace $out/bin/${name} \
            ${subFlags}
        ''}
        wrapProgram $out/bin/${name} \
          --prefix PATH : ${lib.makeBinPath runtimeInputs}
      '';
    };

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

  # Yuezk's Rust rewrite of GlobalProtect-openconnect, via upstream flake.
  # Avoids nixpkgs' old C++/Qt 1.4.9 build that drags in qtwebengine.
  # NOTE: unpinned because v2.4.4 tag fails to build; main works.
  gpoc = (builtins.getFlake "github:yuezk/GlobalProtect-openconnect").packages.${pkgs.system}.default;

  # vpn-connect script wrapped with vpn-slice and gpclient store paths
  # baked in (sudo strips PATH so absolute paths are required) and gpoc
  # on PATH for the unsudo'd gpauth invocation.
  vpn-connect = mkScriptBin {
    name = "vpn-connect";
    src = ../scripts/vpn-connect;
    substitutions = {
      "vpn-slice" = "${pkgs.vpn-slice}/bin/vpn-slice";
      "gpclient" = "${gpoc}/bin/gpclient";
    };
    runtimeInputs = [ gpoc ];
  };
in
{
  imports = [ ../shared.nix ];

  home.packages = [ notify-send-bridge gpoc vpn-connect ];

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

    # On Crostini, ChromeOS host Chrome dispatches custom URL schemes to
    # in-container handlers via garcon, but garcon only scans the standard
    # XDG user dir (~/.local/share/applications/), NOT ~/.nix-profile/share/.
    # Symlink the home-manager-installed gpgui.desktop into the standard
    # location so garcon picks it up.
    ".local/share/applications/gpgui.desktop".source =
      linkHome ".nix-profile/share/applications/gpgui.desktop";
  };

  # Register gpclient as the URL scheme handler for globalprotectcallback://.
  # gpauth's external-browser SAML flow returns a globalprotectcallback: URL;
  # the OS hands it to gpclient launch-gui, which TCP-connects to gpauth's
  # listener via /tmp/gpcallback.port to deliver the cookie. Without this
  # registration the browser silently drops the URL and gpauth hangs forever.
  xdg.desktopEntries.gpgui = {
    name = "GP Connect";
    comment = "A GUI client for GlobalProtect VPN";
    genericName = "GlobalProtect VPN Client";
    categories = [ "Network" "Dialup" ];
    exec = "${gpoc}/bin/gpclient launch-gui %u";
    mimeType = [ "x-scheme-handler/globalprotectcallback" ];
    icon = "gpgui";
    terminal = false;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/globalprotectcallback" = [ "gpgui.desktop" ];
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
      OnCalendar = "minutely";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
