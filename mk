#!/usr/bin/env bash

Prog=$(basename "$0")   # use the invoked filename as the program name
Version=0.1

read -rd '' Usage <<END
Usage:

  $Prog git-update DIR [DIR...]

  git-update -- if the upstream branch has made progress, git-update rebases the current
  branch on its upstream.
END

## commands (capitalized)

Git-update() {
  (( $# > 0 )) || fatal 'directory required' 2
  echo "$*" |             # quoted to preserve IFS
    keepIf isGitRepo |
    each rebaseIfUpstreamHasProgressed
}

## helpers

# isGitRepo returns whether its argument contains a .git directory.
isGitRepo() { [[ -d $1/.git ]]; }

# isMergeBaseOf returns whether ref2 is the merge-base of ref and ref2.
isMergeBaseOf() {
  local ref=$1 ref2=$2 mergeBase
  mergeBase=$(git merge-base $ref $ref2)
  [[ $mergeBase == "$ref2" ]]
}

# rebaseIfUpstreamHasProgressed rebases a git repository
# if its upstream branch has been updated.
# It runs in a subshell so it can change directory without affecting the caller.
rebaseIfUpstreamHasProgressed() (
  local dir=$1

  cue cd $dir
  cue git fetch

  local ref=$(git rev-parse HEAD)                 || fatal "git rev-parse failed, could not git-update $dir"
  local upstreamRef=$(git rev-parse @{upstream})  || fatal "git rev-parse failed, could not git-update $dir"
  isMergeBaseOf $ref $upstreamRef || cue git rebase $upstreamRef

  echo
)

## globals

## boilerplate

source ~/.local/libexec/mk.bash 2>/dev/null || { echo 'fatal: mk.bash not found' >&2; exit 128; }

# enable safe expansion
IFS=$'\n'
set -o noglob

return 2>/dev/null  # stop if sourced
handleOptions $*    # standard options
main ${*:?+1}
