shopt -s expand_aliases   # enable aliases even when non-interactive

# reveal shows the function/alias definition on stderr
reveal () {
  type $1 | sed -e "s|reveal $1; ||" -e '/reveal "$FUNCNAME";/d' | grep --color . >&2
}

Alias validate-bash="source $HOME/dotfiles/bash/validate/validate.bash"

alias l="ls -hF $([[ $OSTYPE == darwin* ]] && echo -G || echo --color=auto)"
Alias ll='l -l'
Alias la='l -la'
Alias ltr='l -ltr'

Alias road='dig +noall +answer'
Alias path="echo \"\${PATH//:/$Nl}\""
Alias df='df -x squashfs -x tmpfs'

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
