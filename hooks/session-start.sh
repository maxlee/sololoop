#!/bin/bash
# ============================================================================
# SoloLoop SessionStart Hook - Session Recovery & Goal Memory Injection (v9)
# ============================================================================
#
# Description:
#   Called automatically when a Claude Code session starts or resumes.
#   v9 adds Goal Memory injection: if .sololoop/goal.md exists, inject
#   goal context into additionalContext.
#
# How it works:
#   1. Read JSON hook input from stdin (contains session_id)
#   2. Check if .sololoop/goal.md exists - if yes, inject goal memory
#   3. Check if state file exists (.claude/sololoop.local.md)
#   4. If state file exists, add warning about unfinished loop
#   5. Output combined additionalContext
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
#   - Goal files exist: JSON with goal memory context
#   - State file exists: JSON with recovery warning
#   - Neither exists: silent exit (exit 0)
#
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------
STATE_FILE=".claude/sololoop.local.md"
SOLOLOOP_DIR=".sololoop"
GOAL_FILE="$SOLOLOOP_DIR/goal.md"
INVARIANTS_FILE="$SOLOLOOP_DIR/invariants.md"
DECISIONS_LOG_FILE="$SOLOLOOP_DIR/decisions-log.md"

# ----------------------------------------------------------------------------
# Read hook input
# ----------------------------------------------------------------------------
HOOK_INPUT=$(cat)

# ----------------------------------------------------------------------------
# Initialize context parts
# ----------------------------------------------------------------------------
GOAL_CONTEXT=""
RECOVERY_CONTEXT=""

# ----------------------------------------------------------------------------
# Goal Memory Injection (v9)
# Requirements 2.1, 2.2, 2.3, 2.4, 2.6
# ----------------------------------------------------------------------------
if [[ -f "$GOAL_FILE" ]]; then
  # Read goal.md content
  GOAL_CONTENT=$(cat "$GOAL_FILE" 2>/dev/null || echo "")
  
  if [[ -n "$GOAL_CONTENT" ]]; then
    GOAL_CONTEXT="## SoloLoop Goal Memory

### Current Goal
$GOAL_CONTENT"
  fi
  
  # Read invariants.md content if exists (Requirements 2.2)
  if [[ -f "$INVARIANTS_FILE" ]]; then
    INVARIANTS_CONTENT=$(cat "$INVARIANTS_FILE" 2>/dev/null || echo "")
    if [[ -n "$INVARIANTS_CONTENT" ]]; then
      GOAL_CONTEXT="$GOAL_CONTEXT

### Core Invariants
$INVARIANTS_CONTENT"
    fi
  fi
  
  # Read latest 5 entries from decisions-log.md (Requirements 2.6)
  if [[ -f "$DECISIONS_LOG_FILE" ]]; then
    # Extract entries (separated by ---) and get last 5
    # Each entry starts with ## [timestamp]
    DECISIONS_CONTENT=$(cat "$DECISIONS_LOG_FILE" 2>/dev/null || echo "")
    if [[ -n "$DECISIONS_CONTENT" ]]; then
      # Extract entries after the header (after first ---)
      # Get last 5 entries by counting ## [ patterns
      RECENT_DECISIONS=$(echo "$DECISIONS_CONTENT" | awk '
        BEGIN { in_entry = 0; entry_count = 0; entries[0] = "" }
        /^---$/ { 
          if (in_entry) {
            entry_count++
            entries[entry_count] = ""
          }
          in_entry = 1
          next
        }
        /^## \[/ {
          if (in_entry && entries[entry_count] != "") {
            entry_count++
            entries[entry_count] = ""
          }
        }
        in_entry { entries[entry_count] = entries[entry_count] "\n" $0 }
        END {
          # Output last 5 entries
          start = entry_count - 4
          if (start < 1) start = 1
          for (i = start; i <= entry_count; i++) {
            if (entries[i] != "") {
              print entries[i]
              print "---"
            }
          }
        }
      ')
      
      if [[ -n "$RECENT_DECISIONS" ]] && [[ "$RECENT_DECISIONS" != *"---"* ]] || [[ $(echo "$RECENT_DECISIONS" | grep -c "## \[") -gt 0 ]]; then
        GOAL_CONTEXT="$GOAL_CONTEXT

### Recent Decisions (Last 5)
$RECENT_DECISIONS"
      fi
    fi
  fi
fi

