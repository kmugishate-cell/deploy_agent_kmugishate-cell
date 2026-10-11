#!/bin/bash
# deploy_agent.sh - deploy, run, and archive the Student Attendance Tracker

# Always work from the folder the script lives in
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
BASE_DIR="$(pwd)"
TEMPLATES_DIR="$BASE_DIR/templates"
PROJECT_DIR=""
