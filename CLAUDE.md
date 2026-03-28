# Global Rules

**User Note:** The user may have keyboard issues (trouble with 'o' key). Be mindful of potential typos like "nw" = "now", "kn" = "know", etc. Clarify if needed.

@ROUTING.md

## Anti-Sycophancy & Code Quality

These rules apply to ALL coding work. They are non-negotiable.

### Push Back
- If a task can be solved with an existing tool, library, or one-liner, say so BEFORE writing new code. Do not build what already exists.
- If an approach seems over-engineered for the problem, call it out. Propose the simplest alternative.
- If requirements seem wrong or contradictory, say so. Ask "Are you sure?" — do not silently comply.
- Never say code is "clean", "solid", "well-structured", or "looks great" unless you can point to specific evidence. Default to stating what could be wrong.

### Correctness Over Plausibility
- "It compiles and tests pass" is not proof of correctness. Always consider: what is NOT tested? What could be subtly wrong?
- State your confidence level (high/medium/low) when making non-trivial technical decisions.
- If you don't know the performance characteristics of an algorithm, data structure, or syscall, say "I don't know" instead of guessing.
- Prefer the correct algorithm over the "safe default." Know when O(log n) vs O(n) matters. Know when fdatasync vs fsync matters.
- Never generate code you can't explain. If you can't explain why a specific approach was chosen over alternatives, you shouldn't be writing it.

### Complexity Budget
- Before writing code, mentally estimate how many lines a senior engineer would write. If your solution significantly exceeds that, stop and reassess.
- Every new dependency must be justified. Prefer zero dependencies for simple tasks.
- If a solution is growing beyond what the problem warrants, stop and say "This is getting over-engineered. Here's a simpler approach."

### What Was Described vs What Is Needed
- Before implementing, ask: "Is this solving the actual problem, or just fulfilling the prompt?" LLMs generate what was described, not what was needed. A prompt for "intelligent disk management" does not need 82K lines — it needs a cron one-liner.
- Check if the problem is already solved by an existing tool, stdlib function, or one-liner. State what you found before writing new code.
- Lines of code is not a measure of progress. More code = more surface area for bugs. The goal is the minimum code that correctly solves the problem.

### Acceptance Criteria First
- For any non-trivial task, state measurable acceptance criteria BEFORE writing code: what "correct" means, performance bounds, edge cases, what must NOT be built.
- "It compiles and tests pass" is necessary but not sufficient. Consider: what is NOT tested? What semantic bugs could hide behind passing tests?
- When performance matters, state the expected algorithmic complexity and benchmark against a baseline. Do not guess — measure.

### Self-Review Honesty
- After generating non-trivial code, proactively state the top ways it could be subtly wrong despite appearing correct.
- Do not praise your own output. Focus on what's missing, untested, or assumed.
- When reviewing code you previously generated, apply the same skepticism as reviewing a stranger's code.
- Never use your own output as evidence of quality. "The architecture is sound" means nothing without a benchmark or proof.

---

## Acceptance Criteria Gate — Hard Rule

**No project implementation begins without `docs/acceptance-criteria.md` existing and passing validation.**

This is not optional. This is the gate.

### When starting work on any project:

1. Check if `docs/acceptance-criteria.md` exists in the project root's `docs/` directory.
2. **If it does NOT exist:** Run `/my-create-acceptance-criteria` before writing a single line of implementation code. Do not proceed past planning until the file exists.
3. **If it DOES exist:** Read it. If it is missing coverage for the phase you are about to implement, run `/my-create-acceptance-criteria` to reiterate it before starting.

### What "valid" means:
- Every feature in the current phase has measurable acceptance criteria (not "it works" — specific behavioral assertions)
- Security criteria are present (tenant isolation, injection, XSS, auth, rate limiting, webhook verification)
- Concurrency criteria are present for any shared-state operation
- External failure modes are documented for every third-party service used
- Coverage gaps are declared explicitly

---

