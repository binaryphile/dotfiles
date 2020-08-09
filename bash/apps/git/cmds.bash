Ralias ga.='git add .'
Ralias gadd='git add'
Ralias gafor='git add --force'
Ralias gapat='git add --patch'
Ralias gbD='git branch -D'
Ralias gball='git branch --all'
Ralias gbdel='git branch --delete'
Ralias gbran='git branch'
Ralias gbvv='git branch -vv'
Ralias gch-.='git checkout -- .'
Ralias gch-='git checkout --'
Ralias gchb='git checkout -b'
Ralias gchec='git checkout'
Ralias gclon='git clone'
Ralias gcoam='git commit --amend'
Ralias gcoane='git commit --amend --no-edit'
Ralias gcome='git commit --message'
Ralias gdcac='git diff --cached'
Ralias gdiff='git diff'
Ralias gfetc='git fetch'
Ralias ginit='git init'
Ralias glg='git lg'
Ralias glsfi='git ls-files'
Ralias gmerg='git merge'
Ralias gmeab='git merge --abort'
Ralias gmv='git mv'
Ralias gpusf='git push --force'
Ralias gpull='git pull'
Ralias gpush='git push'
Ralias gpussu='git push --set-upstream'
Ralias gpust='git push --tags'
Ralias greba='git rebase'
Ralias grebc='git rebase --continue'
Ralias grebi='git rebase --interactive'
Ralias grebs='git rebase --skip'
Ralias grefl='git reflog'
Ralias gremv='git remote --verbose'
Ralias gresH^='git reset HEAD^'
Ralias grese='git reset'
Ralias gresh='git reset --hard'
Ralias greshH='git reset --hard HEAD'
Ralias grm='git rm'
Ralias grmfo='git rm --force'
Ralias gshop='git show --patch'
Ralias gshow='git show'
Ralias gstasa='git stash apply'
Ralias gstasd='git stash drop'
Ralias gstasl='git stash list'
Ralias gstassa='git stash save'
Ralias gstasshp='git stash show --patch'
Ralias gstats='git status --short'

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
