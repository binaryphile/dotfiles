# probe-lib.bash -- shared probe logic for tmux panel and waybar
# widget-status. Sourced by both rendering scripts.
#
# Caller must set $State to a writable directory BEFORE sourcing
# (e.g., $XDG_RUNTIME_DIR/panel for tmux, /tmp/waybar-health for
# waybar). All cached state lives under $State. The check below
# fails fast with a clear error if the caller forgot -- without it,
# probes silently write to a literal "$State/..." path in the cwd.
#
# Naming follows the project bash style guide (see
# ~/projects/task.bash/update-env header): camelCase functions and
# variables, lowercase first letter for locals, uppercase first
# letter for globals.

# Injectable command variables. Each defaults to the real binary but
# can be overridden by callers (notably tests) to substitute a mock.
# Code below invokes them via `$var ...` expansion so the override is
# transparent. Named lowercase because they exist only to be shadowed
# by locals in test functions (via bash dynamic scope).
timeout=${timeout:-timeout}
ssh=${ssh:-ssh}
curl=${curl:-curl}
jq=${jq:-jq}
ip=${ip:-ip}
grep=${grep:-grep}

if [[ -z ${State:-} ]]; then
  echo "probe-lib.bash: \$State is not set -- caller must set it to a writable directory before sourcing this library" >&2
  return 1 2>/dev/null || exit 1
fi
if [[ ! -d $State ]]; then
  mkdir -p "$State" || {
    echo "probe-lib.bash: cannot create state directory '$State'" >&2
    return 1 2>/dev/null || exit 1
  }
fi

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

# vpnUp returns true if the VPN tunnel interface exists AND its link carrier
# is up. An interface can persist in DOWN state after a tear-down (gpoc
# leaves tun0 around on disconnect; pangp leaves gpd0 around between connect
# cycles). tun0 = gpoc (openconnect); gpd0 = official pangp client.
#
# Probe matches the LOWER_UP flag in the kernel netlink flag set (the bracketed
# <...> field of `ip -o link show`). LOWER_UP indicates the link-layer carrier
# is active: for tun devices that means userspace holds the fd open and is
# passing traffic; for ethernet it's physical carrier sense. The textual
# `state` field is NOT used because tun devices report `state UNKNOWN` (no
# carrier-sense layer to drive the up/down distinction), which previously
# caused this probe to false-negative when pangp's gpd0 was live.
#
# Semantic scope (tasks.dotfiles #27152 F1/F10):
# vpnUp reports INTERFACE-STATE -- userspace endpoint attached to a tun
# device (or ethernet carrier sense). It does NOT prove end-to-end VPN
# USABILITY. A wedged tunnel client that still holds the tun fd will keep
# LOWER_UP asserted while traffic flows nowhere. The widget's design
# intent is interface-state; promotion to usability semantics would
# require a supplementary probe (route reachability, gateway ping, or
# `globalprotect show --status` parse).
#
# Caller surface (the canonical consumers; both must move together if
# either is changed because the function API and the persisted state
# artifact are coupled via the panel's refresh()):
#   - scripts/panel:vpnProbe -- runs the same probe, writes result to
#     $State/vpn for tmux widget rendering
#   - scripts/panel:dm1Module / stashModule / gitlabModule / nexusModule
#     -- call vpnUp directly to gate visibility of VPN-dependent widgets
#   - scripts/panel:popupSummary -- reads $State/vpn to render the popup
#   - nixos-config/scripts/widget-status:vpn -- renders the waybar VPN
#     widget (calls vpnClient for the tooltip's client distinction)
# Anyone reading $State/vpn directly (the persisted artifact) is a
# downstream consumer of this function's semantics; updating one without
# the other will drift them.
vpnUp() {
  [[ $(vpnClient) != offline ]]
}

# vpnClient prints which VPN client owns the active tunnel: "gpoc",
# "pangp", or "offline". Renderers that want the active-client
# distinction in tooltips/status use this; vpnUp's bool predicate
# composes on top. When both interfaces report LOWER_UP (transient
# state during a client switch), gpoc wins by check order.
vpnClient() {
  if $ip -o link show tun0 2>/dev/null | $grep -q LOWER_UP; then
    echo gpoc
  elif $ip -o link show gpd0 2>/dev/null | $grep -q LOWER_UP; then
    echo pangp
  else
    echo offline
  fi
}

