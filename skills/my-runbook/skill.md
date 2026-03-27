---
name: my-runbook
description: Use when debugging production issues, diagnosing service health, or investigating symptoms like "the app is slow", "API returns 500", "Docker container keeps restarting", "database connection refused". Structured symptom → investigation → diagnosis → report.
argument-hint: "< symptom description >"
---

# /my-runbook — Structured Debugging

Systematic investigation of production symptoms. Follows a symptom → investigation → diagnosis → action → report flow.

## Behavior

### 1. Identify Symptom

Ask (or infer from context) what the symptom is. Common categories:

| Symptom | Investigation Path |
|---------|-------------------|
| App slow / high latency | → Network, DB queries, CPU/memory, event loop |
| HTTP 5xx errors | → App logs, stack traces, dependency health |
| Container restarting | → Docker logs, OOM killer, health checks, exit codes |
| Connection refused | → Port binding, firewall, DNS, service status |
| Database issues | → Connections, slow queries, disk space, locks |
| High memory / CPU | → Process list, profiling, leak detection |
| Deployment failed | → CI logs, build output, migration status |

### 2. Triage — Gather Baseline

Run these in parallel to establish context:

```bash
# System health
uptime && free -h && df -h /

# Docker status (if applicable)
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null

# Recent logs (last 50 lines of relevant service)
docker logs --tail 50 <service> 2>/dev/null || journalctl -u <service> --no-pager -n 50

# Network — is the port listening?
lsof -i :<port> 2>/dev/null || ss -tlnp | grep <port>

# Process resource usage
ps aux --sort=-%mem | head -10
```

### 3. Investigate — Follow the Symptom

Based on triage results, dig deeper:

**For latency:**
```bash
# Check DB query performance
docker exec <db-container> psql -U <user> -d <db> -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE state = 'active' ORDER BY duration DESC LIMIT 5;"

# Check event loop (Node.js)
curl -s http://localhost:<port>/health | python3 -m json.tool

# Network latency to dependencies
curl -w "DNS: %{time_namelookup}s\nConnect: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" -o /dev/null -s <dependency-url>
```

**For container issues:**
```bash
# Exit code and OOM
docker inspect <container> --format '{{.State.ExitCode}} {{.State.OOMKilled}}'

# Resource limits vs usage
docker stats --no-stream <container>

# Health check status
docker inspect <container> --format '{{json .State.Health}}' | python3 -m json.tool
```

**For connection issues:**
```bash
# DNS resolution
dig <hostname> +short

# Port reachability
nc -zv <host> <port> 2>&1

# Firewall rules
sudo iptables -L -n 2>/dev/null | head -20
```

### 4. Diagnose

Based on investigation, state:
- **Root cause** (confirmed or suspected, with confidence level)
- **Impact** (what's affected, who's affected, data loss risk)
- **Evidence** (specific log lines, metrics, or observations)

### 5. Recommend Action

Propose fix with:
- **Immediate mitigation** (restart, rollback, scale)
- **Permanent fix** (code change, config update, infra change)
- **Prevention** (monitoring, alerting, test coverage)

### 6. Report

```
Runbook Report — <symptom>
══════════════════════════
Symptom: <what was reported>
Triage: <baseline findings>
Investigation: <what was checked and found>
Root Cause: <confirmed/suspected> — <description>
Confidence: High | Medium | Low
Impact: <scope>
Evidence:
  - <log line or metric>
  - <observation>
Immediate Action: <what to do now>
Permanent Fix: <what to change>
Prevention: <how to avoid recurrence>
```

## Gotchas

- Always check if SSH access is needed first — remote servers require `ssh user@host` prefix on all commands
- Docker logs rotate — if the issue happened hours ago, `--since 2h` may miss it; check log driver config
- `docker exec` fails on stopped containers — use `docker logs` instead
- PostgreSQL `pg_stat_activity` requires superuser or `pg_read_all_stats` role
- OOM kills don't always show in container logs — check `dmesg | grep -i oom` on the host
- Don't restart services before collecting evidence — you'll lose the diagnostic state

## Rules

- Gather evidence BEFORE taking action — restarting a service destroys diagnostic state
- State confidence level on every diagnosis — "suspected" vs "confirmed"
- Never run destructive commands (DROP, TRUNCATE, rm) during investigation
- If the issue is unclear after investigation, state what you ruled out and what remains
- Always propose prevention, not just fixes
