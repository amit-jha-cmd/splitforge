# AGENTS.md — how agents build in this repo

These rules are **mandatory** for every change: features **and** bug fixes. They encode an adversarial, no-rubber-stamp process the project owner requires.

## The workflow

1. **Plan before code.** No implementation begins without a written plan for the feature/bugfix.
2. **Plan-critic loop (simplicity gate).** After drafting a plan, spawn a **fresh** critic agent whose sole lens is *"the simplest architecture that still meets every requirement."* Address its feedback, spawn a **new** critic (never reuse the previous one), and loop until it returns `APPROVED` with no open issues.
3. **User approval gate.** After the plan is critic-approved, get explicit user approval **before** writing any code.
4. **Milestone decomposition.** Every feature and every bug fix is broken into milestones. Each milestone is independently implementable and testable.
5. **Tests are mandatory.** Each milestone ships with unit tests — or integration/host-harness tests where unit testing isn't feasible (firmware, IOKit). Tests must **pass** before requesting critic approval.
6. **Post-implementation critic loop (no skipping).** After implementing a milestone, spawn a **fresh** critic and give it the **explicit list of every changed/added file**. It must review **all of them without skipping**, returning per-file findings and a verdict. The implementing agent fixes the findings, then spawns **another fresh** critic. Loop until the critic returns `APPROVED` for **all files** — no skips, no open issues.
7. **Fresh agent every round.** Each critic round uses a clean-context agent to prevent rubber-stamping.
8. **Critic output contract.** A critic returns exactly `APPROVED` or `CHANGES_REQUESTED`, a per-file list of findings (file → issues), and must confirm tests are green. Because a fresh critic has no memory of a prior run, it verifies tests by **re-running the milestone's test command itself** (e.g. `swift test`) or by being handed the full test-run transcript — never on faith. Approval is invalid if any listed file was skipped.
9. **Non-convergence escalation.** If a critic loop hasn't converged after **3 rounds**, stop and surface the disagreement to the user rather than looping indefinitely.
10. **Definition of done (per milestone):** code + passing tests + critic-approved (all files) + docs updated.

## Critic prompt contract (for the caller)

When spawning a critic, give it:
- The **exact list of changed/added files** (absolute paths) — instruct it to review **every one, no skipping**.
- The **milestone's requirements** and how to run the tests.
- The required output: line 1 `VERDICT: APPROVED` or `VERDICT: CHANGES_REQUESTED`, then per-file findings.

## Repo conventions

- Pure logic (decoding, protocol framing, model assembly, state machines, settings) lives in `SplitForgeCore` with **no IOKit/AppKit imports**, so it is fully unit-testable. Side-effecting boundaries (HID, windows, login items) sit behind protocols with mocks in tests.
- Match the surrounding code's style. Keep the architecture as simple as the requirements allow.