# pingHost is a fast TCP-port-443 reachability check (ICMP is
# unreliable because most vendor sites block it). Returns ok or fail.
# On fail, also invalidates the cached SSH success for the widget so
# the state cannot return to "active" without a fresh SSH probe --
# implements the "stay active so long as ping is succeeding" contract.
# Args: state-key-prefix host
pingHost() {
  local key=$1
  local host=$2
  if $timeout 3 bash -c "exec 3<>/dev/tcp/$host/443" 2>/dev/null; then
    echo ok
  else
    echo fail > "$State/${key}-ssh.tmp" \
      && mv "$State/${key}-ssh.tmp" "$State/${key}-ssh"
    echo fail
  fi
}

# sshHost tests git-over-ssh reachability. Returns ok if the server
# responds (rc 0/1 or "shell request failed" -- both indicate the SSH
# layer is up regardless of git permissions), fail otherwise.
sshHost() {
  local host=$1
  local err rc
  err=$($ssh -T -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new \
    "git@$host" 2>&1) && rc=$? || rc=$?
  if (( rc == 0 || rc == 1 )) || $grep -q 'shell request failed' <<<"$err"; then
    echo ok
  else
    echo fail
  fi
}

# combine merges per-source results into a single widget class. Rules:
#   - api=down or api=off    -> off  (service is down per vendor)
#   - api=degraded/partial   -> partial
#   - ping=fail              -> off  (network unreachable)
#   - ssh=ok and ping=ok     -> on   (fully active)
#   - ssh=skip and ping=ok   -> on   (no SSH layer; ping+api sufficient)
#   - ping=ok                -> partial (reachable but no auth confirmation)
#   - otherwise              -> unknown
# Args: ssh-state ping-state [api-state]
#
# Locals are *Cls (class) rather than ssh/ping/api to avoid shadowing
# the injectable globals $ssh, $ping, etc. -- a background fork that
# inherits an empty local $ssh expands `$ssh -T ...` to ` -T ...`,
# producing rc=127 and a false "fail" verdict.
combine() {
  local sshCls=${1:-unknown}
  local pingCls=${2:-unknown}
  local apiCls=${3:-on}
  case $apiCls in
    down|off)         echo off;     return ;;
    degraded|partial) echo partial; return ;;
  esac
  [[ $pingCls == fail ]] && { echo off; return; }
  [[ $sshCls  == ok   && $pingCls == ok ]] && { echo on; return; }
  [[ $sshCls  == skip && $pingCls == ok ]] && { echo on; return; }
  [[ $pingCls == ok ]] && { echo partial; return; }
  echo unknown
}

# bitbucketApiProbe queries Atlassian's component status API for the
# 'Git via SSH' component (id: qmh4tj8h5kbn). Returns: on, partial, off.
bitbucketApiProbe() {
  local result
  result=$($curl -fs --connect-timeout 3 --max-time 5 \
    https://bitbucket.status.atlassian.com/api/v2/components.json 2>/dev/null \
    | $jq -r '.components[] | select(.id == "qmh4tj8h5kbn") | .status' 2>/dev/null) || true
  case $result in
    operational)                          echo on      ;;
    degraded_performance|partial_outage)  echo partial ;;
    *)                                    echo off     ;;
  esac
}

# codebergApiProbe queries the Codeberg uptime status API; monitor
# 1 is "Codeberg.org" (the main site). Returns: on, off.
codebergApiProbe() {
  local result
  result=$($curl -fs --connect-timeout 3 --max-time 5 \
    https://status.codeberg.org/api/status-page/heartbeat/codeberg 2>/dev/null \
    | $jq -er '.heartbeatList."1"[-1].status' 2>/dev/null) || true
  case $result in
    1) echo on ;;
    *) echo off ;;
  esac
}

# digiApiProbe queries the Digi Remote Manager status page (Atlassian
# Statuspage) for the worst component status. Returns: on, partial, off.
# Shared by dm1 and remotemanager widgets.
digiApiProbe() {
  local result
  result=$($curl -fs --connect-timeout 3 --max-time 5 \
    https://status.digi.com/api/v2/components.json 2>/dev/null \
    | $jq -r '[.components[].status] |
      if any(. == "major_outage") then "off"
      elif any(. == "partial_outage" or . == "degraded_performance") then "partial"
      elif all(. == "operational") then "on"
      else "off" end' 2>/dev/null) || true
  case $result in
    on)      echo on      ;;
    partial) echo partial ;;
    *)       echo off     ;;
  esac
}

