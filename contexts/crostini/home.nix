{ config, pkgs, lib, ... }:

let
  linkHome = relPath:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${relPath}";
  linkDotfile = path: linkHome "dotfiles/${path}";

  mkScriptBin = import ../mkScriptBin.nix { inherit pkgs; };

  # gpoc (GlobalProtect-openconnect) is installed via apt on crostini
  # (update-env stage 1) to avoid the upstream flake's Rust build.
  # On NixOS, linux/home.nix receives gpoc as a flake input from nixos-config.
  gpclient = "/usr/bin/gpclient";

  # vpn-connect script wrapped with vpn-slice and gpclient absolute paths
  # baked in (sudo strips PATH so absolute paths are required).
  vpn-connect = mkScriptBin {
    name = "vpn-connect";
    src = ../../scripts/vpn-connect;
    substitutions = {
      "vpn-slice" = "${pkgs.vpn-slice}/bin/vpn-slice";
      "gpclient" = gpclient;
    };
  };

  # onepassword:// scheme handler. Built with absolute Exec path so it
  # doesn't depend on PATH resolution under garcon's minimal-PATH dispatch
  # env (cros-garcon.service hardcodes PATH and child processes inherit it;
  # nix-profile is not on that PATH). The package's bundled .desktop ships
  # Exec=1password (no path) which fails when ChromeOS dispatches the
  # callback. makeDesktopItem builds a derivation; home.file (below) places
  # the resulting .desktop into ~/.local/share/applications/ -- one of the
  # few directories garcon's XDG_DATA_DIRS actually includes.
  onepasswordDesktop = pkgs.makeDesktopItem {
    name = "onepassword";
    desktopName = "1Password (URL scheme handler)";
    exec = "${pkgs._1password-gui}/bin/1password %U";
    mimeTypes = [ "x-scheme-handler/onepassword" ];
    terminal = false;
    noDisplay = true;
  };

  # tinyproxy listens on container loopback. ChromeOS host Chrome reaches
  # it via garcon's container->host localhost forwarding. Selectively used
  # by Chrome via the PAC file below -- only VPN-bound hosts traverse it.
  tinyproxyPort = 8118;
  pacPort = 8120;
  pacDir = "${config.home.homeDirectory}/.local/share/proxy-pac";

  tinyproxyConf = pkgs.writeText "tinyproxy.conf" ''
    Port ${toString tinyproxyPort}
    Listen 127.0.0.1
    Timeout 600
    LogLevel Critical
    MaxClients 50
    DisableViaHeader Yes
  '';

  # PAC file routes only VPN hosts through tinyproxy. Everything else
  # returns DIRECT -- Chrome connects without involving the container.
  # vpn-connect routes 10.0.0.0/8 and 172.26.0.0/16 via CIDRs for
  # routing, and lists split-horizon *.digi.com hosts as positional
  # args so vpn-slice writes /etc/hosts entries. This PAC uses
  # dnsDomainIs to auto-match any *.digi.com host (excluding public
  # sites), plus explicit entries for AWS-hosted services.
  proxyPac = pkgs.writeText "proxy.pac" ''
    function FindProxyForURL(url, host) {
      // Public *.digi.com sites -- access externally, not via tunnel
      if (host == "remotemanager.digi.com" || host == "www.digi.com" || host == "digi.com") {
        return "DIRECT";
      }
      // Internal *.digi.com services (vpn-slice writes /etc/hosts via positional args)
      if (dnsDomainIs(host, ".digi.com")) {
        return "PROXY 127.0.0.1:${toString tinyproxyPort}";
      }
      // AWS-hosted services that require VPN source IP
      var vpnHosts = [
        "dm1.devdevicecloud.com",
        "gitlab.drm.ninja",
        "3.16.193.243"
      ];
      for (var i = 0; i < vpnHosts.length; i++) {
        if (host == vpnHosts[i] || shExpMatch(host, "*." + vpnHosts[i])) {
          return "PROXY 127.0.0.1:${toString tinyproxyPort}";
        }
      }
      return "DIRECT";
    }
  '';
