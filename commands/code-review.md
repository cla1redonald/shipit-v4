---
name: code-review
description: Structured code review for quality and security. Use before merging code or when you want a security/quality audit.
---

# /code-review -- Structured Code Review

**Usage:** `/code-review`
**Example:** `/code-review` (reviews the current branch's changes against main)

## When to Use

- Before merging a feature branch
- When you want a security/quality audit of recent changes
- After a significant implementation to catch issues early
- NOT for: the full gate run + PR open workflow (use `/ship`)

**Cost:** Single sonnet agent. Lightweight.

## Process

1. **Get the diff.** Run `git diff main` (or appropriate base branch) to see all changes.
2. **Invoke @reviewer.** Spawn via Task tool with the diff and the review checklist below.
3. **Present findings.** Categorize by severity (Must Fix / Should Fix / Nice to Have).
4. **Deliver verdict.** Ready to ship / Fix and re-review / Major rework.

### Review Checklist

**Security (Must Pass):**
- [ ] Input validation on all user input
- [ ] No injection risks (SQL, XSS, command)
- [ ] Secrets not exposed in code
- [ ] Auth checks on protected routes
- [ ] Database access control configured

**Code Quality:**
- [ ] Functions are small and focused
- [ ] Names are clear and descriptive
- [ ] No `any` types without justification
- [ ] Error handling present
- [ ] Type propagation complete for new fields

**Performance:**
- [ ] No N+1 query patterns
- [ ] No unnecessary re-renders
- [ ] Bundle size considered

**Testing:**
- [ ] Tests exist for new functionality
- [ ] Happy path + error cases covered
- [ ] Build command matches what CI runs

**Maintainability:**
- [ ] Code understandable without author explanation
- [ ] Consistent with existing codebase patterns
- [ ] No dead code or merge conflict markers

## Anti-Rationalization

| Thought | Reality |
|---------|---------|
| "The code looks fine, I don't need to run it" | Reading is not reviewing. Run the tests. Check the build. |
| "It's just a style issue" | Consistency matters. Flag as Nice to Have, but flag it. |
| "Tests pass, so it must be correct" | Tests verify what they test. Check for missing test cases. |
| "This is too small to review" | Small changes cause big breaks. Review everything. |

## Exit Criteria

- [ ] Every changed file reviewed
- [ ] All findings categorized by severity
- [ ] Security checklist completed
- [ ] Clear verdict delivered

## Failure Recovery

| Problem | Action |
|---------|--------|
| @reviewer fails to invoke | Retry once, then do the review inline |
| No diff (no changes) | Nothing to review — report clean |
| Verdict is "Major rework" | Stop and present findings to user for guidance |