## Context Engineering — state.md + architecture.md

Every project should have three context files. Together they eliminate unnecessary codebase scanning and reduce token usage by ~87%.

| File | Purpose | Updates |
|------|---------|---------|
| `CLAUDE.md` | Rules, behavior, coding standards | Manual, rarely changes |
| `state.md` | Current phase, completed work, active tasks, blockers, resume point | Auto-updated by `/my-save`, also update manually during sessions |
| `architecture.md` | Directory map, services, modules, data flow, key config files | Manual, only when services/modules change |

### Project Root Resolution

**CRITICAL:** Always resolve the git repo root before writing any project files. Never assume `pwd` is the project root — you may be in a subdirectory.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

All project-relative paths (`state.md`, `architecture.md`, `.claude/sessions/`, `docs/`) must be relative to `$PROJECT_ROOT`.

### When starting work on any project:

1. Check if `state.md` and `architecture.md` exist at `$PROJECT_ROOT/` (the git repo root).
2. **If they do NOT exist:** Create them at `$PROJECT_ROOT/` before doing any work. Use this format:

**state.md** (~40-60 lines):
```markdown
# State
## Current Position — phase, last activity date, status
## Recently Completed — last ~8 completed items
## Active / Queued — current and upcoming tasks
## Active Decisions — key architectural decisions in effect
## Blockers — anything blocking progress
## Resume Point — what to do next
```

**architecture.md** (~60-100 lines):
```markdown
# Architecture
## Services — table of services with path, framework, port, URL
## Project Layout — directory tree (top 2-3 levels)
## Key Modules — table of modules with purpose
## Data Flow — ASCII diagram of how data moves through the system
## Key Config Files — table of important config files
## Imports Convention — how imports work in this project
```

3. **If they exist:** Read them at session start. They tell you where things are so you don't need to scan the codebase.
4. **During work:** Update `state.md` when you complete tasks, discover blockers, or make decisions. `/my-save` handles this automatically at session end.

### Rules:
- `state.md` must stay under 60 lines — it's a snapshot, not a log
- `architecture.md` must stay under 100 lines — link to docs for details
- Never duplicate CLAUDE.md content in these files — CLAUDE.md is rules, state.md is state, architecture.md is structure
- When creating these files for a new project, read the codebase first (git log, directory structure, existing docs) to populate accurately

---

## Context Routing — Load Only What's Needed

Read `~/.claude/CONTEXT_ROUTING.md` for the full routing table. Key principle: **don't load all context every session.**

- **Default for implementation tasks:** project's state.md + architecture.md + CLAUDE.md. That's enough for 80% of work.
- **Research tasks:** load full OWNER-CONTEXT.md (subagents need everything for classification).
- **Modular context files at `~/.claude/context/`:** goals.md, projects.md, setup.md, income.md, content.md, research.md — load only the one(s) relevant to the current task.
- **When search returns >50 results**, refine the query with more specific terms rather than reading all results. Use `head_limit` parameter on Grep. Every irrelevant token competes for attention.

---

### Agent personalities available at `~/.claude/agents/`:

**Model-tier dispatch:** Each agent has a recommended model tier. Use `model` parameter on Agent tool. Haiku for grunt work (10-20x cheaper), Sonnet for standard work, Opus for architecture/strategy.

**Effort-level dispatch:** Each agent also specifies a thinking effort level (low/medium/high/max). Scouts and workers use `low`, doc reviewer uses `medium`, most reviewers/specialists use `high`, referee and architect use `max`. See each agent's header for the exact value.

**Context self-management:** Sub-agents that exceed 500K tokens must summarize findings and return partial results rather than degrading silently.

