# ADR 0003: The package is portable; debates are not

## Status

ACCEPTED — 2026-08-14

## Context

[ADR 0001](0001-root-plugin-json-replaces-cursor-plugin-manifest.md) makes Dialectic an Agent Plugins 1.0.0 package. Any conformant client can discover and load it. That is a real claim. It is easy to overstate.

Agent Plugins standardizes packaging, discovery, MCP configuration, and failure isolation. It does not standardize subagent dispatch. This system is built on dispatch. Every proposal, critique, refinement, clarification, and judge invocation is a dispatched subagent. A skills-only client will load the plugin, show both skills, then fail mid-run.

A second gap is self-location. Phase 0.0 sets `PROJECT` from the absolute path of `SKILL.md`. Nothing in the spec requires a client to expose that path to a skill. `PLUGIN_ROOT` exists in §9.1, but only for stdio MCP subprocesses. This package has no `mcp.json`. Its skills are not subprocesses. That guarantee does not reach them.

`compatibility` is part of the same claim. A conformant client shows it to explain what a skill needs. Both skills used to say they require Cursor. On any other conformant client, that reads as "unusable here."

## Decision

Every user-facing sentence about the standard states that the *package* conforms and loads portably. It names the two client capabilities a debate needs: subagent dispatch, and a way to know the plugin root. No document claims that any conformant client can run a debate.

Do not drop the portability claim. The package is conformant. Overclaiming and underclaiming are both wrong. The fix is precision.

Skill `compatibility` names capabilities, not a product. `orchestrate` requires a client that can dispatch subagents, plus the payload beside the skill (`prompts/`, `agents/`, `debate-config.json`). Both skills accept `PROJECT=<plugin root>` when the client does not expose the skill's own path. The judge does not dispatch subagents. It does not read `debate-config.json`. Its config arrives through `CONFIG`.

## Consequences

Docs (`AGENTS.md`, `README.md`, `docs/development.md`, `CHANGELOG.md`) distinguish loading from running. Readers should not expect a debate to work in every client that can install the plugin.

Cursor remains the first-class target. On a client that does not pass the skill path, the user must pass `PROJECT` explicitly. The skills already support that fallback.

`compatibility` no longer names Cursor. On another conformant client, the metadata explains what is missing instead of declaring the skill unusable.

The judge can run standalone. It only reads and writes files. It needs the prompt payload and `CONFIG`. It does not need a dispatch-capable client of its own.

Future portability work can build on a true packaging claim. It must still solve dispatch and skill self-location. Those are outside this standard.
