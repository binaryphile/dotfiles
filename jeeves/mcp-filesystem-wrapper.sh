#!/bin/bash
# Wrapper script for Claude Code MCP filesystem server
# Works around the spawn ENOENT bug by providing a single executable

cd ~/urma-next
exec nix develop --command npx -y @modelcontextprotocol/server-filesystem .