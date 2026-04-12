{ config, pkgs, dotfiles, ... }:

let
  inherit (pkgs) lib;

  homeDir = config.home.homeDirectory;

  # Encode an absolute path the way Claude Code does for project directories:
  # /home/ted/projects/dal -> -home-ted-projects-dal
  encodePath = path: builtins.replaceStrings ["/"] ["-"] path;

  # All projects get an Era memory redirect
  eraProjects = [
    "${homeDir}/dotfiles"
    "${homeDir}/projects/era"
    "${homeDir}/projects/fp.bash"
    "${homeDir}/projects/mk.bash"
    "${homeDir}/projects/task.bash"
    "${homeDir}/projects/tesht"
    "${homeDir}/projects/jeeves"
    "${homeDir}/projects/sofdevsim-2026"
    "${homeDir}/projects/binaryphile.github.io"
    "${homeDir}/projects/tandem-protocol"
    "${homeDir}/projects/urma"
    "${homeDir}/projects/share"
    "${homeDir}/projects/dal"
  ];

  redirectSource = "${dotfiles}/claude/era-memory-redirect.md";

  memoryRedirects = lib.listToAttrs (map (dir:
    lib.nameValuePair
      ".claude/projects/${encodePath dir}/memory/MEMORY.md"
      { source = redirectSource; force = true; }
  ) eraProjects);
in
{
  imports = [ ../linux-base.nix ];

  home.packages = with pkgs; [
    cliphist
    asciinema
    asciinema-agg
    wl-clipboard
  ];

  home.file = memoryRedirects // {
    ".claude/settings.json" = {
      source = "${dotfiles}/claude/settings.json";
      force = true;
    };
    ".claude/CLAUDE.md" = {
      source = "${dotfiles}/claude/CLAUDE.md";
      force = true;
    };
    ".claude/projects/-home-ted-projects-dal/CLAUDE.md" = {
      source = "${dotfiles}/claude/dal-project.md";
      force = true;
    };
  };
}
