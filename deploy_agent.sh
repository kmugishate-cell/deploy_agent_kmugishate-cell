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

# ---------- Helpers ----------
# Fail early if a required tool is missing
preflight_check() {
    local missing=0
    for cmd in python3 zip; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "ERROR: '$cmd' is not installed." >&2
            missing=1
        fi
    done
    if [[ $missing -eq 1 ]]; then
        exit 1
    fi
    echo "Pre-flight OK: python3 and zip found."
}

# Ask for a name and set PROJECT_DIR
ask_project_name() {
    local name
    read -rp "Enter project name: " name
    if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "ERROR: use only letters, numbers, - and _." >&2
        return 1
    fi
    PROJECT_DIR="attendance_tracker_${name}"
}

# True if the argument is a whole number
is_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}
