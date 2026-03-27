---
name: my-plugin-dev
description: Use when creating new Claude Code extensions — scaffolds, validates, and tests skills, agents, hooks, and commands. Also use for "create a skill", "new hook", "build agent", or "scaffold plugin".
argument-hint: "< skill | agent | hook | command > [name] [description]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(bash:*), Bash(cat:*), Bash(chmod:*), Bash(ls:*)
---

# Plugin Dev — Build Skills, Agents, Hooks, Commands

Scaffold, validate, and iterate on Claude Code configuration components. Enforces the conventions already established in this setup.

## Quick Help

**What**: Create or validate skills, agents, hooks, and commands using established patterns.
**Usage**:
- `/my-plugin-dev skill my-deploy "Deploy current branch to staging"` — scaffolds a new skill
- `/my-plugin-dev agent ux-researcher "User research and usability analysis"` — scaffolds a new agent
- `/my-plugin-dev hook block-large-writes "Block Write tool for files >500 lines"` — scaffolds a new hook
- `/my-plugin-dev validate` — validate all existing skills/agents/hooks for structural issues
**Output**: Ready-to-use files in the correct locations, following existing conventions.

## Steps

### 1. Parse Intent

| Argument | Action |
|----------|--------|
| `skill <name> <desc>` | Create skill at `~/.claude/skills/<name>/skill.md` |
| `agent <name> <desc>` | Create agent at `~/.claude/agents/<name>.md` |
| `hook <name> <desc>` | Create hook script at `~/.claude/hooks/<name>.sh` + settings.json entry |
| `command <name> <desc>` | Create command at `~/.claude/commands/<name>.md` |
| `validate` | Scan all components for structural issues |
| No argument | Interactive — ask what to build |

### 2. For SKILL — Scaffold from Convention

Read 2-3 existing skills to extract the pattern, then generate:

```markdown
---
name: <name>
description: <desc>
argument-hint: [contextual hint]
allowed-tools: [minimal set needed]
---

# <Title>

<One-line purpose>

## Quick Help

**What**: <what it does>
**Usage**:
- `/<name>` — <default behavior>
- `/<name> <arg>` — <with argument>
**Safety**: <guardrails>

## Steps

### 1. <Step>
...

## Rules

- <rule>
```

Checklist before writing:
- [ ] Name is prefixed with `my-` (user convention)
- [ ] `allowed-tools` is minimal — no tools that aren't used
- [ ] Quick Help section exists
- [ ] Steps are numbered and concrete
- [ ] Rules section exists with guardrails

### 3. For AGENT — Scaffold from Convention

Read 2-3 existing agents to extract the pattern, then generate:

```markdown
# <Name> Agent

## Identity

You are the <Name>. <2-3 sentences defining perspective, priorities, and what you do NOT care about.>

You operate under the CLAUDE.md global rules by default:
- Correctness over plausibility
- Acceptance criteria first
- Complexity budget enforced
- Self-review honesty required

## <Primary Review/Work Dimensions>

### 1. <Dimension>
- <specific questions to answer>

...

## Output Format

\```
## <Section>
[structured output]

## Verdict
<VERDICT_OPTIONS>
\```

## Rules

- <rules specific to this agent's role>
```

Checklist before writing:
- [ ] Identity section defines what the agent DOES and DOES NOT care about
- [ ] CLAUDE.md global rules referenced
- [ ] Dimensions are ordered by priority
- [ ] Output format is structured and machine-parseable
- [ ] Verdict uses a finite set of options
- [ ] Rules are specific, not generic

### 4. For HOOK — Scaffold and Register

Generate the script:

```bash
#!/usr/bin/env bash
# Hook: <name>
# Purpose: <desc>
# Event: <PreToolUse|PostToolUse|Stop|SessionStart|PreCompact>
# Created: <date>

# Source hook-gate for ECC_HOOK_PROFILE / ECC_DISABLED_HOOKS support
HOOK_ID="<event>:<name>"
if [[ -f "$HOME/.claude/hooks/hook-gate.sh" ]]; then
  source "$HOME/.claude/hooks/hook-gate.sh"
fi

<implementation>
```

Then:
1. Write script to `~/.claude/hooks/<name>.sh`
2. `chmod +x` the script
3. Run `bash -n` to validate syntax
4. Add entry to `settings.json` hooks (via my-hookify logic — backup, jq validate, write)

### 5. For VALIDATE — Audit All Components

Scan and report:

| Check | Target | Pass Criteria |
|-------|--------|--------------|
| Skill frontmatter | `~/.claude/skills/*/skill.md` | Has name, description, allowed-tools |
| Skill Quick Help | Same | Has Quick Help section |
| Agent identity | `~/.claude/agents/*.md` | Has Identity section, Output Format, Verdict |
| Hook syntax | `~/.claude/hooks/*.sh` | `bash -n` passes |
| Hook registered | `settings.json` | Script exists for every registered hook |
| Orphan scripts | `~/.claude/hooks/` | Flag scripts not in settings.json |

Output a table of findings.

## Gotchas

- Skills installed via `npx skills add` go to a different directory than `~/.claude/skills/` — check both locations
- SKILL.md frontmatter name must match the directory name (kebab-case) or validation fails
- Description must be under 1024 chars with no angle brackets

## Rules

- Always read existing components before generating — match the established style
- Skills MUST be prefixed with `my-` per user convention
- Never generate a component that duplicates existing functionality — check first
- `allowed-tools` must be minimal. Justify every tool in the list.
- Every skill must have a Quick Help section
- Every agent must have structured Output Format and Verdict
- Every hook must source hook-gate.sh for profile/disable support
- Run `bash -n` on every generated shell script
- Validate settings.json with `jq .` after any modification
