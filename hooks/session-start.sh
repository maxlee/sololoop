#!/bin/bash
# ============================================================================
# SoloLoop SessionStart Hook - Session Recovery Detection (v8)
# ============================================================================
#
# Description:
#   Called automatically when a Claude Code session starts or resumes.
#   If an unfinished SoloLoop state file exists, outputs a warning message
#   to let the user know they can continue or cancel the previous loop.
#
# How it works:
#   1. Read JSON hook input from stdin (contains session_id)
#   2. Check if state file exists (.claude/sololoop.local.md)
#   3. If exists, output additionalContext warning message
#   4. If not exists, exit silently
#
# Input:
#   JSON via stdin:
#   {
#     "session_id": "abc123",
#     "cwd": "/path/to/project",
#     "hook_event_name": "SessionStart"
#   }
#
# Output:
#   - State file exists: JSON {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}
#   - State file not exists: silent exit (exit 0)
#
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------
STATE_FILE=".claude/sololoop.local.md"

# ----------------------------------------------------------------------------
# Read hook input
# ----------------------------------------------------------------------------
HOOK_INPUT=$(cat)

# ----------------------------------------------------------------------------
# Check if state file exists
# If not exists, exit silently
# Requirements 2.4
# ----------------------------------------------------------------------------
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# ----------------------------------------------------------------------------
# Check if state file is empty
# ----------------------------------------------------------------------------
if [[ ! -s "$STATE_FILE" ]]; then
  exit 0
fi

# ----------------------------------------------------------------------------
# Parse YAML frontmatter from state file
# ----------------------------------------------------------------------------
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || echo "")

# Handle malformed state file
if [[ -z "$FRONTMATTER" ]]; then
  exit 0
fi

# Check if frontmatter contains required fields
if ! echo "$FRONTMATTER" | grep -q '^iteration:' || ! echo "$FRONTMATTER" | grep -q '^max_iterations:'; then
  exit 0
fi

# ----------------------------------------------------------------------------
# Extract iteration info
# Requirements 2.2
# ----------------------------------------------------------------------------
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "")
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || echo "")

# Validate numeric fields
if [[ -z "$ITERATION" ]] || [[ -z "$MAX_ITERATIONS" ]]; then
  exit 0
fi

if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  exit 0
fi

# ----------------------------------------------------------------------------
# Detect wrap mode
# ----------------------------------------------------------------------------
WRAP_MODE=$(echo "$FRONTMATTER" | grep '^wrap_mode:' | sed 's/wrap_mode: *//' || echo "false")
WRAPPED_COMMAND=$(echo "$FRONTMATTER" | grep '^wrapped_command:' | sed 's/wrapped_command: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")

# ----------------------------------------------------------------------------
# Build warning message
# Requirements 2.2, 2.3
# ----------------------------------------------------------------------------
WARNING_MSG="Detected unfinished SoloLoop ($ITERATION/$MAX_ITERATIONS)"

if [[ "$WRAP_MODE" == "true" ]] && [[ -n "$WRAPPED_COMMAND" ]]; then
  WARNING_MSG="$WARNING_MSG [wrapped: $WRAPPED_COMMAND]"
fi

WARNING_MSG="$WARNING_MSG. Continue: run command directly; Restart: run /sololoop:cancel-sololoop first"

# ----------------------------------------------------------------------------
# Output JSON response
# Requirements 2.1, 2.2, 2.3
# ----------------------------------------------------------------------------
if command -v jq &>/dev/null; then
  jq -n \
    --arg context "$WARNING_MSG" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": $context
      }
    }'
else
  # Fallback when jq is not available - manually build JSON
  # Need to escape special characters
  ESCAPED_MSG=$(echo "$WARNING_MSG" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\t/\\t/g')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"$ESCAPED_MSG\"}}"
fi
