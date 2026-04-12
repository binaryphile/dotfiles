# Claude Code project configuration: memory redirects and project CLAUDE.md files.
# Imported by both crostini and linux contexts.

{ config, pkgs, ... }:

let
  inherit (pkgs) lib;

  homeDir = config.home.homeDirectory;

  # Encode an absolute path the way Claude Code does for project directories:
  # /home/ted/projects/dal -> -home-ted-projects-dal
  encodePath = path: builtins.replaceStrings ["/"] ["-"] path;

  # All projects get an Era memory redirect (read-only nix store symlink)
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

  memoryRedirects = lib.listToAttrs (map (dir:
    lib.nameValuePair
      ".claude/projects/${encodePath dir}/memory/MEMORY.md"
      { source = ../claude/era-memory-redirect.md; force = true; }
  ) eraProjects);
in
{
  home.file = memoryRedirects // {
    ".claude/settings.json" = {
      source = ../claude/settings.json;
      force = true;
    };
    ".claude/CLAUDE.md" = {
      source = ../claude/CLAUDE.md;
      force = true;
    };
    ".claude/projects/-home-ted-projects-dal/CLAUDE.md" = {
      source = ../claude/dal-project.md;
      force = true;
    };
    ".claude/projects/-home-ted-projects-urma/CLAUDE.md" = {
      source = ../claude/urma-project.md;
      force = true;
    };
  };
}
