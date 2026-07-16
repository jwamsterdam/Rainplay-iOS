# Review Rubric

Each agent must score the artifact, not the person.

## Scoring
0 = absent / dangerous
1 = poor
2 = weak
3 = acceptable with reservations
4 = good
5 = excellent

## Developer self-assessment
- Correctness: does the implementation satisfy the requested behavior?
- Minimality: is the diff as small as reasonably possible?
- Maintainability: is the Swift readable and idiomatic?
- Testability: is the code easy to test (pure logic, injectable seams)?
- Risk control: are known risks documented?

## Test Engineer assessment
- Behavior coverage: are core user paths covered?
- Edge cases: are likely boundary cases covered?
- Regression protection: would these tests catch future breakage?
- Test quality: are tests stable, readable, and not over-mocked?
- Evidence: were the build/test commands actually run?

## Software Architect assessment
- Pattern fit: does this follow existing project patterns and layer boundaries?
- Boundaries: are responsibilities cleanly separated (Logic/Services/State/Views)?
- Dependency discipline: are new/existing dependencies used appropriately?
- Complexity: is the solution no more complex than needed?
- Long-term maintainability: will this scale with the app?

## Gate rules
- Any score below 3 is blocking.
- Any security, data-loss, broken-build, or failing-test issue is blocking regardless of score.
- Average score below 4 requires at least one improvement iteration unless explicitly waived.
- Maximum 3 automatic iterations; after that, stop and summarize trade-offs.
