# probe-lib.bash — shared probe logic for tmux panel and waybar
# widget-status. Sourced by both rendering scripts.
#
# Caller must set $State to a writable directory before sourcing
# (e.g., $XDG_RUNTIME_DIR/panel for tmux, /tmp/waybar-health for
# waybar). All cached state lives under $State.
#
# Naming follows the project bash style guide (see
# ~/projects/task.bash/update-env header): camelCase functions and
# variables, lowercase first letter for locals, uppercase first
# letter for globals.

# isStale returns true if the state file is missing or older than
# $ttl seconds. Used to gate background refreshes.
isStale() {
  local file=$1
  local ttl=$2
  [[ ! -e $file ]] && return 0
  local mtime now
  mtime=$(stat -c %Y "$file" 2>/dev/null) || return 0
  now=$(date +%s)
  (( (now - mtime) >= ttl ))
}

# refresh runs a probe in the background if the cache key is stale,
# capturing the probe's stdout into $State/$key via atomic mv. Probe
# is invoked as `cmd args...`; the first two args are the key and TTL.
refresh() {
  local key=$1
  local ttl=$2
  shift 2
  if isStale "$State/$key" "$ttl"; then
    (
      cls=$("$@" 2>/dev/null) || cls=unknown
      printf '%s' "$cls" > "$State/$key.tmp" && mv "$State/$key.tmp" "$State/$key"
    ) &
    disown
  fi
}

# readState returns the cached value for a key, or "unknown".
readState() {
  local key=$1
  local file=$State/$key
  if [[ -e $file ]]; then
    cat "$file"
  else
    echo unknown
  fi
}

# vpnUp returns true if the VPN tunnel interface exists.
vpnUp() { ip link show tun0 >/dev/null 2>&1; }

# pingHost is a fast TCP-port-443 reachability check (ICMP is
# unreliable because most vendor sites block it). Returns ok or fail.
# On fail, also invalidates the cached SSH success for the widget so
# the state cannot return to "active" without a fresh SSH probe —
# implements the "stay active so long as ping is succeeding" contract.
# Args: state-key-prefix host
pingHost() {
  local key=$1
  local host=$2
  if timeout 3 bash -c "exec 3<>/dev/tcp/$host/443" 2>/dev/null; then
    echo ok
  else
    echo fail > "$State/${key}-ssh.tmp" \
      && mv "$State/${key}-ssh.tmp" "$State/${key}-ssh"
    echo fail
  fi
}

# sshHost tests git-over-ssh reachability. Returns ok if the server
# responds (rc 0/1 or "shell request failed" — both indicate the SSH
# layer is up regardless of git permissions), fail otherwise.
sshHost() {
  local host=$1
  local err rc
  err=$(ssh -T -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new \
    "git@$host" 2>&1) && rc=$? || rc=$?
  if (( rc == 0 || rc == 1 )) || grep -q 'shell request failed' <<<"$err"; then
    echo ok
  else
    echo fail
  fi
}

# combine merges per-source results into a single widget class. Rules:
#   - api=down or api=off    → off  (service is down per vendor)
#   - api=degraded/partial   → partial
#   - ping=fail              → off  (network unreachable)
#   - ssh=ok and ping=ok     → on   (fully active)
#   - ping=ok                → partial (reachable but no auth confirmation)
#   - otherwise              → unknown
# Args: ssh-state ping-state [api-state]
combine() {
  local ssh=${1:-unknown}
  local ping=${2:-unknown}
  local api=${3:-on}
  case $api in
    down|off)         echo off;     return ;;
    degraded|partial) echo partial; return ;;
  esac
  [[ $ping == fail ]] && { echo off; return; }
  [[ $ssh  == ok && $ping == ok ]] && { echo on; return; }
  [[ $ping == ok ]] && { echo partial; return; }
  echo unknown
}

# bitbucketApiProbe queries Atlassian's component status API for the
# 'Git via SSH' component (id: qmh4tj8h5kbn). Returns: on, partial, off.
bitbucketApiProbe() {
  local result
  result=$(curl -fs --connect-timeout 3 --max-time 5 \
    https://bitbucket.status.atlassian.com/api/v2/components.json 2>/dev/null \
    | jq -r '.components[] | select(.id == "qmh4tj8h5kbn") | .status' 2>/dev/null) || true
  case $result in
    operational)                          echo on      ;;
    degraded_performance|partial_outage)  echo partial ;;
    *)                                    echo off     ;;
  esac
}

# codebergApiProbe queries the Codeberg uptime status API; component
# 7 is the "Codeberg SSH access" monitor. Returns: on, off.
codebergApiProbe() {
  local result
  result=$(curl -fs --connect-timeout 3 --max-time 5 \
    https://status.codeberg.org/api/status-page/heartbeat/codeberg 2>/dev/null \
    | jq -er '.heartbeatList."7"[-1].status' 2>/dev/null) || true
  case $result in
    1) echo on ;;
    *) echo off ;;
  esac
}

# probeReachability runs the ssh+ping (and optional api) probes for a
# named widget at the standard cadences and prints the combined class.
# Caller is responsible for any VPN-gating check before invoking.
# Args: key host [apiFn]
probeReachability() {
  local key=$1
  local host=$2
  local apiFn=${3:-}
  refresh "${key}-ssh"  600 sshHost  "$host"
  refresh "${key}-ping" 30  pingHost "$key" "$host"
  local ssh ping api
  ssh=$(readState "${key}-ssh")
  ping=$(readState "${key}-ping")
  if [[ -n $apiFn ]]; then
    refresh "${key}-api" 30 "$apiFn"
    api=$(readState "${key}-api")
  else
    api=on
  fi
  combine "$ssh" "$ping" "$api"
}
