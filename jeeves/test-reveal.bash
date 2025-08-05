#!/bin/bash
# Test script for new reveal function

# Source the modified file
source /home/ted/dotfiles/bash/settings/cmds.bash

echo "=== Testing Reveal Function ==="
echo

echo "Test 1: Alias without arguments (ll)"
echo "Expected: Just 'l -l' in yellow on stderr"
echo -n "Actual: "
ll >/dev/null 2>&1 | cat -v  # cat -v to show color codes
echo

echo "Test 2: Alias with arguments (la /tmp)"
echo "Expected: Just 'l -la' in yellow on stderr"
echo -n "Actual: "
la /tmp >/dev/null 2>&1 | cat -v
echo

echo "Test 3: Function (miracle test)"
echo "Expected: Just 'miracle test' in yellow on stderr"
echo "Note: Don't actually run miracle, just test reveal output"
# We'll need to test this carefully
echo

echo "Test 4: Builtin (cd /tmp)"
echo "Expected: Just 'cd /tmp' in yellow on stderr"
# Test carefully without changing directory
echo

echo "Test 5: Non-existent command"
echo "Expected: No output"
type nonexistent 2>&1
echo