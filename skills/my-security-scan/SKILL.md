---
name: my-security-scan
description: Use when you need a security audit — runs SAST, dependency audit, secret detection, and STRIDE threat modeling on the current project. Also use for "security scan", "check for vulnerabilities", "audit security", or "find secrets".
argument-hint: "< full | sast | deps | secrets | stride > [target path]"
allowed-tools: Read, Glob, Grep, Bash(npx:*), Bash(pip:*), Bash(python3:*), Bash(pnpm:*), Bash(npm:*), Bash(cargo:*), Bash(go:*), Bash(semgrep:*), Bash(bandit:*), Bash(trivy:*), Bash(gitleaks:*), Bash(grep:*), Agent
---

# Security Scanning

Run automated security scans on the current project. Combines SAST, dependency auditing, secret detection, and threat modeling.

## Quick Help

**What**: Automated security scanning pipeline — finds vulnerabilities, leaked secrets, outdated deps, and builds threat models.
**Usage**:
- `/my-security-scan` or `/my-security-scan full` — run all scans
- `/my-security-scan sast` — static analysis only
- `/my-security-scan deps` — dependency vulnerability audit only
- `/my-security-scan secrets` — secret/credential detection only
- `/my-security-scan stride src/api/` — STRIDE threat model for specific paths
**Output**: Consolidated security report with findings sorted by severity.

## Steps

### 1. Detect Project Stack

| Signal | Detection |
|--------|-----------|
| Language | File extensions, config files |
| Package manager | `package.json` (npm/pnpm/yarn), `requirements.txt`/`pyproject.toml` (pip), `Cargo.toml` (cargo), `go.mod` (go) |
| Framework | Import patterns in source files |
| Existing security tooling | `.semgreprc`, `.banditrc`, `.eslintrc` security plugins, `.trivyignore`, `.gitleaksrc` |

### 2. SAST (Static Application Security Testing)

Run the appropriate scanner for the detected stack:

| Stack | Tool | Command |
|-------|------|---------|
| Polyglot / default | semgrep | `semgrep scan --config auto --json` |
| Python | bandit | `bandit -r <path> -f json` |
| JS/TS | eslint + security plugin | `npx eslint --plugin security --rule '...' <path>` |
| Go | gosec | `gosec -fmt json ./...` |
| Rust | cargo-audit patterns | `cargo audit --json` |

If the tool isn't installed, check if it can be run via `npx` or `pip` without global install. If not, fall back to manual grep-based scanning for common patterns:

```
# Manual SAST patterns (fallback)
- eval(, exec(, Function(          → code injection
- innerHTML, dangerouslySetInner   → XSS
- f"...{user_input}...", `${}`     → injection in queries
- subprocess.call(shell=True       → command injection
- os.path.join(user_input          → path traversal
- pickle.loads(                    → deserialization
- yaml.load( without Loader        → yaml deserialization
- JWT without expiry verification  → auth bypass
```

### 3. Dependency Audit

| Package Manager | Command |
|----------------|---------|
| npm/pnpm | `pnpm audit --json` or `npm audit --json` |
| pip | `pip audit --format json` (if pip-audit installed) or `python3 -m pip_audit` |
| cargo | `cargo audit --json` |
| go | `go list -json -m all` + check against vuln DB |

Parse results and classify:
- **CRITICAL**: Known exploited vulnerabilities (KEV list)
- **HIGH**: RCE, auth bypass, data exposure CVEs
- **MEDIUM**: DoS, information disclosure CVEs
- **LOW**: Theoretical or low-impact CVEs

### 4. Secret Detection

Scan for leaked credentials:

```bash
# Patterns to detect
- API keys: AKIA[0-9A-Z]{16}, sk-[a-zA-Z0-9]{48}, ghp_[a-zA-Z0-9]{36}
- Tokens: Bearer [a-zA-Z0-9._-]+, token["\s:=]+["'][a-zA-Z0-9]+
- Passwords: password["\s:=]+["'][^"']+, DATABASE_URL=.*:.*@
- Private keys: -----BEGIN (RSA |EC )?PRIVATE KEY-----
- Connection strings: postgresql://.*:.*@, mongodb://.*:.*@, redis://.*:.*@
```

Check these locations specifically:
- `.env` files (should be in `.gitignore`)
- Config files committed to git
- Test fixtures and seed data
- Docker files and compose files
- CI/CD config (`.github/workflows/`, `.gitlab-ci.yml`)

If `gitleaks` is available, prefer it: `gitleaks detect --source . --report-format json`

### 5. STRIDE Threat Model

For the target path(s), dispatch an agent with the security-reviewer identity:

> Load `~/.claude/agents/reviewers/security.md`. For the code at [target paths], build a STRIDE threat model. Map every endpoint, data flow, and trust boundary. For each STRIDE category, identify specific threats with attack vectors and mitigations. Output in the STRIDE table format from your identity doc.

### 6. Consolidate Report

```
## Security Scan Report
Project: [name] | Stack: [detected] | Date: [today]
Scans run: [list of scans executed]

### Summary
| Severity | SAST | Deps | Secrets | STRIDE | Total |
|----------|------|------|---------|--------|-------|
| CRITICAL | N | N | N | N | N |
| HIGH | N | N | N | N | N |
| MEDIUM | N | N | N | N | N |
| LOW | N | N | N | N | N |

### CRITICAL Findings (fix immediately)
| # | Source | Finding | Location | Fix |
|---|--------|---------|----------|-----|

### HIGH Findings (fix before ship)
[same format]

### MEDIUM Findings (schedule fix)
[same format]

### LOW Findings (track)
[same format]

### Dependency Vulnerabilities
| Package | Version | CVE | Severity | Fixed In | Action |
|---------|---------|-----|----------|----------|--------|

### Leaked Secrets
| File | Line | Type | Action |
|------|------|------|--------|

### STRIDE Threat Model
[from agent output]

### Recommendations
- [SAST tooling to install/configure]
- [Dependency update commands]
- [Secrets to rotate]
- [Architecture changes for threat mitigation]
```

## Gotchas

- SAST tools produce many false positives on generated code — verify findings before filing issues
- Secret detection flags .env.example files — exclude example/template env files

## Rules

- Never install tools globally without asking — use `npx`, `pipx`, or check if already installed first
- If a scan tool isn't available and can't be run ephemerally, fall back to grep-based patterns — don't skip the scan
- Leaked secrets are always CRITICAL — no exceptions
- Known exploited vulnerabilities (CISA KEV) are always CRITICAL
- Don't generate false positives from test files — flag them separately as "test-only, verify not shipped"
- STRIDE is optional for `full` scans on small changes — only auto-include for new endpoints, auth flows, or data pipelines
- This skill finds issues. Use the security-reviewer agent for deep manual analysis of specific findings.
