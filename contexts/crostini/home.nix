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

    # ChromeOS host Chrome dispatches custom URL schemes to in-container
    # handlers via garcon, but garcon only scans the standard XDG user dir
    # (~/.local/share/applications/), NOT ~/.nix-profile/share/. Symlink the
    # home-manager-installed gpgui.desktop into the standard location.
    ".local/share/applications/gpgui.desktop".source =
      linkHome ".nix-profile/share/applications/gpgui.desktop";
  };

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

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/globalprotectcallback" = [ "gpgui.desktop" ];
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
