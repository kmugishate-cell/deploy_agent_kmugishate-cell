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

# 6b: build Helpers/assets.csv (Option A: copy template, Option B: generate)
build_roster() {
    local out="$BASE_DIR/$PROJECT_DIR/Helpers/assets.csv"
    local cfg="$BASE_DIR/$PROJECT_DIR/Helpers/config.json"
    local opt n
    echo "Roster options:"
    echo "  A) Copy students from the template"
    echo "  B) Generate a fresh roster"
    read -rp "Choose A or B: " opt

    case "${opt^^}" in
        A)
            local max=$(( $(wc -l < "$TEMPLATES_DIR/assets.csv") - 1 ))
            read -rp "How many students to copy (1-$max)? " n
            if ! is_number "$n" || (( n < 1 || n > max )); then
                echo "ERROR: invalid number." >&2; exit 1
            fi
            head -n $(( n + 1 )) "$TEMPLATES_DIR/assets.csv" > "$out"
            # Sample rows have 4 prior sessions, so total_sessions stays 5
            ;;
        B)
            read -rp "How many students to generate? " n
            if ! is_number "$n" || (( n < 1 )); then
                echo "ERROR: invalid number." >&2; exit 1
            fi
            local names=("Alice Johnson" "Bob Smith" "Carol White" "David Brown" "Eve Davis"
                         "Frank Miller" "Grace Lee" "Henry Wilson" "Ivy Clark" "Jack Moore")
            local emails=("alice" "bob" "carol" "david" "eve" "frank" "grace" "henry" "ivy" "jack")
            echo "Email,Names,Attendance Count,Absence Count" > "$out"
            local i idx suffix
            for (( i=0; i<n; i++ )); do
                idx=$(( i % ${#names[@]} ))
                suffix=""
                (( i >= ${#names[@]} )) && suffix=$(( i / ${#names[@]} ))
                echo "${emails[idx]}${suffix}@example.com,${names[idx]},0,0" >> "$out"
            done
            # Fresh roster means this is session one
            sed -i 's/"total_sessions": *[0-9]*/"total_sessions": 1/' "$cfg"
            ;;
        *)
            echo "ERROR: choose A or B." >&2; exit 1
            ;;
    esac
    echo "Roster created with $n students."
}

# 6c: make the app executable, lock down the config
set_permissions() {
    chmod +x "$BASE_DIR/$PROJECT_DIR/attendance_checker.py"
    chmod 600 "$BASE_DIR/$PROJECT_DIR/Helpers/config.json"
    echo "Permissions set:"
    ls -l "$BASE_DIR/$PROJECT_DIR/attendance_checker.py" "$BASE_DIR/$PROJECT_DIR/Helpers/config.json"
}

# 6d: optionally update warning/failure thresholds in config.json
update_thresholds() {
    local cfg="$BASE_DIR/$PROJECT_DIR/Helpers/config.json"
    local ans w f
    read -rp "Update attendance thresholds? (y/n): " ans
    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        return 0
    fi

    read -rp "Warning threshold [75]: " w
    w=${w:-75}
    read -rp "Failure threshold [50]: " f
    f=${f:-50}

    if ! is_number "$w" || ! is_number "$f" || (( w > 100 || f >= w )); then
        echo "ERROR: values must be 0-100 and failure must be below warning. Keeping current values." >&2
        return 1
    fi

    # Edit only the two target lines, keep formatting
    sed -i -E "s/(\"warning\":[[:space:]]*)[0-9]+/\1$w/; s/(\"failure\":[[:space:]]*)[0-9]+/\1$f/" "$cfg"
    echo "Thresholds updated: warning=$w, failure=$f"
}

# 6e: full deploy: checks, build, trap on during setup, verify by running
deploy_feature() {
    preflight_check
    ask_project_name || return 1

    trap handle_interrupt SIGINT SIGTSTP     # on during setup
    create_structure
    build_roster
    set_permissions
    update_thresholds
    trap - SIGINT SIGTSTP                    # off before the app runs

    echo "Deployment complete. Verifying by running the app..."
    run_app
}
[master 21cde01] Add roster, permissions, thresholds, deploycat
 1 file changed, 94 insertions(+)

# ---------- Menu ----------
echo "=== Attendance Tracker Deploy Agent ==="
echo "1) Deploy application"
echo "2) Run application"
echo "3) Archive logs"
echo "4) Exit"
read -rp "Select a feature [1-4]: " choice

case "$choice" in
    1) deploy_feature ;;
    2) run_feature ;;
    3) archive_feature ;;
    4) echo "Goodbye." ;;
    *) echo "Invalid choice." >&2; exit 1 ;;
esac
