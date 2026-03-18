---
name: "devops-sre"
description: "DevOps and site reliability team for infrastructure design, CI/CD pipelines, observability setup, and operational reliability"
version: "1.0.0"
author: "Maestro"
agents:
  - role: infra-architect
    agent: "maestro:maestro-implementer"
    model: opus
    focus: "Infrastructure design, cloud architecture, and cost optimization. Produces architecture decisions, resource specifications, and the infrastructure plan that pipeline-builder and monitor execute against."
    tools: [Read, Grep, Glob, Write]
  - role: pipeline-builder
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "CI/CD pipelines, GitHub Actions workflows, and deployment automation. Consumes the infrastructure plan. Implements fail-fast pipelines with correct job ordering, caching, secret management, and rollback triggers."
    tools: [Read, Edit, Write, Bash, Grep, Glob]
  - role: monitor
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "Observability setup, alerting rules, and dashboard creation. Consumes the infrastructure plan. Instruments the four golden signals — latency, traffic, errors, saturation — and creates actionable alerts with appropriate thresholds."
    tools: [Read, Edit, Write, Bash, Grep, Glob]
orchestration_mode: dag
shared_context:
  - ".maestro/dna.md"
  - "CLAUDE.md"
quality_gates:
  - "Infra-architect produces explicit resource specifications and architecture decisions before implementation begins"
  - "No secrets are hardcoded in any pipeline or infrastructure configuration file"
  - "All deployments have health checks that must pass before receiving production traffic"
  - "Rollback procedure is defined and executable without manual steps"
  - "Monitoring covers all four golden signals with actionable alert thresholds"
  - "Pipeline runs lint and type-check before build before deploy — fail fast ordering enforced"
---

# Squad: DevOps / SRE

## Purpose

Design and operate infrastructure, CI/CD pipelines, and observability systems that make deployments safe, fast, and recoverable. This squad enforces an infrastructure-first discipline: an infra-architect defines the system design and resource specifications before pipelines or monitoring are built. Pipeline-builder and monitor then execute in parallel against a shared infrastructure plan, ensuring pipelines and observability are aligned to the actual deployment topology.

Use this squad when a story involves infrastructure changes, CI/CD pipeline work, monitoring setup, or any operational concern that affects how code moves from development to production.

## Agents

### infra-architect (opus)

The first agent to run. Defines the infrastructure strategy that pipeline-builder and monitor execute against.

Responsibilities:
- Design cloud architecture: compute, storage, networking, and edge topology
- Specify resource configurations: instance types, scaling policies, region selection, cost targets
- Define environment topology: how development, staging, and production differ and what they share
- Identify secrets and credentials: what exists, where it lives, how it is injected at runtime
- Define deployment strategy: blue-green, canary, rolling — and what triggers a rollback
- Specify health check endpoints and the conditions that constitute a healthy deployment
- Document the infrastructure plan that pipeline-builder and monitor receive as context

The infra-architect produces specifications and decisions, not working code. Its output is the contract that makes parallel implementation safe.

### pipeline-builder (sonnet)

Implements automated CI/CD pipelines against the infrastructure plan.

Responsibilities:
- GitHub Actions workflows (or equivalent) with correct trigger conditions
- Job ordering that enforces fail-fast: lint and type-check run before build, build before test, test before deploy
- Dependency caching to keep CI runtimes under 5 minutes for standard pipelines
- Secret injection from the CI/CD secret store — no secrets in configuration files, ever
- Build artifact versioning: each deployment produces a tagged, immutable artifact
- Deployment automation triggered by merge to the appropriate branch
- Health check validation before traffic is routed to new deployments
- Rollback trigger: automatic on health check failure, manual via workflow dispatch
- Environment variable documentation in example files alongside pipeline configuration
- Path filtering where appropriate: documentation changes should not trigger full deploys

### monitor (sonnet)

Instruments the running system to make failures visible and actionable.

Responsibilities:
- Observability for the four golden signals: latency (p50/p95/p99), traffic (requests per second), error rate (4xx/5xx by endpoint), and saturation (CPU, memory, queue depth)
- Structured log configuration: log levels, correlation IDs, sampling rates for high-volume paths
- Alert rules with thresholds set to signal real problems — not so sensitive they create noise, not so loose they miss incidents
- On-call runbooks linked from alert notifications: what the alert means, how to investigate, how to resolve
- Dashboards that give an operator situational awareness within 30 seconds of opening them
- Synthetic monitoring for critical user journeys: uptime checks, transaction monitors
- SLO definitions for user-facing surfaces with error budget burn rate alerts
- Deployment markers in dashboards so anomalies can be correlated to deploys

## Workflow

```
infra-architect
      |
      +-- pipeline-builder (parallel)
      |
      +-- monitor          (parallel)
```

1. **infra-architect** receives the story and produces: cloud architecture decisions, resource specifications, environment topology, secret inventory, deployment strategy, health check definitions, and rollback criteria. This output is added to context for pipeline-builder and monitor.

2. **pipeline-builder** and **monitor** run in parallel, each consuming the infra-architect's plan. They do not need to wait for each other. Pipeline-builder implements the deployment automation; monitor instruments the running system.

## Context Sharing

Every agent in this squad receives:
- `.maestro/dna.md` — Project DNA: cloud provider, deployment targets, existing tooling, operational conventions
- `CLAUDE.md` — Project-level rules all agents must follow

In addition:
- **pipeline-builder** and **monitor** receive the infra-architect's output as injected context
- If this is a re-dispatch after a prior failure, all agents receive the previous failure output and the specific rejection reason

## Quality Gates

1. **Architecture gate** — Pipeline-builder and monitor must not begin until infra-architect has produced explicit resource specifications, environment topology, and deployment strategy. Vague intent is not sufficient.
2. **Secret hygiene** — No secrets, API keys, tokens, or credentials appear in any configuration file committed to the repository. All secrets are referenced by name from the CI/CD secret store. Automatic rejection if violated.
3. **Health check gate** — Every deployment must configure a health check endpoint and route traffic only after it passes. Deploying without health checks is an automatic rejection criterion.
4. **Rollback coverage** — The pipeline must include an automated or manual rollback trigger. Rollback means re-deploying the previous artifact, not reverting code.
5. **Observability completeness** — Monitoring must cover all four golden signals. Missing any one (latency, traffic, errors, saturation) is a quality gate failure.
6. **Fail-fast ordering** — CI pipeline jobs must run in the correct cost order: lint/type-check first, then build, then test, then deploy. Running expensive steps before cheap checks wastes resources and slows feedback.
7. **Alert actionability** — Every alert must have a corresponding runbook or inline description that tells the on-call engineer what to investigate. Alerts without context create confusion during incidents.

## When to Use

- Setting up a CI/CD pipeline for a new service or significantly changing an existing one
- Cloud infrastructure changes: new resources, scaling configuration, region expansion
- Adding or overhauling monitoring and alerting for a service
- Incident response prep: improving observability after an incident to prevent recurrence
- Cost optimization: reviewing and right-sizing cloud resources
- Environment setup: configuring a staging environment, adding environment parity
- Any story where "how does this get to production?" and "how do we know it's healthy?" are open questions
