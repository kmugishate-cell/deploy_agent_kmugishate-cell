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

# ---------- Feature 2: Run the application ----------
# Run the app inside an already-deployed project
run_app() {
    if [[ ! -d "$BASE_DIR/$PROJECT_DIR" ]]; then
        echo "ERROR: $PROJECT_DIR does not exist. Deploy it first." >&2
        return 1
    fi
    # Subshell: the cd only affects this one command
    ( cd "$BASE_DIR/$PROJECT_DIR" && python3 attendance_checker.py )
}

# Menu entry: ask which project, then run it
run_feature() {
    ask_project_name || return 1
    run_app
}

# ---------- Feature 1: Deploy the application ----------
# 6a: create directories and copy the unmodified template files
create_structure() {
    if [[ -d "$BASE_DIR/$PROJECT_DIR" ]]; then
        local ans
        read -rp "$PROJECT_DIR already exists. Overwrite? (y/n): " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            rm -rf "$BASE_DIR/$PROJECT_DIR"
        else
            echo "ERROR: aborting, $PROJECT_DIR already exists." >&2
            exit 1
        fi
    fi

    mkdir -p "$BASE_DIR/$PROJECT_DIR/Helpers" "$BASE_DIR/$PROJECT_DIR/reports"
    cp "$TEMPLATES_DIR/attendance_checker.py" "$BASE_DIR/$PROJECT_DIR/"
    cp "$TEMPLATES_DIR/config.json" "$BASE_DIR/$PROJECT_DIR/Helpers/"
    echo "Structure created: $PROJECT_DIR"
}