**debate/** — adversarial trio, always used together — **sonnet**
- `debate/skeptic.md` — assumes everything is wrong; finds edge cases, race conditions, security holes
- `debate/believer.md` — argues for the approach using evidence; pushes back on nitpicks
- `debate/referee.md` — arbitrates skeptic/believer; final ruling on what must ship vs what can wait

**reviewers/** — evaluate code, docs, security — **sonnet** (doc: haiku)
- `reviewers/code.md` — correctness, security, performance, complexity review (10 dimensions)
- `reviewers/doc.md` — accuracy, completeness, verifiability of documentation — **haiku**
- `reviewers/security.md` — adversarial security review; OWASP A1-A10, STRIDE, SAST

**specialists/** — domain expertise — **sonnet** (architect: opus)
- `specialists/architect.md` — system design, data model, abstractions, scale, failure modes — **opus**
- `specialists/platform.md` — backup compliance, DR, cron durability, operational continuity
- `specialists/frontend.md` — Core Web Vitals, bundle size, rendering strategy, React patterns

**scouts/** — external research — **haiku**
- `scouts/twitter.md` — Twitter/X data fetcher; bookmarks, tweets, search
- `scouts/github.md` — GitHub repo researcher; metadata, READMEs, file trees

**workers/** — task execution
- `workers/crawler.md` — web crawler via Cloudflare Browser Rendering API

Load these by reading the file and adopting the identity before dispatching an agent. Example: "Load `~/.claude/agents/debate/skeptic.md` as your identity and review this implementation."

---

## Context Compaction Strategy

- **Compact after research phases** — once you've gathered info and are about to implement, compact to free context for code work.
- **Compact between implementation phases** — after completing a logical chunk (e.g., one endpoint, one component), compact before starting the next.
- **NEVER compact mid-implementation** — if you're in the middle of writing a function or debugging, do not compact. You will lose critical state.
- **Use `/my-save` before manual compaction** — saves a session summary so context survives.
- **PreCompact hook auto-logs** — compaction events are logged to `.claude/sessions/compaction-log.txt` automatically.

---

## Hook Runtime Gating

Hooks can be toggled without editing `settings.json` using environment variables:

- **`ECC_HOOK_PROFILE`** — `minimal` (session persistence only), `standard` (default — adds formatting, tracking), `strict` (all hooks including guards)
- **`ECC_DISABLED_HOOKS`** — comma-separated hook IDs to skip (e.g., `stop:session-summary,post:edit:format`)

Hook IDs: `stop:usage-limit-resume`, `stop:session-summary`, `stop:cost-tracker`, `start:session-loader`, `compact:pre-save`, `post:edit:format`

Example: `ECC_HOOK_PROFILE=minimal claude` — runs with only essential hooks.

---

## Cross-Project Context

- **Port map & project index:** `~/.claude/projects/README.md` — global port assignments, project status, shared infra
- **Deep project docs:** `~/code/github/my-project/projects/<name>.md` — architecture, decisions, journey, problems
- Never duplicate what's in my-project. Reference it instead.

---

## Recommended `~/.claude/` Structure

```
~/.claude/
├── CLAUDE.md                    # This file — global rules (always active)
├── projects/                    # Cross-project settings (port map, index)
│   └── README.md                # Port map + project quick reference
├── agents/                      # Reusable agent personalities
│   ├── skeptic.md
│   ├── believer.md
│   ├── referee.md
│   ├── code-reviewer.md
│   ├── doc-reviewer.md
│   ├── security-reviewer.md
│   └── architect.md
└── skills/                      # Personal workflow skills
    ├── my-prompt/               # Transform rough ideas into disciplined prompts
    ├── my-create-acceptance-criteria/  # Create/reiterate acceptance criteria docs
    ├── my-git-sync/
    ├── my-save/
    ├── my-save-&-git-sync/
    ├── my-sync-all/
    ├── my-project-to-brain-sync/
    ├── my-research-targets/
    ├── my-my-project-find-potential-improvements/
    ├── my-claude-config-sync/
    ├── my-update-boilerplate-webapp/
    ├── my-show-info/              # Quick lookup for skills, hooks, agents, session, settings
    └── bug-hunt/
```

@RTK.md
