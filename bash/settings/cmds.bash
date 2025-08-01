# aliases are turned on for non-interactive as well in lib/initutil.bash

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

Alias validate-bash="source $HOME/dotfiles/bash/lib/validate.bash"

alias l="ls -hF $([[ $OSTYPE == darwin* ]] && echo -G || echo --color=auto)"
Alias ll='l -l'
Alias la='l -la'
Alias ltr='l -ltr'

Alias road='dig +noall +answer'
Alias path="echo \"\${PATH//:/$'\n'}\""
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

new () {
  case $1 in
    cmd ) $EDITOR "$HOME"/dotfiles/bash/${2:+apps/$2/}cmds.bash;;
  esac
}

ainst () {
  reveal "$FUNCNAME"
  sudo bash -c "set -eu; apt update -qq; apt install -y '$1'; apt autoremove"
}