# ----------------------------------------------------------------------------
# Session Recovery Detection (v8 functionality) + Brief Status (v9)
# Requirements 2.4 (from v8), 6.3
# ----------------------------------------------------------------------------
if [[ -f "$STATE_FILE" ]] && [[ -s "$STATE_FILE" ]]; then
  # Parse YAML frontmatter from state file
  FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || echo "")
  
  if [[ -n "$FRONTMATTER" ]]; then
    # Check if frontmatter contains required fields
    if echo "$FRONTMATTER" | grep -q '^iteration:' && echo "$FRONTMATTER" | grep -q '^max_iterations:'; then
      # Extract iteration info
      ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//' || echo "")
      MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//' || echo "")
      
      # Validate numeric fields
      if [[ -n "$ITERATION" ]] && [[ -n "$MAX_ITERATIONS" ]] && \
         [[ "$ITERATION" =~ ^[0-9]+$ ]] && [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
        
        # Detect wrap mode
        WRAP_MODE=$(echo "$FRONTMATTER" | grep '^wrap_mode:' | sed 's/wrap_mode: *//' || echo "false")
        WRAPPED_COMMAND=$(echo "$FRONTMATTER" | grep '^wrapped_command:' | sed 's/wrapped_command: *//' | sed 's/^"\(.*\)"$/\1/' || echo "")
        
        # Build warning message
        RECOVERY_CONTEXT="Detected unfinished SoloLoop ($ITERATION/$MAX_ITERATIONS)"
        
        if [[ "$WRAP_MODE" == "true" ]] && [[ -n "$WRAPPED_COMMAND" ]]; then
          RECOVERY_CONTEXT="$RECOVERY_CONTEXT [wrapped: $WRAPPED_COMMAND]"
        fi
        
        RECOVERY_CONTEXT="$RECOVERY_CONTEXT. Continue: run command directly; Restart: run /sololoop:cancel-sololoop first"
        
        # ----------------------------------------------------------------------------
        # Brief Status Display for Goal Memory (v9)
        # Requirements 6.3: Show brief status when resuming session with active goal memory
        # ----------------------------------------------------------------------------
        GOAL_MEMORY_ENABLED=$(echo "$FRONTMATTER" | grep '^goal_memory_enabled:' | sed 's/goal_memory_enabled: *//' || echo "false")
        
        if [[ "$GOAL_MEMORY_ENABLED" == "true" ]]; then
          # Extract goal memory status fields
          ITERATION_SINCE_ANCHOR=$(echo "$FRONTMATTER" | grep '^iteration_since_anchor:' | sed 's/iteration_since_anchor: *//' || echo "0")
          ANCHOR_INTERVAL=$(echo "$FRONTMATTER" | grep '^anchor_interval:' | sed 's/anchor_interval: *//' || echo "15")
          DRIFT_WARNING_COUNT=$(echo "$FRONTMATTER" | grep '^drift_warning_count:' | sed 's/drift_warning_count: *//' || echo "0")
          TOTAL_ANCHORS=$(echo "$FRONTMATTER" | grep '^total_anchors:' | sed 's/total_anchors: *//' || echo "0")
          
          # Build brief status
          STATUS_LINE="[Goal Memory Active] Re-anchor: $ITERATION_SINCE_ANCHOR/$ANCHOR_INTERVAL, Total anchors: $TOTAL_ANCHORS"
          
          # Add drift warning if any
          if [[ "$DRIFT_WARNING_COUNT" != "0" ]] && [[ -n "$DRIFT_WARNING_COUNT" ]]; then
            STATUS_LINE="$STATUS_LINE, Drift warnings: $DRIFT_WARNING_COUNT"
          fi
          
          RECOVERY_CONTEXT="$RECOVERY_CONTEXT
$STATUS_LINE"
        fi
      fi
    fi
  fi
fi

# ----------------------------------------------------------------------------
# Combine contexts and output
# Requirements 2.1, 2.2, 2.3, 2.4, 2.5
# ----------------------------------------------------------------------------

# If no context to output, exit silently (Requirements 2.5)
if [[ -z "$GOAL_CONTEXT" ]] && [[ -z "$RECOVERY_CONTEXT" ]]; then
  exit 0
fi

# Combine contexts
COMBINED_CONTEXT=""
if [[ -n "$GOAL_CONTEXT" ]]; then
  COMBINED_CONTEXT="$GOAL_CONTEXT"
fi

if [[ -n "$RECOVERY_CONTEXT" ]]; then
  if [[ -n "$COMBINED_CONTEXT" ]]; then
    COMBINED_CONTEXT="$COMBINED_CONTEXT

---

$RECOVERY_CONTEXT"
  else
    COMBINED_CONTEXT="$RECOVERY_CONTEXT"
  fi
fi

# ----------------------------------------------------------------------------
# Output JSON response
# Requirements 2.1, 2.3, 2.4
# ----------------------------------------------------------------------------
if command -v jq &>/dev/null; then
  jq -n \
    --arg context "$COMBINED_CONTEXT" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": $context
      }
    }'
else
  # Fallback when jq is not available - manually build JSON
  # Need to escape special characters for JSON
  ESCAPED_MSG=$(echo "$COMBINED_CONTEXT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\t/\\t/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"$ESCAPED_MSG\"}}"
fi