# Widget metadata. Single source of truth for host names, VPN gating,
# and vendor API probe selection -- both the dotfiles tmux panel and
# the nixos-config waybar widget-status renderer read these. Adding a
# new widget host means editing this file once instead of two.
declare -A WidgetHost=(
  [stash]=stash.digi.com
  [dm1]=dm1.devdevicecloud.com
  [gitlab]=gitlab.drm.ninja
  [nexus]=nexus.digi.com
  [remotemanager]=remotemanager.digi.com
  [bitbucket]=bitbucket.org
  [codeberg]=codeberg.org
  [teams]=teams.microsoft.com
  [ntfy]=ntfy.sh
)
declare -A WidgetVpnGated=(
  [stash]=yes
  [dm1]=yes
  [gitlab]=yes
  [nexus]=yes
)
declare -A WidgetNoSsh=(
  [dm1]=yes
  [nexus]=yes
  [remotemanager]=yes
  # SSH probes (sshHost) removed for the remaining widgets -- were triggering
  # 1Password SSH-agent auth dialogs on every poll. Ping result alone now
  # drives the state (combine treats ssh=skip + ping=ok as "on").
  [stash]=yes
  [gitlab]=yes
  [codeberg]=yes
  [bitbucket]=yes
)
declare -A WidgetApiFn=(
  [bitbucket]=bitbucketApiProbe
  [codeberg]=codebergApiProbe
  [dm1]=digiApiProbe
  [remotemanager]=digiApiProbe
)

# widgetHost prints the configured host for a widget, or empty if
# unknown. Helper so callers don't have to know about the array name.
widgetHost() { printf '%s' "${WidgetHost[$1]:-}"; }

# widgetVpnGated returns true if the widget requires the VPN tunnel.
widgetVpnGated() { [[ ${WidgetVpnGated[$1]:-no} == yes ]]; }

# probeReachability runs the ssh+ping (and optional api) probes for a
# named widget at the standard cadences and prints the combined class.
# Caller is responsible for any VPN-gating check before invoking.
# Args: key host [apiFn]
probeReachability() {
  local key=$1
  local host=$2
  local apiFn=${3:-}
  # *Cls (class) names, not ssh/ping/api -- the latter would shadow
  # the injectable globals $ssh / $ping and refresh's bg subshell
  # would inherit an empty $ssh, breaking sshHost.
  local sshCls pingCls apiCls
  if [[ ${WidgetNoSsh[$key]:-no} == yes ]]; then
    sshCls=skip
  else
    refresh "${key}-ssh"  600 sshHost  "$host"
    sshCls=$(readState "${key}-ssh")
  fi
  refresh "${key}-ping" 30  pingHost "$key" "$host"
  pingCls=$(readState "${key}-ping")
  if [[ -n $apiFn ]]; then
    refresh "${key}-api" 30 "$apiFn"
    apiCls=$(readState "${key}-api")
  else
    apiCls=on
  fi
  combine "$sshCls" "$pingCls" "$apiCls"
}

# probeWidget is a thin wrapper that reads host + apiFn from the
# widget metadata table and calls probeReachability. Most callers
# should use this -- it eliminates the need to repeat the host name
# at each call site.
probeWidget() {
  local key=$1
  local host=${WidgetHost[$key]:-}
  if [[ -z $host ]]; then
    echo "probeWidget: unknown widget '$key'" >&2
    return 1
  fi
  probeReachability "$key" "$host" "${WidgetApiFn[$key]:-}"
}

# probePing runs only the TCP/443 ping probe at a configurable
# cadence. Useful for widgets like teams that don't expose SSH and
# don't have a vendor status API -- just a "is the host reachable"
# check at a slow cadence.
# Args: key host [ttl-seconds]
probePing() {
  local key=$1
  local host=$2
  local ttl=${3:-30}
  refresh "${key}-ping" "$ttl" pingHost "$key" "$host"
  local ping
  ping=$(readState "${key}-ping")
  case $ping in
    ok)   echo on ;;
    fail) echo off ;;
    *)    echo unknown ;;
  esac
}
