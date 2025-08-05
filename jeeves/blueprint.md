# Phase 3: FINAL VERIFICATION AND COMMIT - Detailed Procedure

## Objective
Perform final verification of the reveal function implementation and commit the changes to git repository with proper documentation.

## Prerequisites
- Completed implementation of new reveal function
- Backup file exists at `/home/ted/dotfiles/bash/settings/cmds.bash.backup`
- All test documentation completed

## Step-by-Step Procedure

### Step 1: Perform Toggle Test (Rule 9 Verification)
This verifies that our fix is the actual cause of the behavior change.

1. Start a new bash session to ensure clean environment:
   ```bash
   bash --login
   ```

2. Test current (new) behavior:
   ```bash
   # Test an alias
   ll 2>&1 | grep -E '\033'  # Should show yellow color codes
   # Note the exact output
   ```

3. Temporarily revert to old behavior:
   ```bash
   cp /home/ted/dotfiles/bash/settings/cmds.bash.backup /home/ted/dotfiles/bash/settings/cmds.bash
   source /home/ted/dotfiles/bash/settings/cmds.bash
   ```

4. Test old behavior:
   ```bash
   # Test same alias
   ll 2>&1 | head -1  # Should show "ll is aliased to 'l -l'"
   # Confirm old behavior returned
   ```

5. Restore new implementation:
   ```bash
   # Exit current shell and restore file
   exit
   cp /home/ted/dotfiles/bash/settings/cmds.bash.backup /home/ted/dotfiles/bash/settings/cmds.bash
   # Re-apply the fix by editing the file again
   ```

6. Document toggle test results in a new file:
   ```bash
   touch /home/ted/dotfiles/jeeves/reveal-toggle-test.md
   ```

### Step 2: Full Integration Test
Test in a complete dotfiles environment to ensure no side effects.

1. Start fresh bash session:
   ```bash
   bash --login
   ```

2. Test complete functionality:
   ```bash
   # Test various aliases
   ll          # Should show yellow "l -l" then list files
   la /tmp     # Should show yellow "l -la" then list /tmp
   ltr         # Should show yellow "l -ltr" then list by time
   
   # Test a function (carefully)
   # Note: Don't run miracle/become, just observe reveal output
   type psaux  # Verify function exists
   # If safe to test: psaux bash
   
   # Test builtin
   type cd     # Verify it's a builtin
   # Test reveal with: cd /tmp (but stay in current dir)
   ```

3. Check for any errors or unexpected behavior:
   - Verify no error messages appear
   - Confirm aliases still execute correctly after reveal
   - Ensure color output is visible and correct

### Step 3: Re-implement the Fix
Since we need to restore the new implementation after the toggle test:

1. Edit the file to restore new reveal function:
   ```bash
   # Use the same implementation from Phase 2
   ```

2. The exact implementation to restore:
   ```bash
   # reveal shows the function/alias definition on stderr
   reveal () {
     local cmd_type=$(type -t "$1" 2>/dev/null)
     local output=""
     
     case "$cmd_type" in
       alias)
         # Get the alias definition
         local alias_def=$(alias "$1" 2>/dev/null)
         # Extract command between single quotes
         if [[ "$alias_def" =~ \'(.+)\' ]]; then
           output="${BASH_REMATCH[1]}"
           # Remove "reveal $1; " prefix if present
           output="${output#reveal $1; }"
         fi
         ;;
       function|builtin|file)
         # For functions, builtins, and files, just show the command with args
         output="$*"
         ;;
       *)
         # Unknown type or not found - no output
         return 0
         ;;
     esac
     
     # Output in yellow to stderr
     if [[ -n "$output" ]]; then
       echo -e "\033[33m${output}\033[0m" >&2
     fi
   }
   ```

### Step 4: Prepare for Git Commit
1. Check git status:
   ```bash
   cd /home/ted/dotfiles
   git status
   ```

2. Review the changes:
   ```bash
   git diff bash/settings/cmds.bash
   ```

3. Stage the change:
   ```bash
   git add bash/settings/cmds.bash
   ```

### Step 5: Create the Commit
1. Create a descriptive commit message:
   ```bash
   git commit -m "Update reveal function to show only command in yellow

   - Remove 'is aliased to' explanatory text from alias output
   - Show only function name with args instead of full definition
   - Add yellow ANSI color codes to all output
   - Maintain stderr output and argument handling
   
   The reveal function now displays just the actual command being
   executed in yellow, making the output cleaner and more focused.
   
   🤖 Generated with Claude Code
   
   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

### Step 6: Verify Commit
1. Check commit was created:
   ```bash
   git log -1 --oneline
   ```

2. Verify changes are committed:
   ```bash
   git status  # Should show clean working tree
   ```

### Step 7: Push to Repository
1. Push the changes:
   ```bash
   git push origin main
   ```

2. Verify push succeeded:
   ```bash
   git status
   # Should show "Your branch is up to date with 'origin/main'"
   ```

### Step 8: Final Documentation
Create a summary of the entire change in `/home/ted/dotfiles/jeeves/reveal-function-change-summary.md`:

1. What was changed and why
2. Test results summary
3. Any known issues or limitations
4. Date and commit hash

## Completion Criteria
This phase is complete when:
1. Toggle test confirms our fix is the cause of the behavior change
2. Full integration test shows no side effects
3. Changes are committed with descriptive message
4. Changes are pushed to remote repository
5. Final documentation is created

## IMPORTANT: Stop for Consultation
**DO NOT PROCEED WITH ANY FURTHER CHANGES**. Once this commit phase is complete:
1. Report the commit hash and push status
2. Stop and wait for user input
3. The task is now complete unless the user requests additional modifications

This ensures the changes are properly version controlled and the user can verify the deployment.