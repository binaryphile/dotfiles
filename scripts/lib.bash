# lib.bash -- shared helpers for dotfiles scripts.
# Source this instead of update-env to avoid coupling to the full bootstrap script.
# Callers must set IFS=$'\n' and set -o noglob before use.

# Naming Policy:
#
# All function and variable names are camelCased.
#
# Private function names begin with lowercase letters.
# Public function names begin with uppercase letters.
# Function names are prefixed with "lib." (always lowercase) so they are namespaced.
#
# Local variable names begin with lowercase letters, e.g. localVariable.
#
# Global variable names begin with uppercase letters, e.g. GlobalVariable.
# Since this is a library, global variable names are also namespaced by suffixing them with
# the randomly-generated letter L, e.g. GlobalVariableL.
# Global variables are not public.  Library consumers should not be aware of them.
# If users need to interact with them, create accessor functions for the purpose.
#
# Variable declarations that are name references borrow the environment namespace, e.g.
# "local -n ARRAY=$1".

# lib.MachineHostname returns the machine's identity hostname.
# On Crostini (HOSTNAME=penguin), reads from persistent mount.
lib.MachineHostname() {
  if [[ ${HOSTNAME:-} == penguin && -e $CrostiniDirL/hostname ]]; then
    cat -- $CrostiniDirL/hostname
    return
  fi
  echo ${HOSTNAME:-}
}

# lib.ValidateHostname rejects invalid or default hostnames.
lib.ValidateHostname() {
  local h=$1
  [[ $h != penguin ]] || { echo "ERROR: hostname is 'penguin'. Set \$CrostiniDir/hostname." >&2; return 1; }
  [[ $h =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "ERROR: invalid hostname '$h'. Must be [a-z0-9][a-z0-9-]*." >&2; return 1; }
}

# lib.ValidSecretName NAME -- returns 0 if NAME is a valid secret filename.
# Policy: alphanumeric start, then alphanumeric/dot/underscore/hyphen.
# No dotfiles, no paths, no leading dashes, no spaces, no unicode.
lib.ValidSecretName() {
  [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]
}

# lib.Glob temporarily enables globbing and nullglob, expands its arguments,
# and prints results newline-separated. Restores prior glob state.
lib.Glob() {
  local nullglobWasOn=0 noglobWasOn=1
  [[ $(shopt nullglob) == *on ]] && nullglobWasOn=1 || shopt -s nullglob
  [[ $- != *f* ]] && noglobWasOn=0 || set +o noglob

  eval "local results=( $* )"

  (( noglobWasOn )) && set -o noglob
  (( nullglobWasOn )) || shopt -u nullglob

  local IFS=$'\n'
  (( ${#results[*]} == 0 )) || echo "${results[*]}"
}

## globals

# CrostiniDirL is the persistent Crostini mount point. Callers may set
# CrostiniDir before sourcing; this provides the default and normalizes
# to the suffixed name.
CrostiniDirL=${CrostiniDir:-/mnt/chromeos/MyFiles/Downloads/crostini}
NL=$'\n'
