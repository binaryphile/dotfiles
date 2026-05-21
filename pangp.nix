# Palo Alto Networks GlobalProtect VPN client -- official proprietary Linux
# release. Packaged here because nixpkgs has no derivation for it (closed
# source, EULA-restricted).
#
# Use case: working VPN against PAN's Prisma Access cloud when the
# open-source yuezk gpoc client is broken (e.g., post-CVE-2026-0257
# cookie-mint changes that broke gpoc since ~2026-05-08; tracked at
# yuezk/GlobalProtect-openconnect#606). The official client keeps working
# because PAN ships it alongside the server-side changes.
#
# Source: the `PanGPLinux-<version>.tgz` archive from PAN's customer
# support portal. The archive contains debs/rpms for multiple arches plus
# install scripts; we extract the amd64 .deb.
#
# Runtime layout: pangp's bundled libwa* libraries dlopen each other via
# absolute paths under /opt/paloaltonetworks/globalprotect/. The .deb
# installs there, and the binaries are built assuming that path. The
# original design kept the /opt/... layout INSIDE $out and used
# autoPatchelfHook to rewrite DT_NEEDED entries to nix-store paths,
# planning to skip the /opt symlink entirely.
#
# That design is broken: PanGPS performs an IPC-peer co-location check
# at PanGPA connect time. It compares the directory of /proc/<peer>/exe
# against the directory of its own /proc/self/exe; if they differ, it
# logs
#   Error( 312): Connected by process not from GP folder, app: <peer>
#   Error( 212): Connected by non-PanGPA. Close socket.
# and rejects. The error text is misleading -- "GP folder" is *PanGPS's
# own directory*, not a hardcoded path; the same rejection fires when
# PanGPS runs from /tmp/gp/.../PanGPS even if the peer's path looks
# canonical. The hash of the binary doesn't matter -- a byte-flipped
# PanGPS (with different SHA-384) in the same directory as PanGPA still
# accepts the connection. (Verified empirically 2026-05-20: byte-flipped
# /opt/.../PanGPS accepted /opt/.../PanGPA; pristine /tmp/gp/.../PanGPS
# rejected /opt/.../PanGPA. See the byte-flip and directory-mismatch
# experiments documented in docs/design.md.)
#
# Practical consequence for nix packaging: autoPatchelfHook's DT_NEEDED
# rewrites are NOT the cause of the rejection per se -- the cause is
# that the autoPatchelf'd PanGPS lives in /nix/store/.../opt/... while
# PanGPA's /opt symlink (or absence thereof) places the peer at a
# different directory. The wedge stays masked as long as a matching pair
# of binaries exists in the same directory; the apt-shipped .deb at
# /opt was that pair until `apt purge globalprotect`.
#
# Working architecture (see docs/design.md "pangp packaging" and
# docs/vpn.md "PanGPS co-location workaround"): place both PanGPS and
# PanGPA into the same /opt/paloaltonetworks/globalprotect/ directory
# (extracted from the .deb by update-env's extractGlobalprotectDebToOptTask),
# and point the systemd units' ExecStart at those /opt paths. The
# Nix-managed systemd unit + scripts stay; only the proprietary binaries
# run from /opt. autoPatchelfHook is preserved here for tooling that may
# still consume the in-store layout (e.g. the bin/PanGPA wrapper).
#
# Cert validation note: pangp's libwa* stack statically links OpenSSL and
# uses bundled CA roots. The system trust store at /etc/ssl/certs is NOT
# consulted. This means MITM-with-custom-CA does not work without binary
# patching libwaapi.so -- relevant if you ever need to debug the wire.

