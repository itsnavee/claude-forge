---
name: bug-hunt
description: Use when you want to find bugs before shipping — runs 3 adversarial agents (Hunter finds bugs, Skeptic disproves false positives, Referee arbitrates) against your codebase or specific files. Also use when the user says "find bugs", "hunt for issues", or "check for problems".
argument-hint: "< path | -b branch [--base base-branch] >"
disable-model-invocation: true
gate:
  type: cooldown
  duration: 15m
  reason: "Runs 3 adversarial agents (Hunter, Skeptic, Referee). Re-running on unchanged code finds the same bugs."
---

# Bug Hunt - Adversarial Bug Finding

Run a 3-agent adversarial bug hunt on your codebase. Each agent runs in isolation.

## Usage

```
/bug-hunt              # Scan entire project
/bug-hunt src/         # Scan specific directory
/bug-hunt lib/auth.ts  # Scan specific file
/bug-hunt -b feature-xyz              # Scan files changed in feature-xyz vs main
/bug-hunt -b feature-xyz --base dev   # Scan files changed in feature-xyz vs dev
```

## Target

The raw arguments are: $ARGUMENTS

**Parse the arguments as follows:**

1. If arguments contain `-b <branch>`: this is a **branch diff mode**.
   - Extract the branch name after `-b`.
   - If `--base <base-branch>` is also present, use that as the base branch. Otherwise default to `main`.
   - Run `git diff --name-only <base>...<branch>` using the Bash tool to get the list of changed files.
   - If the command fails (e.g. branch not found), report the error to the user and stop.
   - If no files changed, tell the user there are no changes to scan and stop.
   - The scan target is the list of changed files (scan their full contents, not just the diff).
2. If arguments do NOT contain `-b`: treat the entire argument string as a **path target** (file or directory). If empty, scan the current working directory.

## Step 0: Resolve Project Root

Before any file operations, resolve the git repo root. All project-relative paths (`docs/`) are relative to this root, NOT `pwd`.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

## Execution Steps

You MUST follow these steps in exact order. Each agent runs as a separate subagent via the Agent tool to ensure context isolation.

### Step 1: Parse arguments and resolve target

Follow the rules in the **Target** section above to determine the scan target. If in branch diff mode, run the git diff command now and collect the file list.

### Step 2: Read the prompt files

Read these files using the skill directory variable:
- ${CLAUDE_SKILL_DIR}/prompts/hunter.md
- ${CLAUDE_SKILL_DIR}/prompts/skeptic.md
- ${CLAUDE_SKILL_DIR}/prompts/referee.md

### Step 3: Run the Hunter Agent

Launch a general-purpose subagent with the hunter prompt. Include the scan target in the agent's task. If in branch diff mode, pass the explicit file list so the Hunter only scans those files (full contents). The Hunter must use tools (Read, Glob, Grep) to examine the actual code.

Wait for the Hunter to complete and capture its full output.

### Step 3b: Check for findings

If the Hunter reported TOTAL FINDINGS: 0, skip Steps 4-5 and go directly to Step 6 with a clean report. No need to run Skeptic and Referee on zero findings.

### Step 4: Run the Skeptic Agent

Launch a NEW general-purpose subagent with the skeptic prompt. Inject the Hunter's structured bug list (BUG-IDs, files, lines, claims, evidence, severity, points). Do NOT include any narrative or methodology text outside the structured findings.

The Skeptic must independently read the code to verify each claim.

Wait for the Skeptic to complete and capture its full output.

### Step 5: Run the Referee Agent

Launch a NEW general-purpose subagent with the referee prompt. Inject BOTH:
- The Hunter's full bug report
- The Skeptic's full challenge report

The Referee must independently read the code to make final judgments.

Wait for the Referee to complete and capture its full output.

### Step 6: Present the Final Report

Display the Referee's final verified bug report to the user. Include:
1. The summary stats
2. The confirmed bugs table (sorted by severity)
3. Low-confidence items flagged for manual review
4. A collapsed section with dismissed bugs (for transparency)

If zero bugs were confirmed, say so clearly — a clean report is a good result.

## Gotchas

- Each agent (Hunter, Skeptic, Referee) needs a fresh `/reset` between runs — context from previous agents biases findings
- The Skeptic's 2x penalty for dismissing real bugs sometimes makes it too conservative — it defends everything
- Running on large codebases (>50 files) without scoping to a directory produces shallow findings — always scope with a path

## Quick Help

**What**: Adversarial bug hunting with 3 agents (Hunter finds, Skeptic challenges, Referee decides).
**Usage**:
- `/bug-hunt` — scan entire project
- `/bug-hunt src/services/` — scan specific path
- `/bug-hunt -b feature-branch` — scan branch diff vs main
- `/bug-hunt -b feature --base develop` — scan branch diff vs custom base
**Output**: `docs/bug-hunt-YYYY-MM-DD.md` with confirmed bugs, dismissed bugs, and manual-review items.
