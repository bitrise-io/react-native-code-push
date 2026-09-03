---
name: maintain-verification-skill
description: Periodic pass that keeps a project's verification skill accurate
disable-model-invocation: true
---

# Maintain a verification skill

The `verify-codepush` skill rots the moment the codebase changes. This skill is the maintenance tool for keeping the verification skill accurate and useful.

## Edit scope

Only edit the verification skill's own directory. Never edit product code during a run: a behavior the skill describes that the app no longer does is either doc drift (fix the skill) or a product regression (report it, don't paper over it in docs).

## Workflow

0. **Read the verification skill**: it lives at `.agents/skills/verify-codepush/`.

1. **Analyze features**: Spawn a subagent with the goal of understanding the major user flows and the behavior covered by the E2E test harness. Return shape: feature summary / source entry points / likely drift or none.

2. **Reconcile**: if the previous step returned drift, address it by updating the verification skill.

3. **Run the verification skill**: required even when the skill looks correct. Exercise every feature/behavior and what the skill claims to cover.

## Outcomes

Pick one:

- **clean**: the verification skill is accurate and covers all features and mechanisms of the codebase; nothing worth shipping. No branch, no PR.
- **changed** — one PR with required corrections.
- **blocked** — coverage could not finish or a proven fix could not ship safely. Say exactly what blocked it.
