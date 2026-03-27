# aitmpl.com Ecosystem Report

> **Generated:** 2026-03-13
> **Source:** [aitmpl.com](https://www.aitmpl.com) / [github.com/davila7/claude-code-templates](https://github.com/davila7/claude-code-templates)
> **Purpose:** What to adopt, what to update — compared against our current setup (18 skills, 12 agents, 14 hooks, 10 plugins)

---

## What Can Be Adopted (Net-New)

### Plugins (from Anthropic Official + Community)

| Plugin | Source | What It Does | Why Adopt |
|--------|--------|-------------|-----------|
| **hookify** | anthropic official | Create/manage hooks via natural language rules; dynamic hook lifecycle | We have 14 static hooks maintained by hand. This lets us create situational hooks on the fly without editing `settings.json`. Huge maintenance win. |
| **plugin-dev** | anthropic official | Meta-tooling: agents for creating agents, skills for writing skills/hooks/commands | We build and maintain custom skills/agents regularly. This gives us scaffolding, validation, and best-practice enforcement for that work. |
| **pr-review-toolkit** | anthropic official | 6 specialized agents: silent-failure-hunter, type-design-analyzer, comment-analyzer, pr-test-analyzer, code-simplifier | Our code-reviewer is a generalist. These are scalpels — silent-failure-hunter alone catches a class of bugs our setup misses. |
| **agent-teams** | wshobson | Multi-agent coordination: team-spawn, team-delegate, parallel-debugging, parallel-feature-development | We dispatch agents one at a time. This adds coordinated multi-agent workflows with task delegation and status tracking. |
| **conductor** | wshobson | Track-based workflow: context-driven-development, track management | Structured feature development lifecycle. Complements superpowers' plan execution with persistent tracks. |
| **llm-application-dev** | wshobson | RAG implementation, prompt engineering patterns, vector index tuning, embedding strategies (8 skills) | Directly relevant when building AI features. We have nothing for RAG/embedding/vector work. |
| **incident-response** | wshobson | Incident runbook templates, on-call handoff patterns, postmortem writing, smart-fix command | We have bug-hunt for finding bugs but nothing for incident management workflow. |
| **observability-monitoring** | wshobson | Grafana dashboards, Prometheus config, distributed tracing, SLO implementation | We reference Grafana in cross-project context but have no skills for setting up/managing observability. |
| **context-management** | wshobson | context-save / context-restore commands | Simpler alternative to my-save for quick context snapshots. Could coexist. |

### Agents (from claude-code-templates + wshobson)

| Agent | Source | What It Does | Why Adopt |
|-------|--------|-------------|-----------|
| **prompt-engineer** | claude-code-templates | Specialized prompt optimization and evaluation | We have my-prompt for transforming rough thoughts, but no agent that evaluates/optimizes prompts adversarially. |
| **chaos-engineer** | claude-code-templates | Fault injection, resilience testing | We test for bugs (bug-hunt) and security (security-reviewer) but not for resilience/chaos scenarios. |
| **technical-debt-manager** | claude-code-templates | Identifies, prioritizes, and plans tech debt reduction | We have code-gaps-fix but it's criteria-focused. This is debt-lifecycle focused. |
| **dependency-manager** | claude-code-templates | Dependency audit, upgrade planning, vulnerability tracking | We block bare package manager usage (hooks) but don't proactively manage deps. |
| **changelog-generator** | claude-code-templates | Auto-generates changelogs from git history + PR context | We have nothing for release documentation. |
| **diagram-architect** | claude-code-templates | Generates architecture diagrams (Mermaid, PlantUML) | We have architect agent for review but no diagram generation capability. |
| **research-coordinator** | claude-code-templates | Orchestrates multi-agent research workflows | Our my-research-targets dispatches scouts. This adds coordination layer for complex research. |
| **fact-checker** | claude-code-templates | Verifies claims, cross-references sources | Anti-sycophancy complement — verifies factual claims in docs/code comments. |

### Commands (from claude-code-templates)

| Command | Source | What It Does | Why Adopt |
|---------|--------|-------------|-----------|
| **generate-tests** | claude-code-templates | Auto-generates test suites for existing code | We enforce TDD via superpowers but have no command to backfill tests on existing code. |
| **security-audit** | claude-code-templates | Comprehensive security scan with OWASP checklist | Our security-reviewer agent does this manually. A command makes it one-shot. |
| **optimize-bundle-size** | claude-code-templates | Bundle analysis + optimization suggestions | Relevant for frontend projects (your frontend projects). No equivalent today. |
| **setup-monitoring-observability** | claude-code-templates | Scaffolds monitoring/alerting infrastructure | Pairs with observability-monitoring plugin above. |
| **project-health-check** | claude-code-templates | Multi-dimensional project health assessment | We have code-gaps-fix and review-docs but no unified health score. |
| **retrospective-analyzer** | claude-code-templates | Sprint/project retrospective with actionable insights | Useful for knowledge-base project tracking. Nothing equivalent. |

### Skills (from alirezarezvani + claude-code-templates)

| Skill | Source | What It Does | Why Adopt |
|-------|--------|-------------|-----------|
| **Product Manager** | alirezarezvani | PRD writing, feature prioritization, roadmap planning | We create acceptance criteria but have no product management workflow. |
| **Data Analyst** | alirezarezvani | Data exploration, statistical analysis, visualization | No data analysis capability in current setup. |
| **Marketing skills (Content Pod)** | alirezarezvani | Content creation, copywriting, social media management (8 skills) | Relevant for X/LinkedIn content posting (referenced in my-research-targets). |
| **ISO 27001 Specialist** | alirezarezvani | Information security compliance | Complements security-reviewer with standards-based compliance checks. |
| **GDPR Specialist** | alirezarezvani | Data protection compliance | Relevant for any project handling user data. |
| **Self-Improving Agent** | alirezarezvani | Agent that analyzes its own performance and improves | Meta-capability for improving our agent fleet. |

### Hooks

| Hook | Source | What It Does | Why Adopt |
|------|--------|-------------|-----------|
| **telegram-pr-webhook** | claude-code-templates | Sends Telegram notifications on PR events | We have no notification system. Useful if you want mobile alerts on PR activity. |
| **bash_command_validator** | anthropic examples | Validates bash commands before execution (Python-based) | More sophisticated than our block-destructive.sh — uses pattern matching with allowlists. |

---

## What Can Be Updated (Existing Items With Better Alternatives)

### Agents

| Our Agent | External Alternative | Source | What's Better | Recommendation |
|-----------|---------------------|--------|--------------|----------------|
| **code-reviewer** | pr-review-toolkit (6 agents) | anthropic official | Splits review into specialized roles: silent-failure-hunter catches implicit errors, type-design-analyzer reviews type architecture, code-simplifier suggests simplifications. Our generalist misses these niches. | **Supplement** — keep our code-reviewer as the generalist, add pr-review-toolkit agents for deep dives. |
| **security-reviewer** | security-scanning plugin | wshobson | Adds STRIDE analysis, attack-tree construction, SAST configuration skills. Our reviewer checks OWASP but doesn't build threat models or configure scanners. | **Supplement** — add threat-modeling and SAST skills to our security workflow. |
| **architect** | c4-architecture plugin | wshobson | Adds C4 model generation (context, container, component, code diagrams). Our architect reviews but doesn't produce structured architecture artifacts. | **Supplement** — add C4 command for generating architecture docs. |
| **bug-hunt** | systematic-debugging (superpowers) | obra/superpowers | 4-phase root cause analysis vs our 3-agent adversarial approach. Different strengths — superpowers is more methodical, ours is more adversarial. | **No change** — both are installed. Use systematic-debugging for methodical debugging, bug-hunt for adversarial sweeps. |
| **twitter-scout** | twitter-ai-influencer-manager | claude-code-templates | Adds engagement optimization, posting schedule, audience analysis. Our scout only fetches and classifies. | **Update if** you want to post content, not just research. Low priority otherwise. |
| **platform-engineer** | cloud-infrastructure plugin | wshobson | 7 agents + 8 skills covering multi-cloud, service mesh, cost optimization, Terraform modules. Our platform-engineer is one generalist agent. | **Supplement** — adopt cloud-infrastructure if working on infra-heavy projects. |

### Skills

| Our Skill | External Alternative | Source | What's Better | Recommendation |
|-----------|---------------------|--------|--------------|----------------|
| **my-git-sync** | commit-commands plugin | anthropic official | Adds commit-push-pr (single command for commit → push → PR creation) and clean_gone (prunes merged branches). Our skill doesn't create PRs or clean branches. | **Update** — add PR creation and branch cleanup to my-git-sync, or install commit-commands alongside. |
| **my-save** | context-management plugin | wshobson | Adds context-restore (our my-get-me-up2speed reads summaries but doesn't restore full context). | **Evaluate** — test if context-restore meaningfully improves session continuity vs our summary approach. |
| **my-create-acceptance-criteria** | Product Manager skill | alirezarezvani | Product Manager covers PRD → acceptance criteria → roadmap as a full lifecycle. Our skill is criteria-only. | **No change** — our focused approach is better for the gate rule. Consider Product Manager for greenfield projects. |
| **my-code-gaps-fix** | agent-teams plugin | wshobson | Multi-agent coordination with status tracking vs our parallel dispatch. Agent-teams adds team-status and inter-agent communication. | **Evaluate** — if code-gaps-fix dispatch becomes unwieldy, migrate to agent-teams coordination. |

### Hooks

| Our Hook | External Alternative | Source | What's Better | Recommendation |
|----------|---------------------|--------|--------------|----------------|
| **block-destructive.sh** | bash_command_validator.py | anthropic examples | Python-based with regex allowlists, more configurable than our shell script. | **Update** — port the allowlist pattern to our hook for better configurability. |
| **Static hook system** | hookify plugin | anthropic official | Dynamic rule creation/deletion without restarting. Our hooks require settings.json edits + session restart. | **Adopt hookify** — use for situational rules, keep static hooks for permanent guards. |

### Plugins

| Our Plugin | External Alternative | Source | What's Better | Recommendation |
|------------|---------------------|--------|--------------|----------------|
| **claude-mem** | Built-in memory system | claude code native | We already have file-based memory in `~/.claude/projects/*/memory/`. claude-mem may duplicate or conflict. | **Evaluate** — check if claude-mem adds value beyond native memory. If not, disable to reduce complexity. |

---

## Priority Tiers

### Tier 1 — Adopt Now (High Value, Low Effort)

| Item | Type | Why Now |
|------|------|---------|
| **hookify** | Plugin | Biggest maintenance win. Dynamic hooks without settings.json edits. |
| **pr-review-toolkit** | Plugin | Catches bug classes our generalist code-reviewer misses. Official Anthropic plugin. |
| **plugin-dev** | Plugin | We build skills/agents regularly. This is the meta-tool for that. |
| **generate-tests** | Command | Backfill tests on existing code. Pairs with superpowers TDD for new code. |

### Tier 2 — Adopt Soon (High Value, Medium Effort)

| Item | Type | Why Soon |
|------|------|----------|
| **agent-teams** | Plugin | Multi-agent coordination is our next evolution beyond single-dispatch. |
| **llm-application-dev** | Plugin | RAG/embedding skills needed when building AI features. |
| **security-scanning** | Plugin | Threat modeling + SAST fills gaps in our security workflow. |
| **incident-response** | Plugin | Incident management workflow missing entirely. |
| **c4-architecture** | Plugin | Architecture diagrams complement our architect agent. |

### Tier 3 — Evaluate (Potentially Valuable, Needs Testing)

| Item | Type | Why Evaluate |
|------|------|-------------|
| **conductor** | Plugin | Track-based workflow might overlap with superpowers plan execution. Test for conflicts. |
| **context-management** | Plugin | Test if context-restore beats our summary-based approach. |
| **claude-mem** | Plugin (existing) | May conflict with native memory. Audit for redundancy. |
| **Marketing skills** | Skills | Only valuable if actively posting content. Low priority otherwise. |
| **bash_command_validator** | Hook | Better than block-destructive but requires porting patterns. |

---

## Sources

| Source | URL | Items | License |
|--------|-----|-------|---------|
| aitmpl.com / claude-code-templates | [github.com/davila7/claude-code-templates](https://github.com/davila7/claude-code-templates) | 300+ agents, 280+ commands, 35+ skills | MIT |
| Anthropic claude-code | [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code) | 11 official plugins | Apache 2.0 |
| obra/superpowers | [github.com/obra/superpowers](https://github.com/obra/superpowers) | 14 skills (already installed) | MIT |
| alirezarezvani/claude-skills | [github.com/alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) | 60+ professional role skills | MIT |
| wshobson/agents | [github.com/wshobson/agents](https://github.com/wshobson/agents) | 55+ plugins, 112+ agents | MIT |
