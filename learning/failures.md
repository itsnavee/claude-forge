# Failures

Debugging sessions, bugs that took significant effort, things that broke unexpectedly.

### 2026-03-14 — macOS date %P format doesn't produce lowercase am/pm
**Project**: claude-config
**Context**: Timezone clocks showed "10:07P" instead of "10:07pm". `%P` is a GNU extension — macOS date doesn't support it the same way.
**Learning**: On macOS, use `date +"%l:%M%p"` then pipe through `tr '[:upper:]' '[:lower:]'` and `sed 's/\.//g'` to get clean lowercase am/pm.

