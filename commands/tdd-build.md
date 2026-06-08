---
name: tdd-build
description: Test-Driven Development build workflow. Writes failing tests first, implements iteratively until green, then refactors. Tracks iteration count and reports which tests were hardest to pass.
---

# /tdd-build -- Test-Driven Autonomous Build

**Usage:** `/tdd-build <feature-description>`
**Example:** `/tdd-build "a dark mode toggle with system preference detection"`

## When to Use

- You want strict TDD: tests written FIRST, verified to FAIL, then implementation
- You want autonomous implementation without stopping for input
- You want iteration tracking and a difficulty report
- NOT for: non-TDD features (use @engineer directly)

**Cost:** 1-2 agent spawns (sonnet). @engineer writes the failing tests, then implements to green.

## Process

### Setup
1. Check for test runner (`vitest.config.*`, `jest.config.*`, or `test` script in `package.json`)
2. If no test runner, set up Vitest with TypeScript support
3. Confirm `npm test -- --run` executes without config errors

### Step 1: RED -- Write Failing Tests
Invoke @engineer via Task tool (or write them inline) to add comprehensive failing tests covering:
- Happy path (core functionality)
- Edge cases (empty states, boundaries, special characters)
- Error handling (invalid input, missing data)
- Integration boundaries (data flows between components)

Verify ALL new tests FAIL before proceeding.

### Step 2: GREEN -- Implement Iteratively
```
iteration = 0
while (failing tests > 0 AND iteration < max_iterations):
    iteration += 1
    1. Read the first failing test
    2. Write minimum code to make it pass
    3. Run tests
    4. If a previously passing test broke -> fix regression FIRST
    5. Continue to next failing test
```

Rules: simplest code that passes, no features beyond what tests specify, run tests after EVERY change.

### Step 3: REFACTOR
With all tests green: remove duplication, extract functions, improve naming, remove dead code. Run tests after each refactor.

### Step 4: Final Verification
Run the full gate: `npm test -- --run && npx tsc --noEmit && npm run build`

### Step 5: TDD Summary Report
Report: total iterations, test count, tests modified (with reasons), difficulty ranking, tests by category, key learnings.

## Anti-Rationalization

| Thought | Reality |
|---------|---------|
| "This function is too simple to test" | Simple functions have simple tests. Write them. |
| "I'll write the implementation first, then add tests" | That's not TDD. The test comes first. Always. |
| "Tests are slowing me down" | TDD is faster. You catch bugs at write time, not debug time. |
| "I can skip the refactor step" | Green is not done. Refactor removes the shortcuts you took to get green. |
| "One test per function is enough" | One test per behaviour. A function with 3 branches needs 3+ tests. |

## Exit Criteria

- [ ] All tests passing (green)
- [ ] TypeScript compiles without errors
- [ ] Build succeeds
- [ ] Refactoring complete
- [ ] TDD summary report produced
- [ ] No test was written AFTER implementation

## Failure Recovery

| Problem | Action |
|---------|--------|
| Test runner not configured | Set up Vitest/Jest, return to setup |
| Tests pass immediately | Tests are wrong — rewrite them to test new behaviour |
| Stuck on same test 5+ iterations | Skip, note in report, try next test |
| Previously passing test breaks | Fix regression first (counts as iteration) |
| Type errors after green | Fix types, re-run tests |
| Build fails after tests pass | Fix build issue, re-run tests |
