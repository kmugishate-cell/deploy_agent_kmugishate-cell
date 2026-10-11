#!/bin/bash
# deploy_agent.sh - deploy, run, and archive the Student Attendance Tracker

# Always work from the folder the script lives in
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
BASE_DIR="$(pwd)"
TEMPLATES_DIR="$BASE_DIR/templates"
PROJECT_DIR=""

# ---------- Signal handler ----------
# Runs on Ctrl+C (SIGINT) or Ctrl+Z (SIGTSTP) while deploying
handle_interrupt() {
    echo
    echo "!! Deployment interrupted by user."
    if [[ -n "$PROJECT_DIR" && -d "$BASE_DIR/$PROJECT_DIR" ]]; then
        echo "Archiving incomplete project..."
        cd "$BASE_DIR" || exit 1
        zip -rq "${PROJECT_DIR}_archive.zip" "$PROJECT_DIR"
        echo "Saved: ${PROJECT_DIR}_archive.zip"
        rm -rf "$PROJECT_DIR"   # leave no half-made directory behind
    else
        echo "Nothing to archive yet."
    fi
    echo "Session closed cleanly."
    exit 130
}
