# 1Password SSH agent: declarative deployment of the systemd-user service.
#
# This module ships ONLY the systemd unit. The full feature requires three
# interlocking artifacts; the other two live in linux-base.nix:
#
#   1. systemd-user service (this module)
#        -> runs `1password --silent`, which binds ~/.1password/agent.sock
#   2. dotfiles/bash/init.bash kick block (symlinked, in dotfiles)
#        -> imports DISPLAY/WAYLAND_DISPLAY into user-systemd on first
#           interactive shell so the unit can come up; also recovers from
#           start-limit-failed state on cold-boot Crostini
#   3. programs.git in linux-base.nix
#        -> gpg.format=ssh,
#           gpg.ssh.program=${pkgs._1password-gui}/bin/op-ssh-sign,
#           commit.gpgsign=true, user.signingkey=~/.ssh/id_ed25519_signing.pub
#
# Removing or breaking any one of the three breaks `git commit` signing.
# pkgs._1password-gui is already in linux-base.nix's home.packages, so this
# module does not add it.
#
# Pre-2026-06-24 the gitconfig was a static home.file symlink to
# contexts/<ctx>/gitconfig (literal file). That deployment baked a
# context-dependent path (~/.nix-profile/bin/op-ssh-sign) which was wrong
# on NixOS hosts where HM is integrated and ~/.nix-profile/bin/ is
# unpopulated. Migrating to programs.git lets ${pkgs._1password-gui} bind
# the path to the Nix store, host-portably and GC-immune.

{ ... }:

{
  systemd.user.services.onepassword = {
    Unit = {
      Description = "1Password (silent; hosts SSH agent for op-ssh-sign)";
      After = [ "default.target" ];
    };

    Service = {
      Type = "simple";
      # Stale socket file may exist from a prior unclean shutdown; clear it
      # so 1Password can bind cleanly. /bin/sh -c form is portable: NixOS
      # lacks /usr/bin/rm but has /bin/sh. Leading `-` tolerates absent file.
      ExecStartPre = "-/bin/sh -c 'rm -f %h/.1password/agent.sock'";
      ExecStart = "%h/.nix-profile/bin/1password --silent";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
