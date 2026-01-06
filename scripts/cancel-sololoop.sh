#!/bin/bash
# ============================================================================
# SoloLoop Cancel Script (v3)
# ============================================================================

set -uo pipefail

STATE_FILE=".claude/sololoop.local.md"
PLANNING_DIR=".sololoop"

if [[ -f "$STATE_FILE" ]]; then
  # Read state info
  ITER=$(grep '^iteration:' "$STATE_FILE" 2>/dev/null | sed 's/iteration: *//' || true)
  MAX=$(grep '^max_iterations:' "$STATE_FILE" 2>/dev/null | sed 's/max_iterations: *//' || true)
  PLAN_MODE=$(grep '^plan_mode:' "$STATE_FILE" 2>/dev/null | sed 's/plan_mode: *//' || true)
  
  # Set defaults
  ITER="${ITER:-?}"
  MAX="${MAX:-?}"
  PLAN_MODE="${PLAN_MODE:-false}"
  
  # Delete state file
  rm -f "$STATE_FILE"
  
  echo "SoloLoop cancelled (iteration $ITER/$MAX)"
  
  # Show preserved planning files in plan mode (v3: check .sololoop/ directory)
  if [[ "$PLAN_MODE" == "true" ]]; then
    echo ""
    echo "Planning files preserved in $PLANNING_DIR/:"
    
    if [[ -d "$PLANNING_DIR" ]]; then
      if [[ -f "$PLANNING_DIR/task_plan.md" ]]; then
        echo "  - $PLANNING_DIR/task_plan.md"
      fi
      if [[ -f "$PLANNING_DIR/notes.md" ]]; then
        echo "  - $PLANNING_DIR/notes.md"
      fi
      if [[ -f "$PLANNING_DIR/deliverable.md" ]]; then
        echo "  - $PLANNING_DIR/deliverable.md"
      fi
    else
      echo "  (no planning directory found)"
    fi
    
    echo ""
    echo "Tip: Planning files were not deleted and can be used in future sessions."
  fi
else
  echo "No active SoloLoop"
fi
