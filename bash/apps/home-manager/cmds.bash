hm() {
  local config
  config=$(basename "$(readlink ~/dotfiles/context)")
  nix run ~/dotfiles#home-manager -- "$@" --flake ~/dotfiles#$config
}