{ pkgs
, src ? throw ''
    pangp.nix: src must be set to the path of PanGPLinux-<version>.tgz
    (downloaded from PAN's customer support portal). Example:
      (import ./pangp.nix { inherit pkgs; src = /path/to/PanGPLinux-6.3.3-c31.tgz; })
  ''
, # Architecture suffix used inside the tarball's deb filenames. The amd64
  # build is bare; aarch64/arm have explicit suffixes.
  arch ? "amd64"
, # Runtime base directory where PanGPS and PanGPA actually live at
  # service-start time. Must match the directory that the .deb is
  # extracted to (Crostini/Debian: /opt/paloaltonetworks/globalprotect,
  # populated by update-env's extractGlobalprotectDebToOptTask). NixOS
  # hosts that don't have a /opt extract should override to a path that
  # exists at switch time -- typically the store layout
  # "$out/opt/paloaltonetworks/globalprotect" if you accept that
  # NixOS-only PanGPS WON'T pass the co-location check until a peer
  # PanGPA also lives there (in practice: NixOS deployment of pangp
  # needs the .deb extracted into the same directory at install time,
  # same as Crostini). See header comment for rationale.
  runtimeBase ? "/opt/paloaltonetworks/globalprotect"
}:

let
  # Tarball naming: GlobalProtect_deb-<version>.deb for amd64,
  # GlobalProtect_deb_<arch>-<version>.deb for non-amd64.
  debSuffix = if arch == "amd64" then "" else "_${arch}";
in
pkgs.stdenv.mkDerivation {
  pname = "globalprotect-linux";
  version = "6.3.3-638"; # tied to the tgz contents; bump when src bumps
  inherit src;

  nativeBuildInputs = with pkgs; [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  # Runtime libs the bundled binaries (PanGPS, PanGPA, etc.) need from the
  # host. PanGPS itself is small and links libpthread/libdl/libstdc++/
  # libgcc_s/libc. libwaapi.so additionally needs libm and the bundled
  # libwa* siblings -- those are colocated and resolved via DT_NEEDED with
  # absolute /opt paths, so we must NOT try to bring them in via Nix; they
  # come from $out/opt/... at runtime (via the /opt symlink).
  buildInputs = with pkgs; [
    stdenv.cc.cc.lib   # libstdc++
    glibc              # libc, libpthread, libdl, libm
  ];

  # The bundled libwa*.so files reference each other by absolute /opt
  # paths. autoPatchelfHook complains about these as "not found" because
  # /opt doesn't exist inside the nix build sandbox. Suppress those
  # specific warnings -- runtime resolution happens via the activation-
  # script symlink documented above.
  autoPatchelfIgnoreMissingDeps = [
    "libwaapi.so.4"
    "libwaheap.so.4"
    "libwalocal.so.4"
    "libwaresource.so"
    "libwautils.so.4"
  ];

  unpackPhase = ''
    runHook preUnpack
    mkdir -p tarball
    tar -xzf $src -C tarball
    debFile=$(ls tarball/GlobalProtect_deb${debSuffix}-*.deb 2>/dev/null | head -1)
    if [ -z "$debFile" ]; then
      echo "pangp.nix: no deb found in tarball matching GlobalProtect_deb${debSuffix}-*.deb" >&2
      ls tarball/ >&2
      exit 1
    fi
    echo "pangp.nix: extracting $debFile"
    mkdir -p deb
    dpkg-deb -x "$debFile" deb
    runHook postUnpack
  '';

  # No build step -- we're repackaging a prebuilt binary distribution.
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    # Mirror the deb's install paths under $out:
    #   $out/opt/paloaltonetworks/globalprotect/  -- binaries + libs (the
    #     internal absolute paths still work once /opt is symlinked here)
    #   $out/share/man/                           -- manpages
    #   $out/bin/globalprotect                    -- convenience symlink
    #     onto the CLI (so it's discoverable via PATH when this derivation
    #     is in home.packages)
    #   $out/share/applications/gp.desktop        -- xdg-mime URI handler
    #     for globalprotectcallback:// (the SAML callback bounce)
    #   $out/lib/systemd/system/gpd.service       -- system daemon unit
    #   $out/lib/systemd/user/gpa.service         -- user agent unit
    mkdir -p $out
    cp -r deb/opt $out/opt
    cp -r deb/usr/share $out/share

    # User-side binaries write GP_HTML/, .GlobalProtect/, etc. directly
    # under getenv("HOME"). Wrap them to redirect HOME to a hidden subdir,
    # so the user agent and CLI no longer dump a `GP_HTML` folder in the
    # actual home directory. PanGPS runs as root via systemd-system, so
    # its HOME=/root is already out of the way and is not wrapped.
    mkdir -p $out/bin
    makeWrapper $out/opt/paloaltonetworks/globalprotect/globalprotect \
      $out/bin/globalprotect \
      --run 'export HOME="''${HOME:?HOME unset; pangp wrapper refuses to default to /.local/share/globalprotect}/.local/share/globalprotect"; mkdir -p "$HOME"'
    makeWrapper $out/opt/paloaltonetworks/globalprotect/PanGPA \
      $out/bin/PanGPA \
      --run 'export HOME="''${HOME:?HOME unset; pangp wrapper refuses to default to /.local/share/globalprotect}/.local/share/globalprotect"; mkdir -p "$HOME"'

    mkdir -p $out/share/applications
    cp $out/opt/paloaltonetworks/globalprotect/gp.desktop $out/share/applications/

    # Systemd unit files hardcode /opt/paloaltonetworks/globalprotect/
    # for ExecStart, ExecStartPre, and WorkingDirectory. Substitute to the
    # nix store path so the units don't require a /opt symlink to function.
    # For gpa.service (USER unit), additionally point ExecStart at the
    # HOME-wrapped $out/bin/PanGPA so the user agent doesn't pollute $HOME.
    # The gp.desktop file's Exec=/usr/bin/globalprotect line is substituted
    # to the wrapped $out/bin/globalprotect for the same reason.
    # The gpd.service ships with WorkingDirectory=/opt/paloaltonetworks/
    # globalprotect, which is read-only in our nix-store layout. PanGPS
    # writes runtime state (HipPolicy.dat, HIP_*_Report.dat, PanGpMPR.dat,
    # PanPPAC_*.dat, pangps.xml, *.log, ipt*.txt) to cwd, so it needs a
    # writable WorkingDirectory.
    #
    # Solution: redirect WorkingDirectory to /var/lib/globalprotect (via
    # StateDirectory=, which systemd creates+chowns root). An ExecStartPre
    # symlinks every read-only file from $out/opt/.../ into that dir so
    # PanGPS can find its static config (license.cfg, cc.cer, scripts,
    # sign/*) while still being able to create state files alongside.
    # The symlink loop is idempotent (skips existing entries), so it's
    # safe across restarts and survives prior state-file creation.
    #
    # We can't use ExecStartPre=/bin/sh -c '...' because nix store paths
    # change every rebuild; bake the script into the derivation and
    # reference its store path from the unit.
    mkdir -p $out/libexec
    cat > $out/libexec/gpd-prepare <<PREPARE_EOF
#! ${pkgs.runtimeShell}
# Pre-flight setup for PanGPS: stage read-only files from the nix store
# into /var/lib/globalprotect (systemd's StateDirectory for gpd.service)
# so PanGPS finds its static config alongside its writable state files.
set -eu
PANGP_RO=$out/opt/paloaltonetworks/globalprotect
STATE_DIR=\$STATE_DIRECTORY
[ -n "\$STATE_DIR" ] || STATE_DIR=/var/lib/globalprotect
mkdir -p "\$STATE_DIR"
cd "\$STATE_DIR"
# Symlink every file shipped by the .deb (libs, certs, scripts, license,
# signatures, sysv-init wrapper, .desktop). Skip if already present so
# we don't overwrite user-modified pangps.xml.
for f in "\$PANGP_RO"/*; do
  name=\$(basename "\$f")
  [ -e "\$name" ] && continue
  ln -s "\$f" "\$name"
done
# Also stage the sign/ subdir contents (signature files).
mkdir -p sign
for f in "\$PANGP_RO"/sign/*; do
  name=\$(basename "\$f")
  [ -e "sign/\$name" ] && continue
  ln -s "\$f" "sign/\$name"
done
# Also handle the pre_exec_gps.sh original behavior (clean stale pidfile).
rm -f /var/run/PanGPS.pid 2>/dev/null || true
PREPARE_EOF
    chmod +x $out/libexec/gpd-prepare

    # Now compose gpd.service. ExecStart points at the /opt PanGPS
    # (staged by update-env's extractGlobalprotectDebToOptTask) so the
    # daemon co-locates with PanGPA (also at /opt). PanGPS performs an
    # IPC peer co-location check; if PanGPS and PanGPA live in different
    # directories, every PanGPA connection is rejected. See header
    # comment above and docs/design.md "PanGPS co-location check".
    #
    # ExecStartPre still runs $out/libexec/gpd-prepare to symlink the
    # nix-store-shipped read-only files (sign/, license.cfg, etc.) into
    # /var/lib/globalprotect. With the /opt extract in place those files
    # are duplicated -- harmless and the staging keeps gpd.service
    # cwd-equivalent across redeploys.
    mkdir -p $out/lib/systemd/system
    cat > $out/lib/systemd/system/gpd.service <<UNIT_EOF
[Unit]
Description=GlobalProtect VPN client daemon (PanGPS)

[Service]
Type=simple
ExecStartPre=$out/libexec/gpd-prepare
ExecStart=${runtimeBase}/PanGPS
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/globalprotect
StateDirectory=globalprotect

[Install]
WantedBy=multi-user.target
UNIT_EOF

    mkdir -p $out/lib/systemd/user
    substitute $out/opt/paloaltonetworks/globalprotect/gpa.service \
      $out/lib/systemd/user/gpa.service \
      --replace-quiet "/opt/paloaltonetworks/globalprotect/PanGPA" "$out/bin/PanGPA" \
      --replace-quiet '/opt/paloaltonetworks/globalprotect' "$out/opt/paloaltonetworks/globalprotect"

    substituteInPlace $out/share/applications/gp.desktop \
      --replace-quiet '/usr/bin/globalprotect' "$out/bin/globalprotect"

    runHook postInstall
  '';

  # Expose runtimeBase so the home-manager module (contexts/pangp.nix)
  # can use the same path in its systemd.user.services.gpa ExecStart
  # without duplicating the literal. PanGPS and PanGPA must co-locate;
  # both ExecStart lines need to agree on the directory.
  passthru = { inherit runtimeBase; };

  meta = with pkgs.lib; {
    description = "Palo Alto Networks GlobalProtect VPN client (proprietary Linux build)";
    homepage = "https://www.paloaltonetworks.com/sase/globalprotect";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    maintainers = [ ];
  };
}
