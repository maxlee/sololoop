#!/bin/bash
# ============================================================================
# SoloLoop Cancel Script (v5)
# ============================================================================
# v5: Simplified - removed .sololoop/ directory and plan_mode references

set -uo pipefail

STATE_FILE=".claude/sololoop.local.md"

if [[ -f "$STATE_FILE" ]]; then
  # Read state info
  ITER=$(grep '^iteration:' "$STATE_FILE" 2>/dev/null | sed 's/iteration: *//' || true)
  MAX=$(grep '^max_iterations:' "$STATE_FILE" 2>/dev/null | sed 's/max_iterations: *//' || true)
  OPENSPEC_MODE=$(grep '^openspec_mode:' "$STATE_FILE" 2>/dev/null | sed 's/openspec_mode: *//' || true)
  OPENSPEC_TASKS=$(grep '^openspec_tasks_file:' "$STATE_FILE" 2>/dev/null | sed 's/openspec_tasks_file: *//' | tr -d '"' || true)
  
  # Set defaults
  ITER="${ITER:-?}"
  MAX="${MAX:-?}"
  OPENSPEC_MODE="${OPENSPEC_MODE:-false}"
  
  # Delete state file
  rm -f "$STATE_FILE"
  
  echo "SoloLoop cancelled (iteration $ITER/$MAX)"
  
  # Show OpenSpec info if in OpenSpec mode
  if [[ "$OPENSPEC_MODE" == "true" && -n "$OPENSPEC_TASKS" && "$OPENSPEC_TASKS" != "null" ]]; then
    echo ""
    echo "OpenSpec tasks file: $OPENSPEC_TASKS"
    echo "Tip: Use /sololoop:openspec to resume working on this change."
  fi
else
  echo "No active SoloLoop"
fi
