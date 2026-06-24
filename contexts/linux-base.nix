{ config, pkgs, contextName, ... }:

let
  # Path to this context's directory inside the flake source (e.g.,
  # ./crostini, ./desktop). Files that vary per-context are resolved
  # against this prefix so symlink chains stay within the tracked tree
  # and survive flake source materialization (the top-level `context/`
  # selector symlink is gitignored and would otherwise dangle inside
  # the nix store).
  ctxDir = ./. + "/${contextName}";

  mkScriptBin = import ./mkScriptBin.nix { inherit pkgs; };

  # Wrapper around notify-send that also pushes to ntfy.sh, providing
  # phone notifications for any tool that calls notify-send. The wrapper
  # statically references libnotify's notify-send via store path so it
  # does not recurse into itself.
  notify-send-bridge = mkScriptBin {
    name = "notify-send";
    src = ../scripts/notify-send;
    substitutions."notify-send" = "${pkgs.libnotify}/bin/notify-send";
    runtimeInputs = [ pkgs.curl pkgs.coreutils ];
  };

  # Panel sibling files: probe-lib.bash and load-sparkline, installed to
  # a store path so the nix-packaged panel can reference them via @here@
  # substitution. Shared source -- waybar on NixOS sources probe-lib
  # from the dotfiles tree independently.
  panel-lib = pkgs.runCommand "panel-lib" {} ''
    mkdir -p $out
    cp ${../scripts/probe-lib.bash} $out/probe-lib.bash
    cp ${../scripts/load-sparkline} $out/load-sparkline
  '';

  # Panel: tmux status bar renderer. Nix-packaged with runtime deps on
  # PATH and @here@ pointing to panel-lib for probe-lib.bash and
  # load-sparkline. See design.md Status widgets (UC-10).
  panel = mkScriptBin {
    name = "panel";
    src = ../scripts/panel;
    substitutions."here" = "${panel-lib}";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.gnugrep
      pkgs.iproute2
      pkgs.jq
      pkgs.openssh
      pkgs.procps
      pkgs.systemd
    ];
  };

  # op-run: 1Password credential launcher. Wraps `op run` with project-vault
  # compliance and audit. @dotfilesRoot@ is substituted to the live dotfiles
  # path so sourced registry/machine-allowlist files resolve at runtime.
  # See docs/design.md Credential Architecture and UC-11 use cases.
  #
  # _1password-cli is intentionally absent from runtimeInputs. Including it
  # would prepend the store op binary to PATH, bypassing the NixOS security
  # wrapper at /run/wrappers/bin/op. The daemon's SO_PEERCRED check requires
  # egid == onepassword-cli; only the wrapper (setgid onepassword-cli) sets
  # this. The wrapper is on PATH via the NixOS system environment.
  op-run = mkScriptBin {
    name = "op-run";
    src = ../scripts/op-run;
    substitutions."dotfilesRoot" = "${config.home.homeDirectory}/dotfiles";
    runtimeInputs = [ pkgs.git pkgs.jq pkgs.coreutils ];
  };

  # claude-budget: daily token usage warner. Warns at 25/10/5/1% remaining
  # of a self-imposed daily token budget via Claude Code hooks. See UC-13.
  claude-budget = mkScriptBin {
    name = "claude-budget";
    src = ../scripts/claude-budget;
    runtimeInputs = [ pkgs.jq pkgs.coreutils pkgs.util-linux ];
  };

  # Tmux with panel on PATH. Overlaid via symlinkJoin so tmux's status
  # bar commands (#(panel ...)) find the panel binary regardless of the
  # session's PATH state. macOS does not need panel (no headless tmux
  # sessions); it uses plain tmux from shared.nix.
  tmux-with-panel = pkgs.symlinkJoin {
    name = "tmux-with-panel";
    paths = [ pkgs.tmux ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/tmux \
        --prefix PATH : ${pkgs.lib.makeBinPath [ panel ]}
    '';
  };

in
{
  imports = [ ../shared.nix ];

  home.packages = [ pkgs.age claude-budget notify-send-bridge op-run tmux-with-panel ];

  # After switching generations, update the running tmux server's PATH so
  # #(panel ...) status commands resolve the new nix store path. Without
  # this, tmux keeps the stale PATH from when the server started and panel
  # never picks up rebuilt derivations.
  home.activation.updateTmuxPath = config.lib.dag.entryAfter [ "installPackages" ] ''
    if ${pkgs.tmux}/bin/tmux has-session 2>/dev/null; then
      # activation runs at top level, not inside a function -- no `local`
      currentPath=$(${pkgs.tmux}/bin/tmux show-environment -g PATH 2>/dev/null | sed 's/^PATH=//')
      ${pkgs.tmux}/bin/tmux set-environment -g PATH "${panel}/bin:''${currentPath:-$PATH}" || true
      unset -v currentPath
    fi
  '';

  # Stable-config dotfile symlinks. Direct store-path sources -- nix snapshots
  # the file into the store at evaluation, so the runtime symlink is read-only:
  # accidental writes through ~/X cannot mutate the working tree, and the
  # configuration is reproducible from any clean checkout. Active-development
  # artifacts (currently: three Crostini scripts in ~/.local/bin/) use
  # mkOutOfStoreSymlink instead; see docs/design.md "Nix/bash boundary" for the
  # decision rule. Bootstrap-critical files (.bash*, nixpkgs config,
  # home-manager config) stay in update-env so they exist before home-manager
  # runs.
  #
  # Context-switched files (gitconfig, tmux.conf, ssh/config,
  # liquidpromptrc) are sourced via ctxDir so the chain stays inside the
  # tracked tree -- routing through the top-level `~/dotfiles/<file>`
  # selector symlink would dangle in the store because `context/` is
  # gitignored and absent from the flake source snapshot.
  home.file = {
    ".gitignore_global".source = ./../gitignore_global;
    ".tmux.conf".source = ctxDir + "/tmux.conf";
    ".config/liquidprompt/liquid.theme".source = ./../liquidprompt/liquid.theme;
    ".config/liquidpromptrc".source = ctxDir + "/liquidprompt/liquidpromptrc";
    ".ssh/config".source = ctxDir + "/ssh/config";
    ".ssh/authorized_keys".source = ./../ssh/authorized_keys;
    ".ssh/id_ed25519_signing.pub".source = ./../ssh/id_ed25519_signing.pub;
    ".config/ranger/rc.conf".source = ./../ranger/rc.conf;
    ".config/ranger/rifle.conf".source = ./../ranger/rifle.conf;
    ".config/ranger/scope.sh".source = ./../ranger/scope.sh;
  };

  # Git config. Was a static home.file symlink (contexts/<ctx>/gitconfig)
  # until 2026-06-24; the literal path "/home/ted/.nix-profile/bin/op-ssh-sign"
  # baked into the file was host-portable accident — it satisfied via
  # ~/.nix-profile on Crostini (standalone HM) but not on NixOS hosts where
  # HM is integrated and ~/.nix-profile/bin/ is unpopulated. Replacing with
  # programs.git makes the op-ssh-sign path store-bound via
  # ${pkgs._1password-gui}, which works on both contexts and is immune to
  # nix-profile state changes.
  programs.git = {
    enable = true;
    userName = "Ted Lilley";
    userEmail = "ted.lilley@gmail.com";
    aliases = {
      lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(blue)<%an>%Creset' --abbrev-commit --date=relative";
    };
    extraConfig = {
      user.signingkey = "~/.ssh/id_ed25519_signing.pub";
      gpg = {
        format = "ssh";
        ssh.program = "${pkgs._1password-gui}/bin/op-ssh-sign";
      };
      commit.gpgsign = true;
      tag.gpgsign = true;
      core = {
        filemode = false;
        excludesfile = "~/.gitignore_global";
        hooksPath = "~/dotfiles/.githooks";
        mergeoptions = "--no-edit";
        pager = "diff-so-fancy | less --tabs=4 -RFX";
      };
      push.default = "tracking";
      github.user = "binaryphile";
      diff.tool = "vimdiff";
      merge.tool = "vimdiff";
      mergetool = {
        prompt = true;
        vimdiff.cmd = "nvim -d $BASE $LOCAL $REMOTE $MERGED -c '$wincmd -w' -c '$wincmd J'";
      };
      fetch.prune = true;
      color = {
        branch = "auto";
        diff = "auto";
        status = "auto";
      };
      url."git@bitbucket.org:accelecon".insteadOf = "https://bitbucket.org/accelecon";
      pull.ff = "only";
      advice.detachedHead = false;
      init.defaultBranch = "main";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # globalprotectcallback:// dispatched by the browser after SAML auth completes.
      # Without this entry the portal drops the URL and gpauth hangs forever.
      "x-scheme-handler/globalprotectcallback" = [ "gpgui.desktop" ];
      # Preserved from existing ~/.config/mimeapps.list (Claude Code deep links).
      "x-scheme-handler/claude-cli" = [ "claude-code-url-handler.desktop" ];
      # Okta SSO redirects to onepassword:// after SAML auth; without this
      # Firefox opens a blank tab instead of handing off to the 1Password app.
      "x-scheme-handler/onepassword" = [ "1password.desktop" ];
    };
  };

  # Calendar: vdirsyncer syncs ICS from OWA, khal reads it.
  # ICS URL stored in ~/secrets/calendar-ics.url (not committed).
  accounts.calendar = {
    basePath = ".calendars";
    accounts.work = {
      primary = true;
      remote = {
        type = "http";
      };
      local = {
        type = "filesystem";
        fileExt = ".ics";
      };
      vdirsyncer = {
        enable = true;
        collections = null;
        urlCommand = [ "${pkgs.coreutils}/bin/cat" "${config.home.homeDirectory}/secrets/calendar-ics.url" ];
      };
      khal = {
        enable = true;
        type = "calendar";
      };
    };
  };

  programs.vdirsyncer.enable = true;
  services.vdirsyncer.enable = true;
  systemd.user.services.vdirsyncer.Unit.ConditionPathExists = "%h/secrets/calendar-ics.url";

  programs.khal = {
    enable = true;
    locale = {
      local_timezone = "America/New_York";
      default_timezone = "America/New_York";
      timeformat = "%H:%M";
      dateformat = "%Y-%m-%d";
    };
  };

  # Calendar reminders: notify-send at 5min and 1min before events.
  # Phone push happens transparently via the notify-send-bridge wrapper.
  systemd.user.services.khal-notify = {
    Unit.Description = "Calendar event reminder notifications";
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/dotfiles/scripts/khal-notify";
      Environment = [
        "PATH=${pkgs.bash}/bin:${pkgs.khal}/bin:${notify-send-bridge}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin"
        "DISPLAY=:0"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus"
      ];
    };
  };

  systemd.user.timers.khal-notify = {
    Unit.Description = "Calendar event reminder timer";
    Timer = {
      OnCalendar = "*:0/5";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
