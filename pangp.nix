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
# installs there, and the binaries are built assuming that path.
#
# Two PanGPS-enforced gates govern packaging. Only the first is
# characterised; the second is open at tasks.dotfiles #26911.
#
# 1. Directory collocation (verified gate). At every IPC connection,
#    PanGPS reads realpath(/proc/<peer-pid>/exe) and
#    realpath(/proc/self/exe) and requires dirname of each to match.
#    Mismatch -> Error(312) "not from GP folder" + Error(212) close
#    socket. The check makes no reference to the binaries' bytes or
#    signatures. Empirically verified 2026-05-20 (era memory
#    c9dfa3f9e2af): byte-flipping the PanGPS binary in place at /opt
#    keeps PanGPS accepting pristine PanGPA; relocating either binary
#    out of /opt fires Error 312.
#
# 2. autoPatchelf rejection (uncharacterised gate). Even when collocated
#    at /opt, autoPatchelf-built binaries are rejected with a different
#    error path: Error(1322) "App Integrity: Failed to verify PanGPA
#    Signature" + Error(212) close socket. The mechanism behind 1322
#    has NOT been isolated -- autoPatchelfHook rewrites the ELF .interp
#    section and RPATH/RUNPATH in addition to other bytes, so the gate
#    could be (a) a real signature/hash check, (b) an .interp value
#    check, (c) an RPATH origin check, or (d) something else. The
#    targeted single-axis isolation experiment is tracked at
#    tasks.dotfiles #26911.
#
# Misframing to avoid (corrected 2026-06-03): a prior cycle (2026-05-27)
# ran openssl dgst -sha384 -verify against pristine vs autoPatchelf'd
# PanGPA, observed Verified OK vs bad signature, and concluded "PanGPS
# performs an asymmetric SHA-384 integrity check on PanGPA." That
# conclusion was load-bearing but unsupported -- the openssl-dgst
# result only proves the on-disk .sig file matches the binary, not
# that PanGPS uses that signature file at runtime. The verified gate
# is collocation only.
#
# Working architecture (see docs/design.md "pangp packaging" and
# docs/vpn.md "Critical: PanGPS App Integrity check"): keep both PanGPS
# and PanGPA bit-for-bit identical to the .deb-shipped versions, deploy
# them collocated at /opt/paloaltonetworks/globalprotect/ via update-env's
# extractGlobalprotectDebToOptTask. Pristine bytes satisfy gate 1 by
# construction AND sidestep whatever gate 2 actually checks. On NixOS,
# programs.nix-ld.enable=true (in nixos-config/common/configuration.nix)
# supplies a real /lib64/ld-linux-x86-64.so.2 so pristine generic-Linux
# binaries can exec. Crostini uses its native FHS loader; no nix-ld
# needed there.
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
  # NixOS-only PanGPS WON'T pass the collocation gate until a peer
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
    makeWrapper
  ];

  # Keep the .deb-shipped binaries bit-for-bit identical so PanGPS's
  # App Integrity check on PanGPA passes at runtime. Runtime loader is
  # provided by programs.nix-ld on NixOS (set in nixos-config); Crostini
  # has a native FHS /lib64/ld-linux-x86-64.so.2.
  dontPatchELF = true;

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
    # gpd-prepare classifies files by writability: read-only artifacts
    # (libs, certs, scripts, .service files) are symlinked from
    # $PANGP_RO; runtime-mutable artifacts (*.log, *.dat, *.txt) are
    # copied as writable, with nix-store-targeted symlinks for
    # runtime-mutable files actively replaced (the #34261 defect class
    # — PanGPS silently couldn't append to its log because the symlink
    # target was in read-only nix-store). Script extracted to
    # scripts/gpd-prepare for tesht coverage (#34261); install it +
    # wire $PANGP_RO via systemd Environment= so the unit's ExecStartPre
    # finds its source dir at runtime regardless of nix-store rebuild
    # path changes.
    mkdir -p $out/libexec
    install -Dm755 ${./scripts/gpd-prepare} $out/libexec/gpd-prepare

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
# PATH for ExecStartPre — systemd's default service PATH excludes
# coreutils; gpd-prepare needs mkdir/cp/ln/rm/readlink/basename
# (calumny 2026-05-26 failure: "mkdir: command not found").
# PANGP_RO points the script at the .deb source-of-truth subtree;
# changes per nix-store rebuild but the unit is regenerated each
# build, so the path stays consistent with the deployed script.
Environment=PATH=${pkgs.coreutils}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=PANGP_RO=$out/opt/paloaltonetworks/globalprotect
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
