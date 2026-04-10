{ config, pkgs, ... }:

let
  # Live symlink helper, mirroring linux-base.nix's pattern.
  linkDotfile = path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/${path}";

  # tinyproxy listens on container loopback. ChromeOS host Chrome reaches
  # it via garcon's container->host localhost forwarding. Selectively used
  # by Chrome via the PAC file below — only VPN-bound hosts traverse it.
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
  # returns DIRECT — Chrome connects without involving the container.
  # Keep this list in sync with vpn-connect's vpn-slice host list.
  proxyPac = pkgs.writeText "proxy.pac" ''
    function FindProxyForURL(url, host) {
      var vpnHosts = [
        "stash.digi.com",
        "dm1.devdevicecloud.com",
        "nexus.digi.com",
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
  imports = [ ../linux-base.nix ];

  home.username = "ted";
  home.homeDirectory = "/home/ted";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    ast-grep
    btop
    bubblewrap
    abcde
    asciinema
    asciinema-agg
    darkhttpd
    tinyproxy
    wl-clipboard
    xmlstarlet
  ];

  home.file = {
    ".claude/settings.json" = {
      source = ../../claude/settings.json;
      force = true;
    };
    ".claude/CLAUDE.md" = {
      source = ../../claude/CLAUDE.md;
      force = true;
    };
    # PAC file served by darkhttpd. Lives in its own directory so the
    # static server can be pointed at the directory and only serve this.
    ".local/share/proxy-pac/proxy.pac".source = proxyPac;

    # Crostini-only user scripts: tmux status bar widgets, vpn ergonomic
    # wrapper, and the Digi security advisory watcher. Live symlinks via
    # mkOutOfStoreSymlink so edits in the repo take effect immediately.
    ".local/bin/panel".source                = linkDotfile "scripts/panel";
    ".local/bin/vpn".source                  = linkDotfile "scripts/vpn";
    ".local/bin/digi-security-watch".source  = linkDotfile "scripts/digi-security-watch";
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
  # before. Crostini-only — on NixOS, equivalent monitoring is handled
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
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
