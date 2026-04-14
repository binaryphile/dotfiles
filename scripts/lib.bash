# lib.bash -- shared helpers for dotfiles scripts.
# Source this instead of update-env to avoid coupling to the full bootstrap script.

# machineHostname returns the machine's identity hostname.
# On Crostini (HOSTNAME=penguin), reads from persistent mount.
machineHostname() {
  if [[ "${HOSTNAME:-}" == penguin && -e "$CrostiniDir/hostname" ]]; then
    cat -- "$CrostiniDir/hostname"
    return
  fi
  echo "${HOSTNAME:-}"
}

# validateHostname rejects invalid or default hostnames.
validateHostname() {
  local h=$1
  [[ $h != penguin ]] || { echo "ERROR: hostname is 'penguin'. Set \$CrostiniDir/hostname." >&2; return 1; }
  [[ $h =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "ERROR: invalid hostname '$h'. Must be [a-z0-9][a-z0-9-]*." >&2; return 1; }
}

# validSecretName NAME -- returns 0 if NAME is a valid secret filename.
# Policy: alphanumeric start, then alphanumeric/dot/underscore/hyphen.
# No dotfiles, no paths, no leading dashes, no spaces, no unicode.
validSecretName() {
  [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]
}

# glob helper (from update-env)
glob() {
  local nullglobWasOn=0 noglobWasOn=1
  [[ $(shopt nullglob) == *on ]] && nullglobWasOn=1 || shopt -s nullglob
  [[ $- != *f* ]] && noglobWasOn=0 || set +o noglob

  eval "local results=( $* )"

  (( noglobWasOn )) && set -o noglob
  (( nullglobWasOn )) || shopt -u nullglob

  local IFS=$'\n'
  (( ${#results[*]} == 0 )) || echo "${results[*]}"
}

# Globals needed by helpers
CrostiniDir=${CrostiniDir:-/mnt/chromeos/MyFiles/Downloads/crostini}
NL=$'\n'
