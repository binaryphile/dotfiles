# Claude Code base configuration (stage 1).
# Era-dependent config (memory redirects, CLAUDE-era.md) deployed by update-env stage 2.
# Imported by both crostini and linux contexts.

{ config, pkgs, ... }:

{
  home.file = {
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
