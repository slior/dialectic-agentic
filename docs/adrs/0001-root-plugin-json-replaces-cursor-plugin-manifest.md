# ADR 0001: Root `plugin.json` replaces the Cursor plugin manifest

## Status

ACCEPTED — 2026-08-14

## Context

Until 0.1.0, Dialectic shipped as a Cursor plugin. The manifest lived at `.cursor-plugin/plugin.json`. Cursor treats that path as its own plugin format.

Agent Plugins 1.0.0 requires a single manifest at `plugin.json` in the plugin root. The schema is closed. Allowed top-level fields are `$schema`, `name`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, and `extensions`. `$schema` must be exactly `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`.

Cursor detects format from manifest location. A root `plugin.json` means Agent Plugin. `.cursor-plugin/plugin.json` means Cursor Plugin. Cursor's docs do not define what happens if both exist.

Keeping both would put the package in undocumented territory for the client we test against. It would also create two version fields that can drift.

Client-specific data belongs under a reverse-domain namespace (`extensions` in the manifest, or a top-level `com.example.client/` directory). `.cursor-plugin/` is neither.

## Decision

Create `plugin.json` at the repo root. Delete `.cursor-plugin/plugin.json`. Keep exactly one manifest.

Do not keep a Cursor-format manifest beside the portable one. Do not invent a `com.cursor…` extension key; Cursor has not published its reverse-domain namespace, so no client would read it.

The Cursor format supports component types the standard does not: rules, commands, hooks, variables, and `agents/`. This package uses only `agents/`, and only as data files. See [ADR 0002](0002-agents-stay-at-package-root.md). The other loss is the `logo` field, which the closed schema forbids. There is no logo in the repo.

## Consequences

The package is an Agent Plugin, not a Cursor-format plugin. Any conformant client can discover it from the root manifest and the `skills/` tree.

Identity, version, and metadata live in one file. Releases bump one `version`.

Cursor-only component discovery from `.cursor-plugin/` stops. `agents/` is no longer a registered plugin component. Dispatch must not depend on that registration ([ADR 0002](0002-agents-stay-at-package-root.md)).

A marketplace re-index will show a format change. Install flow stays the same, but the change is visible.

A conformant client must reject a missing or wrong `$schema`. It must ignore unknown fields such as `logo`. Adding a listing logo later needs `extensions` (namespace still unpublished) or a return to `.cursor-plugin/plugin.json`, which reopens this decision.
