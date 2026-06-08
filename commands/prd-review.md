---
name: prd-review
description: Review and improve a Product Requirements Document before starting development. Use when validating a PRD for completeness, clarity, and feasibility.
---

# /prd-review -- PRD Validation

**Usage:** `/prd-review`
**Example:** `/prd-review` (reviews the PRD in the current project)

## When to Use

- You have a PRD that needs validation before building
- You want to catch gaps, ambiguity, and scope issues before they become code problems
- After a PRD is produced and before the build starts
- NOT for: creating a PRD from scratch (use a PRD / discovery workflow)

**Cost:** No agent spawns. Runs inline.

## Process

1. **Find the PRD.** Look for `docs/prd.md`, `PRD.md`, or a file matching the project name.
2. **Review against checklist** (see below).
3. **Produce review report** with strengths, issues, questions, and verdict.
4. **Present to user** for action.

### Review Checklist

**Problem Definition:**
- [ ] Problem clearly stated
- [ ] Target user identified
- [ ] Pain point specific and relatable
- [ ] Current workaround documented

**Solution:**
- [ ] Solution addresses the core problem
- [ ] MVP scope ruthlessly minimal
- [ ] Success criteria measurable
- [ ] Out of scope explicitly stated

**Technical Feasibility:**
- [ ] Fits within chosen stack (or stack is specified)
- [ ] No obvious technical blockers
- [ ] Data model reasonable
- [ ] Security considerations noted

**UX/UI:**
- [ ] Main user flows described
- [ ] Key screens identified
- [ ] Mobile responsiveness addressed

**Threads (if present):**
- [ ] Threads are self-contained
- [ ] Reasoning levels assigned
- [ ] File references specific
- [ ] Validation targets defined

## Anti-Rationalization

| Thought | Reality |
|---------|---------|
| "The PRD is good enough to start building" | Ambiguous requirements cause rework. 10 minutes of review saves days. |
| "We can clarify during implementation" | Clarifying during implementation means context-switching and rework. Clarify now. |
| "The scope is obvious" | If the scope is obvious, writing "Out of Scope" takes 30 seconds. Do it. |
| "Success criteria can come later" | Without success criteria, you can't know when you're done. Define them now. |

## Exit Criteria

- [ ] All checklist items evaluated
- [ ] Issues documented with specific suggestions
- [ ] Questions listed for user clarification
- [ ] Clear verdict: Ready to build / Needs revision / Major gaps

## Failure Recovery

| Problem | Action |
|---------|--------|
| No PRD found | Ask the user for the PRD location or to run a PRD / discovery workflow |
| PRD too vague to review | Flag as "Major gaps" — needs a rewrite before review |
| Technical feasibility unclear | Flag specific concerns, recommend an architecture assessment |
