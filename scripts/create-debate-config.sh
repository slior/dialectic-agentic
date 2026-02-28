#!/usr/bin/env sh

set -eu

# Ensure zsh behaves like POSIX sh when invoked as `zsh script.sh`.
if [ -n "${ZSH_VERSION:-}" ]; then
  emulate -L sh
  setopt SH_WORD_SPLIT
fi

# Resolve project paths from script location.
PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PROMPTS_DIR="$PROJECT_ROOT/prompts"

# Canonical tool names used in generated config and hints.
TOOL_NAME_WEB_SEARCH="Web Search"
TOOL_NAME_FILE_READ="file_read"

# Static defaults that mirror the repository debate config template.
DEFAULT_CRITERIA="Proposals have converged when the refinements across agents are substantially aligned, no agent is raising fundamental unresolved objections, and the solution is comprehensive enough to act on."
DEFAULT_TOOLS_WEB_SEARCH_DESC="Search the web for documentation, benchmarks, RFCs, and current best practices"
DEFAULT_TOOLS_FILE_READ_DESC="Read files from the context/ directory or previous round contributions from the debate/ directory"

DEFAULT_AGENTSCONFIG_SEC_HINT="Use ${TOOL_NAME_WEB_SEARCH} to look up CVE databases, OWASP documentation, and known vulnerabilities relevant to the problem."
DEFAULT_AGENTSCONFIG_ARCH_HINT="Use ${TOOL_NAME_WEB_SEARCH} to find reference architectures and real-world implementations of patterns you propose."
DEFAULT_AGENTSCONFIG_PERF_HINT="Use ${TOOL_NAME_WEB_SEARCH} to find real benchmark data and latency/throughput figures relevant to your recommendations."

trim() {
  value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

json_escape() {
  # Minimal JSON escaping for strings we interpolate into output.
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g'
}

normalize_role() {
  # Normalize user-provided role into an ID-safe token.
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9_-]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}

is_positive_int() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    0) return 1 ;;
    *) return 0 ;;
  esac
}

is_non_negative_int() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

is_threshold() {
  # Accept decimal values in [0,1].
  awk -v v="$1" 'BEGIN { exit !(v+0==v && v>=0 && v<=1) }'
}

prompt_with_default() {
  prompt="$1"
  default="$2"
  # Prompt on stderr so command substitution captures only the answer.
  printf "%s [%s]: " "$prompt" "$default" >&2
  IFS= read -r input || true
  input="$(trim "$input")"
  if [ -z "$input" ]; then
    printf '%s' "$default"
  else
    printf '%s' "$input"
  fi
}

prompt_int() {
  prompt="$1"
  default="$2"
  allow_zero="$3"
  while :; do
    value="$(prompt_with_default "$prompt" "$default")"
    if [ "$allow_zero" = "yes" ]; then
      if is_non_negative_int "$value"; then
        printf '%s' "$value"
        return 0
      fi
    else
      if is_positive_int "$value"; then
        printf '%s' "$value"
        return 0
      fi
    fi
    printf 'Please enter a valid integer%s.\n' "$( [ "$allow_zero" = "yes" ] && printf ' (0 or greater)' || printf ' (1 or greater)' )" >&2
  done
}

prompt_threshold() {
  prompt="$1"
  default="$2"
  while :; do
    value="$(prompt_with_default "$prompt" "$default")"
    if is_threshold "$value"; then
      printf '%s' "$value"
      return 0
    fi
    printf 'Please enter a numeric threshold between 0 and 1.\n' >&2
  done
}

prompt_yes_no() {
  prompt="$1"
  default="$2"
  while :; do
    printf "%s [%s]: " "$prompt" "$default" >&2
    IFS= read -r input || true
    # Reuse normalize_role so variants like YES/Yes/ yes are handled.
    input="$(normalize_role "$(trim "$input")")"
    if [ -z "$input" ]; then
      input="$default"
    fi
    case "$input" in
      y|yes|true|1) printf 'true'; return 0 ;;
      n|no|false|0) printf 'false'; return 0 ;;
      *) printf 'Please answer yes or no.\n' >&2 ;;
    esac
  done
}

