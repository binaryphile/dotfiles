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

  # Expose pangp's deployment source + canonical destination to update-env
  # so it can source autoPatchelf'd binaries at deploy time instead of
  # re-extracting the un-patched .deb. Cross-platform: home-manager runs
  # on both Crostini (Debian + Nix) and NixOS hosts. Auto-updated on every
  # home-manager switch; if pangp's nix-store rev rotates, marker content
  # updates with it.
  #
  # Two markers (not one) because:
  # - source: where the patched binaries live in nix-store
  # - dest: the canonical runtime path (uses pangp.passthru.runtimeBase
  #   so any future pangp.nix runtimeBase change propagates here without
  #   re-touching update-env)
  #
  # `.outPath` is explicit (vs bare `"${pangp}"` derivation->string
  # coercion) to make the producer code defensible against unusual
  # pangp value shapes.
  #
  # Consumer: ~/dotfiles/update-env's extractGlobalprotectDebToOptTask
  # reads these via `$(< ~/.local/share/pangp/source)` and stages the
  # source content into the dest path. See docs/vpn.md "NixOS adaptation
  # (calumny pattern)" subsection.
  home.file.".local/share/pangp/source".text =
    "${pangp.outPath}${pangp.passthru.runtimeBase}";
  home.file.".local/share/pangp/dest".text = pangp.passthru.runtimeBase;

  # User systemd unit. The derivation ships gpa.service at
  # $pangp/lib/systemd/user/gpa.service, but home-manager re-derives user
  # units from the systemd.user.services attrset, so we restate it here
  # rather than systemd.user.packages (which doesn't auto-enable).
  #
  # ExecStart points at the /opt PanGPA, not the nix-store $pangp/bin/
  # PanGPA wrapper, because PanGPS performs an IPC peer co-location
  # check: dirname(realpath(/proc/<peer>/exe)) must equal
  # dirname(realpath(/proc/self/exe)). If they differ -- e.g., PanGPS
  # runs from $out/opt/... while PanGPA's /proc/exe resolves to /opt/...
  # -- PanGPS rejects with "Connected by process not from GP folder".
  # The /opt subtree is staged by `update-env`'s
  # extractGlobalprotectDebToOptTask so both binaries co-locate there.
  # See pangp.nix's header comment and docs/design.md "PanGPS co-
  # location check".
  #
  # HOME is wrapped (per the original derivation rationale) to keep
  # GP_HTML/ and .GlobalProtect/ off the top-level $HOME. XDG_CONFIG_HOME
  # and XDG_DATA_HOME are pinned to the real $HOME directories so that
  # xdg-open (spawned by PanGPA for SAML browser launch) finds
  # mimeapps.list and .desktop files in their canonical user locations
  # rather than under the wrapped HOME (where they don't exist). Without
  # this, xdg-open falls through to garcon's terminal vim handler.
  systemd.user.services.gpa = {
    Unit = {
      Description = "GlobalProtect VPN client agent (PanGPA, user-side)";
      After = [ "default.target" ];
    };

    Service = {
      Type = "simple";
      Environment = [
        "HOME=%h/.local/share/globalprotect"
        "XDG_CONFIG_HOME=%h/.config"
        "XDG_DATA_HOME=%h/.local/share"
      ];
      # NixOS lacks /bin/mkdir (only /bin/sh); systemd-exec'd path must be
      # absolute and exist. Use nix-store coreutils for cross-platform safety
      # (works on NixOS and Crostini-with-Nix; the Crostini /bin/mkdir path
      # would also work there but the nix-store path is uniform).
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.local/share/globalprotect";
      ExecStart = "${pangp.passthru.runtimeBase}/PanGPA start";
      Restart = "on-failure";
      RestartSec = 1;
      WorkingDirectory = pangp.passthru.runtimeBase;
    };

    Install.WantedBy = [ "default.target" ];
  };

  # ensure-pangp-active.service -- convergence oneshot that asserts both gpd
  # (system) and gpa (user) are running. Fires at session start via the
  # default.target WantedBy edge (catches cold-start case) and via the
  # ensure-pangp-active.timer below (catches container-resume case where
  # default.target is NOT re-entered -- empirically verified 2026-06-05 that
  # cros-garcon survives in-place across ChromeOS suspend/wake; tasks.
  # dotfiles #27152 Phase 3a Step 1 artifact ~/pangp-27152-verification/
  # lifecycle-decision.md).
  #
  # Uses sudo -n for the system-service start (same NOPASSWD path the
  # activation hook uses; available on Crostini per the established
  # contexts/pangp.nix convention). The `|| true` lets the oneshot
  # complete cleanly even when gpd is already running (start is idempotent
  # at the systemd level but the operator may have stopped it via vpn-mode
  # gpoc -- in that case the start would be expected to succeed, so this
  # is just defensive against transient sudo errors).
  systemd.user.services.ensure-pangp-active = lib.mkIf cfg.enableSystemDaemonOnDebian {
    Unit = {
      Description = "Ensure pangp services (gpd system + gpa user) are running";
      Documentation = [ "tasks.dotfiles-#27152" ];
      After = [ "default.target" ];
      PartOf = [ "default.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = [
        "/usr/bin/sudo -n /bin/systemctl start gpd.service"
        "/bin/systemctl --user start gpa.service"
      ];
      RemainAfterExit = true;
    };

    Install.WantedBy = [ "default.target" ];
  };

  # ensure-pangp-active.timer -- 5-minute backstop. The default.target
  # WantedBy on the service catches cold-start (boot/session-init). The
  # timer catches the container-resume case where default.target is NOT
  # re-entered. Persistent=true is load-bearing -- if the timer would have
  # fired during host suspend, it fires immediately on resume, catching
  # the missed activation.
  systemd.user.timers.ensure-pangp-active = lib.mkIf cfg.enableSystemDaemonOnDebian {
    Unit = {
      Description = "Periodic backstop: ensure pangp services running";
      Documentation = [ "tasks.dotfiles-#27152" ];
    };

    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "ensure-pangp-active.service";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
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
  #
  # Cleanup: prior versions of this module had users manually drop
  # systemd override.conf files (system + user) to point ExecStart at
  # /opt. The HM-managed units now have those settings baked in, so
  # the overrides are redundant. Atomic cleanup with the new unit
  # deployment avoids a window where a service restart would pick up
  # the new (correct) unit without the override (still correct) or vice
  # versa.
  home.activation.pangpSystemUnit = lib.mkIf cfg.enableSystemDaemonOnDebian (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      newUnit="${pangp}/lib/systemd/system/gpd.service"
      liveUnit=/etc/systemd/system/gpd.service
      sysOverride=/etc/systemd/system/gpd.service.d/override.conf
      userOverride=$HOME/.config/systemd/user/gpa.service.d/override.conf
      # Inside the cmp-gate: content-drift-dependent operations only.
      # cp + override-cleanup + daemon-reload + restart are expensive AND
      # only justified by an actual unit-content delta. restart-on-content-
      # drift drops a live tunnel; that's acceptable because the new content
      # was the whole point of the redeploy.
      if [ ! -e "$liveUnit" ] || ! cmp -s "$newUnit" "$liveUnit"; then
        $DRY_RUN_CMD /usr/bin/sudo -n cp "$newUnit" "$liveUnit"
        # Remove the transitional override.conf files. HM-deployed units
        # now carry equivalent settings (ExecStart=/opt/.../, XDG env).
        [ -f "$sysOverride" ] && $DRY_RUN_CMD /usr/bin/sudo -n rm "$sysOverride"
        [ -f "$userOverride" ] && $DRY_RUN_CMD rm "$userOverride"
        $DRY_RUN_CMD /usr/bin/sudo -n ${pkgs.systemd}/bin/systemctl daemon-reload
        $DRY_RUN_CMD /usr/bin/sudo -n ${pkgs.systemd}/bin/systemctl restart gpd.service
      fi
      # Outside the cmp-gate: idempotent state-convergence commands that
      # MUST run on every activation regardless of unit-content drift.
      # Without these, an HM switch where unit content didn't change won't
      # re-converge gpd to "enabled + running" -- which was the failure mode
      # behind tasks.dotfiles #27152 (gpd inactive 26+ hours despite being
      # enabled, because nothing re-started it after an earlier `vpn-mode
      # gpoc` stopped it and subsequent switches skipped the cmp-gate).
      # `start` not `restart`: idempotent no-op on a running gpd; cannot
      # drop a live tunnel; starts a stopped gpd to converge state.
      $DRY_RUN_CMD /usr/bin/sudo -n ${pkgs.systemd}/bin/systemctl enable gpd.service
      $DRY_RUN_CMD /usr/bin/sudo -n ${pkgs.systemd}/bin/systemctl start gpd.service
      $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user start gpa.service
    ''
  );
  };
}
