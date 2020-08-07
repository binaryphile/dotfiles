shopt -s expand_aliases   # enable aliases even when non-interactive

# reveal shows the function/alias definition on stderr
reveal () {
  type $1 | sed -e "s|reveal $1; ||" -e '/reveal "$FUNCNAME";/d' | grep --color . >&2
}

# ralias aliases with reveal
ralias () {
  local name=${1%%=*}
  local cmd=${1#*=}

  alias $name="reveal $name; $cmd"
}
FUNCTIONS+=( ralias )

ralias validate-bash="source $HOME/dotfiles/bash/validate/validate.bash"

alias ls="ls -hF --group-directories-first $([[ $OSTYPE == darwin* ]] && echo -G || echo --color=auto)"
ralias ll='ls -l'
ralias la='ls -la'
ralias ltr='ls -ltr'

ralias road='dig +noall +answer'
ralias path="echo \"\${PATH//:/$NL}\""
ralias df='df -x squashfs -x tmpfs'

# miracle sets up ssh agent forwarding for an account you sudo to
miracle () {
  reveal "$FUNCNAME"
  setfacl -m "$1":rw "$SSH_AUTH_SOCK"
  setfacl -m "$1":x "$(dirname "$SSH_AUTH_SOCK")"
  sudo -u "$1" SSH_AUTH_SOCK="$SSH_AUTH_SOCK" bash -c 'cd; exec bash -l'
}

# become switches users
become () {
  reveal "$FUNCNAME"
  sudo -Hu "$1" bash -c 'cd; exec bash -l'
}

# runas runs a command as another user
runas () {
  reveal "$FUNCNAME"
  sudo -u "$1" bash -l -c "$2"
}

psaux () {
  reveal "$FUNCNAME"
  pgrep -f "$@" | xargs ps -fp 2>/dev/null
}
