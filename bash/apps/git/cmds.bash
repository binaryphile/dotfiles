Alias ga.='git add .'
Alias gadd='git add'
Alias gafor='git add --force'
Alias gapat='git add --patch'
Alias gbD='git branch -D'
Alias gball='git branch --all'
Alias gbdel='git branch --delete'
Alias gbran='git branch'
Alias gbvv='git branch -vv'
Alias gch-.='git checkout -- .'
Alias gch-='git checkout --'
Alias gchb='git checkout -b'
Alias gchec='git checkout'
Alias gclon='git clone'
Alias gcoam='git commit --amend'
Alias gcoane='git commit --amend --no-edit'
Alias gdcac='git diff --cached'
Alias gdiff='git diff'
Alias gfetc='git fetch'
Alias ginit='git init -b main'
Alias glg='git lg'
Alias glsfi='git ls-files'
Alias gmerg='git merge'
Alias gmeab='git merge --abort'
Alias gmv='git mv'
Alias gpusf='git push --force'
Alias gpull='git pull'
Alias gpush='git push'
Alias gpussu='git push --set-upstream'
Alias gpust='git push --tags'
Alias greba='git rebase'
Alias grebc='git rebase --continue'
Alias grebi='git rebase --interactive'
Alias grebs='git rebase --skip'
Alias grefl='git reflog'
Alias gremv='git remote --verbose'
Alias gresH^='git reset HEAD^'
Alias grese='git reset'
Alias gresh='git reset --hard'
Alias greshH='git reset --hard HEAD'
Alias grm='git rm'
Alias grmfo='git rm --force'
Alias gshop='git show --patch'
Alias gshow='git show'
Alias gstasa='git stash apply'
Alias gstasd='git stash drop'
Alias gstasl='git stash list'
Alias gstassa='git stash save'
Alias gstasshp='git stash show --patch'
Alias gstats='git status --short'

gcome () {
  reveal "$FUNCNAME"
  git commit --message "$JIRA${JIRA:+: }$@"
}

correct () {
  reveal "$FUNCNAME"
  git fetch
  git branch --merged origin/"$1" | grep -v "$1"$ | xargs $([[ $OSTYPE != darwin* ]] && echo -r) git branch -D
}

europe () {
  reveal "$FUNCNAME"
  git add --patch
  git commit -m "${1:-}"
  git push
}

pastel () {
  reveal "$FUNCNAME"
  git checkout -b "$1"
  git push --set-upstream origin "$1"
}

flute () {
  reveal "$FUNCNAME"
  git add .
  git commit --amend
  git push -f
}

wolf () {
  reveal "$FUNCNAME"
  git add .
  git commit -m "${1:-}"
  git push
}
