# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] — 2026-08-14
### Added
- Root `plugin.json` manifest conforming to the [Agent Plugins](https://agent-plugins.org)
  specification v1.0.0, so any client implementing the standard can discover and load the
  package unmodified. Running a debate additionally requires a client that can dispatch
  subagents, which the standard does not define.
- Plugin-root assertion in `skills/orchestrate/scripts/create-debate-config.sh`: it now fails
  with a diagnostic naming the resolved root instead of reporting a missing prompts directory.
- `docs/development.md`: a "Validate the package" section with the manifest, skill, and config
  generator checks to run before a release.

### Changed
- The manifest moved from `.cursor-plugin/plugin.json` to the root `plugin.json`. Dialectic is
  now an Agent Plugin rather than a Cursor-format plugin. `agents/`, `prompts/`, and
  `debate-config.json` still ship with the package; the skills read them through their
  resolved plugin-root paths.
- Both role-agent dispatch sites state the contract explicitly: read `agents/role-agent.md`
  (`references/debate-loop.md`) or `agents/role-clarify.md` (`references/clarify-phase.md`) and
  pass the file's contents to a general-purpose subagent, rather than relying on a
  client-registered agent type. `agents/` is not a component type in the standard, so clients
  are not expected to register it. The judge is unaffected — it is a skill under `skills/`.
- The `compatibility` metadata on both skills now names the capability each one needs instead
  of naming a specific client: `orchestrate` requires a client that can dispatch subagents,
  and both skills accept `PROJECT=<plugin root>` on clients that do not expose a skill's own
  path. The judge no longer claims to need subagent dispatch or `debate-config.json`; it needs
  neither.

### Fixed
- `skills/orchestrate/scripts/create-debate-config.sh` resolved the plugin root one directory
  too high (`../../../..` from `skills/orchestrate/scripts/`). Role discovery looked for
  `prompts/` outside the package, so the script always exited with "No available roles were
  found". It now resolves `../../..`.

## [0.1.0] — 2026-05-01
### Added
- Initial Cursor Marketplace release of the Dialectic plugin.
- Self-location Phase 0.0 in `orchestrate` and `judge` skills so installed-plugin
  users no longer need to supply a `PROJECT` parameter.
- Plugin manifest at `.cursor-plugin/plugin.json`.
- Repo layout aligned with Cursor plugin conventions: `skills/`, `agents/`,
  shared `prompts/` at the repo root.
- `LICENSE` (MIT), `CHANGELOG.md`.

### Changed
- `clarify` is now an internal reference under `skills/orchestrate/references/`
  instead of a top-level skill (it is always executed inline by the orchestrator,
  not dispatched as a subagent).
- `role-agent` and `role-clarify` moved under `agents/` as single-file subagent
  definitions (they are never user-invocable).
- The interactive config generator's CLI path changed from
  `scripts/create-debate-config.sh` to
  `skills/orchestrate/scripts/create-debate-config.sh`. (The old top-level
  wrapper was removed; the canonical script that did the real work is preserved
  at the new path.)

### Preserved
- Legacy clone-and-reference flow: users who supply `PROJECT=/abs/path`
  continue to work exactly as before.