list_roles() {
  if [ ! -d "$PROMPTS_DIR" ]; then
    return 0
  fi
  # Discover roles dynamically from prompts/* directories.
  for dir in "$PROMPTS_DIR"/*; do
    [ -d "$dir" ] || continue
    role="$(basename "$dir")"
    [ "$role" = "shared" ] && continue
    [ -f "$dir/system.md" ] || continue
    printf '%s\n' "$role"
  done | sort
}

get_role_count() {
  role_key="$1"
  var_name="ROLE_COUNT_$(printf '%s' "$role_key" | tr '[:lower:]-' '[:upper:]_')"
  # Dynamic variable lookup for per-role numbering, e.g. ROLE_COUNT_ARCHITECT.
  eval "printf '%s' \"\${$var_name:-0}\""
}

increment_role_count() {
  role_key="$1"
  var_name="ROLE_COUNT_$(printf '%s' "$role_key" | tr '[:lower:]-' '[:upper:]_')"
  current="$(get_role_count "$role_key")"
  current=$((current + 1))
  # Persist updated per-role counter.
  eval "$var_name=$current"
  printf '%s' "$current"
}

select_role() {
  prompt="$1"
  default_role="$2"
  available_roles="$3"

  printf '%s\n' "Available roles:" >&2
  idx=1
  IFS='
'
  for role in $available_roles; do
    printf '  %s) %s\n' "$idx" "$role" >&2
    idx=$((idx + 1))
  done
  unset IFS

  while :; do
    if [ -n "$default_role" ]; then
      value="$(prompt_with_default "$prompt (role name or number)" "$default_role")"
    else
      printf '%s: ' "$prompt (role name or number)" >&2
      IFS= read -r value || true
      value="$(trim "$value")"
    fi

    if [ -z "$value" ]; then
      printf 'Role is required.\n' >&2
      continue
    fi

    # Support either typed role name or numeric menu selection.
    case "$value" in
      *[!0-9]*)
        chosen="$(normalize_role "$value")"
        if printf '%s\n' "$available_roles" | awk -v c="$chosen" '$0==c {found=1} END {exit !found}'; then
          printf '%s' "$chosen"
          return 0
        fi
        printf 'Unknown role: %s\n' "$value" >&2
        ;;
      *)
        role_num="$value"
        idx=1
        found=''
        IFS='
'
        for role in $available_roles; do
          if [ "$idx" -eq "$role_num" ]; then
            found="$role"
            break
          fi
          idx=$((idx + 1))
        done
        unset IFS
        if [ -n "$found" ]; then
          printf '%s' "$found"
          return 0
        fi
        printf 'No role at index %s.\n' "$role_num" >&2
        ;;
    esac
  done
}

default_output_path() {
  # Timestamped filename; avoids accidental overwrite by default.
  ts="$(date +%s)"
  printf './debate-config-%s.json' "$ts"
}

printf '%s\n' 'Interactive Debate Config Generator'
printf '%s\n' 'This script will create a debate configuration JSON file.'
printf '\n'

available_roles="$(list_roles)"
if [ -z "$available_roles" ]; then
  printf 'No available roles were found under %s\n' "$PROMPTS_DIR"
  exit 1
fi

printf 'Role suggestions loaded from %s\n' "$PROMPTS_DIR"

agent_count="$(prompt_int "How many debating agents do you want?" "4" "no")"

agents_data=''
i=1
while [ "$i" -le "$agent_count" ]; do
  printf '\n'
  printf 'Agent %s of %s\n' "$i" "$agent_count"
  role="$(select_role "Choose role for agent $i" "" "$available_roles")"
  role_id="$(normalize_role "$role")"
  if [ -z "$role_id" ]; then
    printf 'Invalid role value.\n'
    exit 1
  fi
  # Numbering is per role, so two "performance" agents become -01 and -02.
  role_num="$(increment_role_count "$role_id")"
  role_num_padded="$(printf '%02d' "$role_num")"
  default_name="${role_id}-${role_num_padded}"
  agent_name="$(prompt_with_default "Name for agent $i" "$default_name")"
  agent_id="${role_id}-${role_num_padded}"
  # Store temporary records as pipe-delimited lines for later JSON emission.
  agents_data="${agents_data}${agent_id}|${agent_name}|${role_id}
"
  printf 'Assigned id: %s\n' "$agent_id"
  i=$((i + 1))
done

printf '\n'
judge_role="$(select_role "Judge role" "generalist" "$available_roles")"

printf '\n'
max_rounds="$(prompt_int "Convergence max_rounds" "6" "no")"
judge_threshold="$(prompt_threshold "Convergence judge_threshold" "0.8")"
criteria="$(prompt_with_default "Convergence criteria (free text)" "$DEFAULT_CRITERIA")"

printf '\n'
clarifications_enabled="$(prompt_yes_no "Enable clarifications? (yes/no)" "false")"
clarifications_max="$(prompt_int "Max clarification iterations per agent" "3" "yes")"

printf '\n'
out_default="$(default_output_path)"
output_path="$(prompt_with_default "Output config file path" "$out_default")"

output_dir="$(dirname "$output_path")"
if [ ! -d "$output_dir" ]; then
  printf 'Output directory does not exist: %s\n' "$output_dir"
  exit 1
fi

{
  # Emit JSON manually (dependency-light), with deterministic field order.
  printf '{\n'

  printf '  "agents": [\n'
  first='yes'
  while IFS='|' read -r agent_id agent_name role_name; do
    [ -n "$agent_id" ] || continue
    # Comma management for JSON arrays.
    if [ "$first" = 'yes' ]; then
      first='no'
    else
      printf ',\n'
    fi
    printf '    { "id": "%s", "name": "%s", "role": "%s" }' \
      "$(json_escape "$agent_id")" \
      "$(json_escape "$agent_name")" \
      "$(json_escape "$role_name")"
  done <<EOF
$agents_data
EOF
  printf '\n  ],\n\n'

  printf '  "judge": {\n'
  printf '    "id": "judge",\n'
  printf '    "name": "Technical Judge",\n'
  printf '    "role": "%s",\n' "$(json_escape "$judge_role")"
  printf '    "extra_instructions": ""\n'
  printf '  },\n\n'

  printf '  "convergence": {\n'
  printf '    "max_rounds": %s,\n' "$max_rounds"
  printf '    "judge_threshold": %s,\n' "$judge_threshold"
  printf '    "criteria": "%s"\n' "$(json_escape "$criteria")"
  printf '  },\n\n'

  printf '  "clarifications": {\n'
  printf '    "enabled": %s,\n' "$clarifications_enabled"
  printf '    "max_iterations_per_agent": %s\n' "$clarifications_max"
  printf '  },\n\n'

  printf '  "tools": [\n'
  printf '    {\n'
  printf '      "name": "%s",\n' "$(json_escape "$TOOL_NAME_WEB_SEARCH")"
  printf '      "description": "%s"\n' "$(json_escape "$DEFAULT_TOOLS_WEB_SEARCH_DESC")"
  printf '    },\n'
  printf '    {\n'
  printf '      "name": "%s",\n' "$(json_escape "$TOOL_NAME_FILE_READ")"
  printf '      "description": "%s"\n' "$(json_escape "$DEFAULT_TOOLS_FILE_READ_DESC")"
  printf '    }\n'
  printf '  ],\n\n'

  printf '  "agents_config": {\n'
  printf '    "sec": {\n'
  printf '      "tool_hints": "%s"\n' "$(json_escape "$DEFAULT_AGENTSCONFIG_SEC_HINT")"
  printf '    },\n'
  printf '    "arch": {\n'
  printf '      "tool_hints": "%s"\n' "$(json_escape "$DEFAULT_AGENTSCONFIG_ARCH_HINT")"
  printf '    },\n'
  printf '    "perf": {\n'
  printf '      "tool_hints": "%s"\n' "$(json_escape "$DEFAULT_AGENTSCONFIG_PERF_HINT")"
  printf '    }\n'
  printf '  }\n'

  printf '}\n'
} > "$output_path"

printf '\nWrote config to %s\n' "$output_path"
printf 'Default tools configured: %s, %s\n' "$TOOL_NAME_WEB_SEARCH" "$TOOL_NAME_FILE_READ"
printf 'Default agents_config copied for: sec, arch, perf\n'

printf '\nSummary:\n'
printf '  Judge role: %s\n' "$judge_role"
printf '  Convergence: max_rounds=%s, judge_threshold=%s\n' "$max_rounds" "$judge_threshold"
printf '  Clarifications: enabled=%s, max_iterations_per_agent=%s\n' "$clarifications_enabled" "$clarifications_max"

