#!/bin/bash
cd /home/ted/jeeves
exec nix develop -c npx @playwright/mcp@latest --browser chrome --executable-path /nix/store/fxrbwm6kz68lakv3ksrcygrvpgfcsgwk-chromium-138.0.7204.92/bin/chromium "$@"