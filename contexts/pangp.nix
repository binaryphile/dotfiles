# Palo Alto Networks GlobalProtect (pangp) home-manager module.
#
# What this module owns:
#   - `home.packages`: installs the proprietary client (wrapped binaries)
#   - `systemd.user.services.gpa`: user-side agent for SAML browser bounce
#   - `xdg.mimeApps`: globalprotectcallback:// URI handler points to pangp
#   - `home.activation.pangpSystemUnit` (opt-in): on non-NixOS hosts
#     where home-manager can't drive `systemd.packages`, copies the
#     gpd.service unit to /etc/systemd/system/ on each `home-manager
#     switch`, then `daemon-reload`s. Requires sudo NOPASSWD for the
#     `cp` and `systemctl` invocations (Crostini's setup has this).
#
# Enabling the system daemon:
#
#   NixOS work machine: add to configuration.nix (NOT here -- system-
#   level NixOS modules aren't reachable from home-manager):
#       { systemd.packages = [ pkgs.pangp ];
#         systemd.services.gpd.wantedBy = [ "multi-user.target" ]; }
#   Then `nixos-rebuild switch`. (`pkgs.pangp` requires an overlay; the
#   user's nixos configuration.nix can pull it via:
#       nixpkgs.overlays = [ (final: prev: { pangp = inputs.dotfiles.pangp.${final.system}; }) ];)
#
#   Crostini/Debian: set `services.pangp.enableSystemDaemonOnDebian = true`
#   in your context's home.nix (or import this module with the option set).
#   The activation hook below handles unit deployment + reload.
#
# Why a separate user agent service: PanGPA is the user-facing piece that
# handles the SAML browser flow, tray icon (when GUI installed), and IPC
# with PanGPS. PanGPS itself runs as root for tun-device access. Splitting
# the two is the upstream PAN design, not our choice.

{ config, lib, pkgs, pangp, ... }:

let
  cfg = config.services.pangp;
in

{
  options.services.pangp.enableSystemDaemonOnDebian = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      On non-NixOS Linux hosts (Crostini, plain Debian), drive the
      gpd.service system unit from this home-manager module via an
      activation hook. Requires sudo NOPASSWD for `cp` and `systemctl`.
      On NixOS, leave this false and enable the daemon from your
      system-level configuration.nix instead.
    '';
  };

  config = {
  home.packages = [ pangp ];

  # User systemd unit. The derivation ships gpa.service at
  # $pangp/lib/systemd/user/gpa.service, but home-manager re-derives user
  # units from the systemd.user.services attrset, so we restate it here
  # rather than systemd.user.packages (which doesn't auto-enable).
  systemd.user.services.gpa = {
    Unit = {
      Description = "GlobalProtect VPN client agent (PanGPA, user-side)";
      After = [ "default.target" ];
    };

    Service = {
      Type = "simple";
      # $pangp/bin/PanGPA is the HOME-wrapped binary -- it redirects pangp's
      # state writes (GP_HTML/, .GlobalProtect/, etc.) into
      # $HOME/.local/share/globalprotect/ so they don't pollute $HOME.
      # See pangp.nix's makeWrapper invocation for the wrapper script.
      ExecStart = "${pangp}/bin/PanGPA start";
      Restart = "on-failure";
      RestartSec = 1;
      WorkingDirectory = "${pangp}/opt/paloaltonetworks/globalprotect";
    };

    Install.WantedBy = [ "default.target" ];
  };

  # Register the globalprotectcallback:// URI handler. mkForce because
  # linux-base.nix may declare a default (gpgui.desktop, for the OSS
  # client); pangp needs gp.desktop so the SAML callback URL bounces into
  # the PAN agent rather than the broken OSS one. The desktop file itself
  # is installed by `home.packages = [ pangp ]` into
  # $HOME/.nix-profile/share/applications/gp.desktop.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/globalprotectcallback" = lib.mkForce [ "gp.desktop" ];
    };
  };

  # On Debian-likes (Crostini), deploy the gpd.service system unit and
  # daemon-reload on each home-manager switch. On NixOS this is handled
  # by systemd.packages in configuration.nix; leave the flag false there.
  #
  # Idempotency: cp is overwriting, daemon-reload is cheap, systemctl
  # restart triggers only when the unit content actually differs (cmp -s
  # gate). If the unit didn't change between switches, we skip the
  # restart so we don't drop the user's active VPN session.
  home.activation.pangpSystemUnit = lib.mkIf cfg.enableSystemDaemonOnDebian (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      newUnit="${pangp}/lib/systemd/system/gpd.service"
      liveUnit=/etc/systemd/system/gpd.service
      if [ ! -e "$liveUnit" ] || ! cmp -s "$newUnit" "$liveUnit"; then
        $DRY_RUN_CMD sudo -n cp "$newUnit" "$liveUnit"
        $DRY_RUN_CMD sudo -n systemctl daemon-reload
        $DRY_RUN_CMD sudo -n systemctl restart gpd.service
      fi
    ''
  );
  };
}
