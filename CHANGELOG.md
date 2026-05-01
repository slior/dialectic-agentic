# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
