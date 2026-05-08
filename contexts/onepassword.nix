# 1Password SSH agent: declarative deployment of the systemd-user service.
#
# This module ships ONLY the systemd unit. The full feature requires three
# interlocking artifacts; the other two live in dotfiles directly because
# they are symlink-deployed via linux-base.nix's home.file:
#
#   1. systemd-user service (this module)
#        -> runs `1password --silent`, which binds ~/.1password/agent.sock
#   2. dotfiles/bash/init.bash kick block (symlinked, in dotfiles)
#        -> imports DISPLAY/WAYLAND_DISPLAY into user-systemd on first
#           interactive shell so the unit can come up; also recovers from
#           start-limit-failed state on cold-boot Crostini
#   3. dotfiles/gitconfig signing keys (symlinked, in dotfiles)
#        -> gpg.format=ssh, gpg.ssh.program=op-ssh-sign, commit.gpgsign=true,
#           user.signingkey=~/.ssh/id_ed25519_signing.pub
#
# Removing or breaking any one of the three breaks `git commit` signing.
# pkgs._1password-gui is already in linux-base.nix's home.packages, so this
# module does not add it.
#
# This module was NOT consolidated into a single block holding the systemd
# service + programs.bash.initExtra + programs.git.extraConfig because that
# would conflict with the existing dotfiles/bash/init.bash and
# dotfiles/gitconfig symlinks (both established in linux-base.nix's
# home.file). Keep the symlink-deploys as the source of truth for those
# two; this module owns only the systemd unit.
#
# Verified end-to-end on Crostini host (commit object contains
# `gpgsig -----BEGIN SSH SIGNATURE-----`). NixOS deployment of this module
# is unverified at time of writing -- import from contexts/desktop/home.nix
# and rebuild; verify_signing in the plan covers post-deploy validation.
#
# Plan: ~/.claude/plans/the-plan-after-you-staged-blanket.md

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
