# op-run-integrity.bash -- UC-11 detective integrity check.
#
# OpRunIntegrityCheck verifies the op-run launcher, registry, and machine
# allowlist files against committed SHA-256 hashes at
# $DotfilesRoot/op-run/checksums, and verifies that `command -v op-run`
# resolves under /nix/store/.
#
# Both probes emit detective warnings to stderr on mismatch. Shell startup
# is NOT blocked. The control is Detective per
# ~/projects/jeeves/security/threat-model.md "Tamper-evident launcher".
#
# DotfilesRoot defaults to $Root/.. ($Root is the bash/ directory set by
# bash/init.bash). Tests override DotfilesRoot to point at a temp directory.
#
# Skip-silent conditions:
#   - DotfilesRoot unresolvable (no Root, no DotfilesRoot set: bootstrap)
#   - DotfilesRoot/op-run/checksums missing (pre-first-deploy)
#   - op-run not on PATH (not yet installed -- no shadow signal possible)

OpRunIntegrityCheck () {
  local root=${DotfilesRoot:-${Root:+$Root/..}}
  [[ -n $root ]] || return 0  # bootstrap context, neither var set

  local checksums=$root/op-run/checksums
  if [[ -r $checksums ]]; then
    local sumOutput
    if ! sumOutput=$(cd "$root" && sha256sum --check --quiet "$checksums" 2>&1); then
      {
        echo "op-run integrity: hash mismatch in committed sources"
        printf '  %s\n' "$sumOutput"
        echo "  detail: ( cd $root && sha256sum --check op-run/checksums )"
        echo "  see ~/projects/jeeves/security/threat-model.md \"Tamper-evident launcher\""
      } >&2
    fi
  fi

  local opRunPath
  opRunPath=$(command -v op-run 2>/dev/null) || return 0  # not installed

  local resolved
  resolved=$(readlink -f "$opRunPath" 2>/dev/null) || resolved=$opRunPath
  if [[ $resolved != /nix/store/* ]]; then
    {
      echo "op-run integrity: installed op-run is not under /nix/store"
      echo "  command -v op-run: $opRunPath"
      echo "  readlink -f:       $resolved"
      echo "  PATH-shadow or home-manager profile-symlink redirection suspected"
    } >&2
  fi
}
