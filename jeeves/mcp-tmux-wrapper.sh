#!/bin/bash
# Wrapper script for Claude Code MCP tmux-control server
# Works around the spawn ENOENT bug by providing a single executable

exec node /home/ted/dotfiles/jeeves/mcp-tmux-control.js