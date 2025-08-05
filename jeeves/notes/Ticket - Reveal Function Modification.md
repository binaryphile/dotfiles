# Reveal Function Modification

## Issue
Reveal function shows explanatory text like "ll is aliased to 'l -l'" instead of just the command in yellow color.

## Reproduction Steps
1. Run alias command: `ll`
2. Expected: Shows "l -l" in yellow color
3. Actual: Shows "ll is aliased to 'l -l'" in white text

## Current Analysis
**Session: 2025-08-01**

### Root Cause
- Old implementation used `type $1 | sed` which left explanatory text
- Functions showed full definition instead of just name with args
- No color coding applied to output

### Implementation Applied
- Replaced with `type -t "$1"` for command type detection
- Added case handling for aliases, functions, builtins, files
- Applied yellow ANSI color codes `\033[33m` and `\033[0m`
- Maintained stderr output stream

### Testing Results
✅ Toggle test: Confirmed fix is direct cause of behavior change
✅ Alias test: `ll` shows `[33ml -l[0m]` (yellow, no explanatory text)
✅ Function test: `psaux bash` shows `[33mpsaux[0m]` (yellow, no definition)
✅ Builtin test: `cd /tmp` shows `[33mcd /tmp[0m]` (yellow with args)
✅ Integration test: All commands execute correctly after reveal

## Solution
**Status: COMPLETE**
- File modified: `/home/ted/dotfiles/bash/settings/cmds.bash`
- Git commit: `1c3ad9f`
- Pushed to: `origin/main`
- Backup created: `bash/settings/cmds.bash.backup`

New reveal function uses bash-native approach with proper color coding and removes all explanatory text while maintaining compatibility.