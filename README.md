# deploy_agent

A shell script that deploys, runs, and archives logs for the Student Attendance Tracker, and handles Ctrl+C / Ctrl+Z during deployment.

**Video walkthrough:** PASTE-LINK-HERE

## Repository layout

```
deploy_agent_kmugishate-cell/
├── deploy_agent.sh
├── README.md
└── templates/
    ├── attendance_checker.py   (unmodified)
    ├── assets.csv              (unmodified, 10 students)
    └── config.json             (unmodified)
```

## How to run

```bash
chmod +x deploy_agent.sh
./deploy_agent.sh
```

I used an **interactive menu**:

```
1) Deploy application
2) Run application
3) Archive logs
4) Exit
```

Each feature asks for a project name and builds `attendance_tracker_{name}`. Names may contain only letters, numbers, `-` and `_`.

## Feature 1: Deploy

1. **Pre-flight:** checks that `python3` and `zip` exist, and exits with an error if not.
2. **Structure:** creates `attendance_tracker_{name}/` with `Helpers/` and an empty `reports/`, then copies `attendance_checker.py` and `config.json` unmodified from `templates/`. If the directory exists, the script asks whether to overwrite; any answer except `y` aborts.
3. **Roster:**
   - **Option A** copies N students (plus the header) from `templates/assets.csv`.
   - **Option B** generates N students from name and email arrays inside the script, with counts starting at `0,0`.
4. **Permissions:** `chmod +x` on `attendance_checker.py` and `chmod 600` on `Helpers/config.json`, followed by an `ls -l` confirmation.
5. **Thresholds:** asks whether to update them. If yes, `read` captures warning (default 75) and failure (default 50), checks that they are numbers, warning is at most 100, and failure is below warning, then edits only the two target lines with `sed -E`. The file's formatting and order are untouched.
6. **Verify:** the trap is switched off and the app is started (Feature 2). A successful start proves the structure, roster, and config work together.

### total_sessions and the roster

`total_sessions` must be one more than the sessions already recorded in the roster.

| Roster | Prior sessions | total_sessions |
|---|---|---|
| Option A (template rows, 4 prior sessions each) | 4 | 5 (template default, left unchanged) |
| Option B (fresh roster, counts at 0) | 0 | 1 (script sets it with `sed`) |

## Feature 2: Run

Enters the project directory and runs `python3 attendance_checker.py`. The app is interactive, so the instructor marks each student `P` or `A`. It updates `assets.csv` and writes `reports/attendance.log` and `reports/absent.log` (the absent log only exists if someone was absent).

## Feature 3: Archive logs

Creates `archives/attendance/` and `archives/absent/` and moves each existing log into its own folder with a timestamp:

```
archives/attendance/attendance_YYYYMMDD_HHMMSS.log
archives/absent/absent_YYYYMMDD_HHMMSS.log
```

Both logs get the same timestamp in a run. I used `mv` rather than `cp`, so `reports/` is empty afterwards and the next session starts with fresh logs. If a log doesn't exist, the script prints a note and carries on without crashing.

## Ctrl+C / Ctrl+Z during deployment

`trap handle_interrupt

Walk through video
<a href="https://drive.google.com/file/d/10wgLNoWfahJXcwyFlKSGHpv5JzdGRFhX/view?usp=sharing"> <b>DEMO VIDEO </b> </a>