in
{
  imports = [ ../linux-base.nix ../claude.nix ];

  home.username = "ted";
  home.homeDirectory = "/home/ted";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    ast-grep
    bubblewrap
    abcde
    asciinema
    asciinema-agg
    darkhttpd
    tinyproxy
    wl-clipboard
    xmlstarlet
    vpn-connect
  ];

  home.file = {
    # PAC file served by darkhttpd. Lives in its own directory so the
    # static server can be pointed at the directory and only serve this.
    ".local/share/proxy-pac/proxy.pac".source = proxyPac;

    # Crostini-only user scripts: vpn ergonomic wrapper and the Digi
    # security advisory watcher. Live symlinks via mkOutOfStoreSymlink so
    # edits in the repo take effect immediately. Panel is nix-packaged as
    # a tmux dependency in linux-base.nix (not a live symlink).
    ".local/bin/vpn".source                  = linkDotfile "scripts/vpn";
    ".local/bin/digi-security-watch".source  = linkDotfile "scripts/digi-security-watch";

    # Place the onepassword scheme handler where garcon can find it.
    # home-manager's xdg.desktopEntries deploys to ~/.nix-profile/share/
    # applications/ which is NOT in cros-garcon.service's XDG_DATA_DIRS;
    # only ~/.local/share/applications/ is reachable. (This contradicts
    # the assertion in dotfiles commit d9db7a9 that xdg.desktopEntries
    # alone is sufficient for Crostini -- empirically false. Same fix
    # would re-enable gpgui dispatch but is left for a separate commit.)
    ".local/share/applications/onepassword.desktop".source =
      "${onepasswordDesktop}/share/applications/onepassword.desktop";
  };

  # 1Password desktop-integration gate: the desktop app verifies the
  # connecting `op` binary via SO_PEERCRED, requiring egid to equal the
  # onepassword-cli group (achieved via setgid bit). The Nix-installed op
  # is 0555 ted:ted by default and fails the gate with PipeAuthError(NoCreds).
  # Mirror the official .deb postinst imperatively: create the group
  # (default GID; >=1000 confirmed sufficient via Phase 0) and setgid the
  # resolved store binary. Heretical (mutates /nix/store); v2 follow-on is
  # a wrapper-outside-store pattern. See docs/design.md Desktop Integration
  # Gate (Linux). NixOS uses security.wrappers."op" instead -- this hook
  # is crostini-only.
  home.activation.opSetgid = config.lib.dag.entryAfter [ "installPackages" ] ''
    set -eu
    opPath=$(readlink -f "$HOME/.nix-profile/bin/op" 2>/dev/null) || exit 0

    stateDir="$HOME/.local/state/op-run"
    /usr/bin/install -d -m 700 "$stateDir" 2>/dev/null || true
    statusFile="$stateDir/activation-status"

    # Atomic state-file write: stage to a temp file, rename at end. Avoids
    # truncate-then-write races between concurrent home-manager switches.
    tmpStatus=$(/usr/bin/mktemp "$stateDir/.activation-status.XXXXXX") || tmpStatus=""

    warn() {
      echo "WARNING: home.activation.opSetgid: $*" >&2
      [[ -n $tmpStatus ]] && printf 'DEGRADED: %s\n' "$*" >>"$tmpStatus" 2>/dev/null || true
    }

    # Idempotent fast-path: if the binary is already correctly configured
    # (setgid + onepassword-cli group), skip sudo entirely. Avoids spurious
    # warnings on already-deployed hosts. Sudo only fires on first deploy
    # or after an `op` upgrade replaces the store path with default perms.
    if /usr/bin/getent group onepassword-cli >/dev/null \
      && [[ -g $opPath ]] \
      && [[ $(/usr/bin/stat -c '%G' "$opPath") == onepassword-cli ]]; then
      : # already configured
    else
      if ! /usr/bin/getent group onepassword-cli >/dev/null; then
        if ! /usr/bin/sudo -n /usr/sbin/groupadd onepassword-cli 2>/dev/null; then
          warn "could not create onepassword-cli group (sudo -n failed). Run: sudo groupadd onepassword-cli"
        fi
      fi

      if /usr/bin/getent group onepassword-cli >/dev/null; then
        if ! /usr/bin/sudo -n /bin/chgrp onepassword-cli "$opPath" 2>/dev/null \
          || ! /usr/bin/sudo -n /bin/chmod g+s "$opPath" 2>/dev/null; then
          warn "could not chgrp/chmod $opPath (sudo -n failed). Run: sudo chgrp onepassword-cli '$opPath' && sudo chmod g+s '$opPath'"
        fi
      fi
    fi

    if [[ -g $opPath ]]; then
      [[ -n $tmpStatus ]] && printf 'OK %s\n' "$(date -u +%FT%TZ)" >"$tmpStatus" 2>/dev/null || true
    else
      warn "op binary at $opPath does not have setgid bit set; op-run will fail with PipeAuthError. See docs/design.md Desktop Integration Gate (Linux)."
    fi

    # Atomic publish: rename temp file over real status file. POSIX-atomic
    # on the same filesystem; concurrent activations either win or lose
    # cleanly, never interleave bytes.
    [[ -n $tmpStatus ]] && /bin/mv -f "$tmpStatus" "$statusFile" 2>/dev/null || true
  '';

  # Register gpclient as the URL scheme handler for globalprotectcallback://.
  xdg.desktopEntries = {
    gpgui = {
      name = "GP Connect";
      comment = "A GUI client for GlobalProtect VPN";
      genericName = "GlobalProtect VPN Client";
      categories = [ "Network" "Dialup" ];
      exec = "${gpclient} launch-gui %u";
      mimeType = [ "x-scheme-handler/globalprotectcallback" ];
      icon = "gpgui";
      terminal = false;
    };
  };

  # http/https default handler is garcon's host-browser bridge -- routes
  # xdg-open https://... from the container to ChromeOS host Chrome.
  # firefox-esr's apt install can register itself as the default browser
  # and break the bridge; declaring the default here keeps the routing
  # stable across firefox-esr updates and home-manager rebuilds.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/globalprotectcallback" = [ "gpgui.desktop" ];
      "x-scheme-handler/http"  = [ "garcon_host_browser.desktop" ];
      "x-scheme-handler/https" = [ "garcon_host_browser.desktop" ];
      # onepassword:// is Okta's SSO redirect target after auth. ChromeOS
      # Chrome dispatches the URI back into the container via garcon; the
      # in-container 1Password's running instance receives it via Electron's
      # single-instance arg-forward and verifies the OIDC callback. NOTE:
      # this completes the AUTH; the Chrome sign-in tab does NOT auto-close
      # because the 1Password browser extension's native-messaging bridge
      # cannot reach a container-resident binary from host Chrome (same
      # architectural constraint as Snap/Flatpak per 1Password docs). Close
      # the Chrome tab manually after auth completes.
      "x-scheme-handler/onepassword" = [ "onepassword.desktop" ];
    };
  };

  # tinyproxy: forward HTTP proxy for VPN-bound traffic. Only invoked by
  # ChromeOS Chrome when the PAC file routes a request through it.
  systemd.user.services.tinyproxy = {
    Unit.Description = "tinyproxy HTTP forward proxy for VPN-bound traffic";
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.tinyproxy}/bin/tinyproxy -d -c ${tinyproxyConf}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # darkhttpd: tiny static file server, serves the PAC file to ChromeOS
  # Chrome's "Automatic proxy configuration" URL. Could equivalently use
  # `python3 -m http.server` but darkhttpd is a single binary and faster.
  systemd.user.services.proxy-pac-server = {
    Unit.Description = "Static HTTP server for ChromeOS Chrome PAC file";
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${pacDir} --addr 127.0.0.1 --port ${toString pacPort} --no-listing";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Digi security advisory watcher: polls the Digi Security Center RSS
  # feed every 30 minutes, fires a notify-send (which the linux-base
  # wrapper bridges to ntfy phone push) for any advisory not seen
  # before. Crostini-only -- on NixOS, equivalent monitoring is handled
  # by the waybar custom modules.
  systemd.user.services.digi-security-watch = {
    Unit.Description = "Watch Digi Security Center RSS for new advisories";
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/dotfiles/scripts/digi-security-watch";
      Environment = [
        "PATH=${pkgs.bash}/bin:${pkgs.curl}/bin:${pkgs.xmlstarlet}/bin:${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin:${pkgs.util-linux}/bin:${config.home.homeDirectory}/.nix-profile/bin"
      ];
      TimeoutStopSec = 300;
    };
  };

  systemd.user.timers.digi-security-watch = {
    Unit.Description = "Poll Digi Security Center RSS every 30 minutes";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
