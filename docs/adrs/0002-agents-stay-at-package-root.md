# ADR 0002: `agents/` stays at the package root

## Status

ACCEPTED — 2026-08-14

## Context

`agents/role-agent.md` and `agents/role-clarify.md` are internal subagent instructions. The orchestrator reads them by path and uses them for proposal, critique, refinement, and clarification turns.

Agent Plugins 1.0.0 defines two component types: skills and MCP servers. Agents, commands, hooks, and rules are out of scope for v1. `agents/` is invisible to the standard. Invisible is not forbidden. The spec does not restrict other files at the plugin root.

[ADR 0001](0001-root-plugin-json-replaces-cursor-plugin-manifest.md) removes the Cursor manifest. Under the Cursor format, Cursor discovered `agents/*.md` and registered `role-agent` and `role-clarify` as named subagent types. After that change, that registration is likely gone.

Two other placements fail:

- Under `skills/`, every child directory with a `SKILL.md` becomes a user-invocable skill. These files must not be user-invocable.
- Under a client-namespaced directory, every `{PROJECT}/agents/…` path in the skills would break. No client reads that namespace today.

The judge is not in this category. It is a skill at `skills/judge/`. Every conformant client discovers it.

## Decision

Keep `agents/role-agent.md` and `agents/role-clarify.md` at the package root. Treat them as payload, like `prompts/` and `debate-config.json`. Do not move them under `skills/`. Do not move them into a namespaced extension directory.

Dispatch by file contents, not by registered type. Read the instruction file. Pass its text to a general-purpose subagent. Do not assume a client registers `role-agent` or `role-clarify`.

Both dispatch sites matter. `role-clarify` matters more on the default path: `clarifications.enabled` is `true`, so clarification runs before any proposal. Leave the judge dispatch unchanged. It already names `{PROJECT}/skills/judge/SKILL.md`.

## Consequences

`agents/` travels with the package. A conformant client ignores it as a component type. The files do not appear as user skills or slash-commands.

Debates still run if the client never registers those names. The orchestrator must read `{PROJECT}/agents/role-agent.md` and `{PROJECT}/agents/role-clarify.md` and pass the contents through. Critique and refinement inherit the proposal contract.

If dispatch still used a bare type name, the default debate would fail in the clarification phase, before any proposal.

The judge is unaffected. It stays a portable skill. Do not "fix" its dispatch as part of this change.

Layout stays one plugin root. Skills keep resolving payload through `{PROJECT}`.
