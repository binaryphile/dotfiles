#!/usr/bin/env bash

# Tests for scripts/saml-host-browser.
#
# Focus is the banner-injection behavior -- the only non-trivial
# logic. The exec'd dispatch targets (garcon-url-handler, firefox)
# are inter-system boundaries and not exercised here. The script's
# `return 2>/dev/null` exits the sourced read before main() runs,
# so functions load without launching anything.

# shellcheck disable=SC1091
source "$PWD/scripts/saml-host-browser"

## fixtures

# samlHtmlFixture writes a canonical PanGPA-shaped saml.html to stdout.
# Body abbreviated -- the only invariant injectBanner depends on is the
# literal `document.getElementById('myform').submit();` auto-submit
# line; the SAMLRequest is preserved verbatim to assert the payload
# survives the edit.
samlHtmlFixture() {
  cat <<'EOF'
<html>
<body>
<form id="myform" method="POST" action="https://example.okta.com/sso/saml">
<input type="hidden" name="SAMLRequest" value="PHNhbWxwOkF1dGhuUmVxdWVzdA==" />
<input type="hidden" name="RelayState" value="abc123" />
</form>
<script>
  document.getElementById('myform').submit();
</script>
</body>
</html>
EOF
}

## tests

# test_injectBanner_addsBannerAndWrapsSubmit verifies the happy path:
# banner div lands after <body>, auto-submit gets wrapped in setTimeout,
# and the SAMLRequest payload is preserved through both sed passes.
test_injectBanner_addsBannerAndWrapsSubmit() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local saml=$Dir/saml.html
  samlHtmlFixture > "$saml"

  injectBanner "$saml"

  tesht.Softly <<'END'
    grep -q 'VPN auth via' "$saml" || tesht.Log 'banner text missing'
    grep -q 'position:fixed' "$saml" || tesht.Log 'banner CSS missing'
    grep -q 'setTimeout(function()' "$saml" || tesht.Log 'submit not wrapped in setTimeout'
    grep -q 'PHNhbWxwOkF1dGhuUmVxdWVzdA==' "$saml" || tesht.Log 'SAMLRequest payload lost'
END
}

# test_injectBanner_bannerPrecedesForm verifies the banner div is
# placed before the form, not after -- so it renders above the auto-
# submitting form during the brief window before navigation.
test_injectBanner_bannerPrecedesForm() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local saml=$Dir/saml.html
  samlHtmlFixture > "$saml"

  injectBanner "$saml"

  local bannerLine formLine
  bannerLine=$(grep -n 'VPN auth via' "$saml" | head -1 | cut -d: -f1)
  formLine=$(grep -n 'id="myform"' "$saml" | head -1 | cut -d: -f1)
  (( bannerLine < formLine )) || {
    echo "banner line $bannerLine should precede form line $formLine"
    return 1
  }
}

# test_injectBanner_formatMismatchLogsAndLeavesFileUnchanged covers
# the future-PanGPA-update case where the auto-submit shape changes.
# The injection should NOT proceed (sed against an unmatched pattern
# would be a silent no-op anyway, but the banner sed would still fire
# and produce a banner-without-delayed-submit -- which renders for an
# imperceptible window. Explicit return is the contract.) Warning
# goes to stderr so it surfaces in `journalctl --user -u gpa.service`.
test_injectBanner_formatMismatchLogsAndLeavesFileUnchanged() {
  local Dir; tesht.MktempDir Dir || return 128
  trap "rm -rf $Dir" RETURN

  local saml=$Dir/saml.html
  cat > "$saml" <<'EOF'
<html><body>
<form id="myform">no auto-submit script present</form>
</body></html>
EOF
  local before; before=$(<"$saml")

  local stderr; stderr=$(injectBanner "$saml" 2>&1 >/dev/null)

  local after; after=$(<"$saml")
  tesht.Softly <<'END'
    [[ $stderr == *"format mismatch"* ]] || tesht.Log "expected format-mismatch warning, got: $stderr"
    [[ $after == "$before" ]] || tesht.Log 'file should not have been modified'
END
}
