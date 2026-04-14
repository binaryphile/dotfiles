# DAL

Read `~/projects/dal/obsidian/DAL_PROJECT_UNDERSTANDING.md` before starting
work. It covers the software stack, config/schema system, feature gating, modem
subsystem, testing, release process, product diversity, and a change impact
checklist.

## Where to look first

| Area | Path |
|---|---|
| Board/product packaging | `vendors/<Vendor>/<Product>/` |
| Digi daemons and schemas | `prop/config/` |
| Upstream/forked packages | `user/` |
| Local patches to upstream | `user/<package>/patches/` |
| Modem backends | `prop/config/modem/modemd/src/backend/` |
| Modem driver scripts | `prop/config/modem/drivers/` |
| Serial daemon | `prop/config/seriald/` |
| Web UI pages | `prop/config/webui/` |
| Build/CI scripts | `bin/` |

Key daemons: **configd** (config persistence/validation), **actiond** (action
script dispatch), **runtd** (manages runt store, exposes over ubus),
**modemd** (cellular modem lifecycle), **linkd** (interface management, SIM
selection), **seriald** (serial port protocols), **firewalld** (firewall rules).

## Change impact checklist

- **Changing a config path?** Check: schema definition, migration entries,
  action.d handlers, CLI display scripts, web UI .page templates, runt
  publication, dal_devtests.
- **Adding a feature to a product?** Check: config.vendor (Kconfig toggle),
  tools/kcheck/product.py (product group), schema Makefile (cpp conditionals).
- **Modifying a modem behavior?** Check: backend code (by chipset vendor),
  driver script (by modem module), netifd proto handler (modemd.sh), runt
  state publication, APN selection, SIM/DSDS handling.
- **Touching an upstream package (user/)?** Check: patches/ directory for
  existing patches, makefile for upstream URL and version pin, whether a
  Digi-maintained fork exists.
- **Changing a daemon's runtime behavior?** Check: action.d scripts that
  trigger it, runt paths it publishes, ubus methods it exposes, CLI/web UI
  that reads its state.

## Key architectural facts

- Foundation is OpenWrt: ubus (IPC), procd (init), netifd (network). Digi's
  proprietary layer lives in `prop/`.
- **runt** publishes state (runt_set/get). **ubus methods** send commands.
- Config changes flow: configd -> action.d -> daemon -> runt -> CLI/web/DRM.
- 309 schema files with versioned migrations. Schema shape is cpp-conditional
  per product.
- Classify a subsystem before changing it: upstream (user/), Digi fork, or
  Digi-owned (prop/).
