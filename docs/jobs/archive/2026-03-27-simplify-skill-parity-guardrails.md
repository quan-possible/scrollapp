---
codex_session_id: 019d30ee-43f9-7ff3-9fa7-a131ad064bb0
codex_session_ids:
  - 019d30ee-43f9-7ff3-9fa7-a131ad064bb0
---

# Simplify Skill Parity Guardrails

## Objective
- Strengthen the live `simplify` skill so behavior-preserving simplification requires a baseline, a rollback-safe checkpoint, and an explicit parity gate before sign-off.

## Scope
- `/Users/brucenguyen/My Drive (trungqua@ualberta.ca)/.codex/skills/execution/simplify/SKILL.md`
- `/Users/brucenguyen/.codex/notes/simplify_minimum_effective_design_principles.md`

## Guardrails
- Keep the workflow lightweight enough for normal use.
- Require real user-visible parity checks for behavior-sensitive simplification.
- Do not make remote pushes the default checkpoint strategy.
