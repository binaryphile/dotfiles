{ config, pkgs, ... }:

let
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
}
