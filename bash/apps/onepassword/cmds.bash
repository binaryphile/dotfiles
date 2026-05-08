# 1Password commands for interactive shells.
# Auto-sourced by init.bash via apps/*/cmds.bash glob.

# verifySigning runs the end-to-end signing chain: unit running -> agent
# socket bound -> agent has identities -> op-ssh-sign produces a signature
# embedded in a real commit. Each stage's failure message identifies the
# broken link; the signing stage retries up to 3 times (2s spacing) to
# cover the post-restart "failed to fill whole buffer" window where the
# agent socket is reachable but op-ssh-sign isn't ready yet.
verifySigning() {
  systemctl --user is-active --quiet 1password.service \
    || { echo 'FAIL: 1password.service not active (systemctl --user status 1password.service)'; return 1; }
  ss -xl | grep -qF .1password/agent.sock \
    || { echo 'FAIL: agent socket not listening (service started but did not bind)'; return 1; }
  SSH_AUTH_SOCK=$HOME/.1password/agent.sock ssh-add -L >/dev/null 2>&1 \
    || { echo 'FAIL: agent has no identities (vault locked OR Settings > Developer > Use the SSH Agent is OFF; try: 1password --quick-access)'; return 1; }
  local dir
  dir=$(mktemp -d --suffix=.signtest)
  trap "rm -rf '$dir'" RETURN
  local i
  for i in 1 2 3; do
    if ( cd "$dir" && rm -rf .git && git init -q && git commit --allow-empty -m verify --quiet ) 2>/dev/null; then
      break
    fi
    [[ $i -lt 3 ]] && sleep 2
  done
  git -C "$dir" cat-file -p HEAD 2>/dev/null | grep -q '^gpgsig -----BEGIN SSH SIGNATURE-----' \
    || { echo 'FAIL: signing did not produce gpgsig after 3 retries (post-restart agent not ready, or signing path broken -- check gpg.ssh.program=op-ssh-sign and that the vault is unlocked)'; return 1; }
  echo OK
}
