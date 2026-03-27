#!/bin/bash
# ============================================================================
# Shared utility: Check if current repo is public
# Usage: source this file, then check IS_PUBLIC_REPO ("yes" or "no")
#        Also sets REPO_ROOT if in a git repo
# Dependencies: git only (no gh CLI required)
# ============================================================================

IS_PUBLIC_REPO="no"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -n "$REPO_ROOT" ]; then
  REMOTE_URL=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null)
  if [ -n "$REMOTE_URL" ]; then
    HTTPS_URL=$(echo "$REMOTE_URL" | sed -E 's|git@github\.com:|https://github.com/|; s|\.git$||')
    if GIT_TERMINAL_PROMPT=0 git ls-remote "$HTTPS_URL.git" HEAD >/dev/null 2>&1; then
      IS_PUBLIC_REPO="yes"
    fi
  fi
fi
