hm() {
  local config
  config=$(basename "$(readlink ~/dotfiles/context)") || { echo "error: ~/dotfiles/context symlink missing or broken" >&2; return 1; }
  [[ -n $config ]] || { echo "error: could not determine config from context symlink" >&2; return 1; }
  nix run ~/dotfiles#home-manager -- "$@" --flake ~/dotfiles#$config
}
