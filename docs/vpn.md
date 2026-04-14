# VPN setup notes

How `vpn-connect` works on Crostini, why the SAML callback flow is fragile, and what to do if it breaks.

## The stack

1. **`gpauth`** -- Rust binary from yuezk's globalprotect-openconnect (Rust rewrite). Performs SAML auth via an external browser, captures the cookie, prints it to stdout.
2. **`gpclient connect --cookie-on-stdin`** -- reads the cookie, drives `openconnect` (linked in via FFI) to bring up the GP tunnel.
3. **`vpn-slice`** -- passed as `--script` to gpclient/openconnect for split-horizon DNS. Only the named hosts route through the tunnel; everything else stays on the LAN.
4. **`vpn-connect` script** -- reconnect-loop wrapper around the above. Lives at `scripts/vpn-connect`, deployed via the Nix derivation in `contexts/linux-base.nix`.

The Nix derivation substitutes absolute store paths for `@vpn-slice@` and `@gpclient@` because the script invokes them under `sudo`, which strips PATH.

## The SAML callback dance (the tricky part)

`gpauth` does **not** receive the SAML cookie via an HTTP redirect to a localhost server. The actual flow is more elaborate:

1. `gpauth` opens a one-shot HTTP server on a random port (e.g. 44527) at a unique URL like `/<uuid>`. It launches the browser pointing at that URL.
2. The browser hits the URL once. The HTTP server returns the SAML form HTML, then logs `stop the auth server` and shuts down.
3. `gpauth` opens a **separate raw TCP listener** on another random port (e.g. 39115). It writes that port number to **`/tmp/gpcallback.port`**.
4. The browser completes SAML against the IdP. The IdP's success page redirects to a custom URL: **`globalprotectcallback:<base64-encoded-data>`**.
5. The OS sees the `globalprotectcallback://` scheme and looks up its registered handler in the desktop database. The handler is **`gpclient launch-gui %u`**, registered via `gpgui.desktop` with `MimeType=x-scheme-handler/globalprotectcallback`.
6. `gpclient launch-gui` reads `/tmp/gpcallback.port`, opens a TCP socket to `127.0.0.1:<port>`, writes the auth data.
7. `gpauth`'s `wait_auth_data()` accepts the connection, reads the cookie, removes the port file, prints to stdout, exits.
8. Downstream `gpclient connect --cookie-on-stdin` (in our pipeline) reads the cookie and connects.

Source references: `crates/auth/src/browser/browser_auth.rs:140-170` (TCP listener side), `apps/gpclient/src/launch_gui.rs:83-101` (URL scheme handler side).

## The Crostini garcon trap

The `gpgui.desktop` URL scheme handler **must be in `~/.local/share/applications/`** for ChromeOS to find it. Garcon (the ChromeOS<->Crostini bridge) only scans the standard XDG user directory. `~/.nix-profile/share/applications/` is NOT scanned, even though `xdg-mime` inside the container correctly resolves the handler from there.

This is why `home-manager`'s `xdg.desktopEntries` alone is not sufficient on Crostini -- it installs to nix-profile but not to `~/.local/share/applications/`. We additionally use `home.file` with `mkOutOfStoreSymlink` to symlink the desktop entry into the standard location so garcon discovers it.

When this works correctly, host ChromeOS Chrome receiving a `globalprotectcallback://` URL dispatches it to the in-container `gpclient launch-gui`, which connects to the in-container `gpauth` listener over container-localhost, which is reachable from host-localhost via garcon's port forwarding.

## Diagnosing failures

**Symptom: gpauth hangs after "stop the auth server"**

The TCP listener is waiting on `accept()` but no `gpclient launch-gui` ever ran. Check:

1. `cat /tmp/gpcallback.port` -- should exist with a port number
2. `cat /tmp/gpcallback.log` -- does NOT exist means `launch-gui` never ran (URL scheme handler not invoked); EXISTS with errors means `launch-gui` ran but failed to connect
3. `xdg-mime query default x-scheme-handler/globalprotectcallback` -- must return `gpgui.desktop`
4. `ls -la ~/.local/share/applications/gpgui.desktop` -- must exist (this is the garcon discovery path)

**Manual cookie injection** (to test the in-container TCP path independently of the browser):

```bash
PORT=$(cat /tmp/gpcallback.port)
exec 3<>/dev/tcp/127.0.0.1/$PORT
echo -n 'globalprotectcallback:cas-as=1&un=test@example.com&token=fake' >&3
exec 3>&-
```

If gpauth advances past `accept()` and removes `/tmp/gpcallback.port`, the in-container TCP path is sound and the issue is purely browser->handler dispatch.

**Symptom: pipeline exits silently with no cookie and no error**

Probably SIGPIPE. The downstream side of `gpauth | sudo gpclient ...` (e.g., sudo prompting for a password and timing out, or gpclient hitting an early error) closes the read end of the pipe. When gpauth next writes, it gets SIGPIPE and dies. To diagnose, run `gpauth` standalone (no pipe) and capture stdout/stderr to files.

## Known related issues upstream

- yuezk/GlobalProtect-openconnect#439 -- same pattern in KASM Docker, closed WONTFIX. Containers are an unsupported topology for the external-browser callback flow.
- yuezk/GlobalProtect-openconnect#469 -- same pattern in WSL.
- yuezk/GlobalProtect-openconnect#431 -- confirms the manual TCP-injection workaround.
- yuezk/GlobalProtect-openconnect#405 -- generic "external browser callback hangs" with no resolution.

The Crostini case is technically supported (works via the garcon symlink) but it's not documented anywhere upstream. The garcon discovery path was found by experiment in this repo.

## Non-fatal warnings during connection

- `Server asked us to submit HIP report` -- the GP gateway wants a Host Information Profile. openconnect doesn't generate one natively; you'd need a `--csd-wrapper` script. The connection still works without it but may eventually be limited or disconnected.
- `Failed to open /dev/vhost-net` -- vhost-net isn't available in Crostini's kernel. openconnect uses a userspace fallback. Performance hit but functional.
