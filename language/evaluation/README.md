# Evaluation engine

This private subsystem gives operational meaning to admitted variable, lambda, application, and annotation syntax. It doesn't form types, check terms, normalize, quote values, define conversion, execute host callbacks, or expose evaluator authority through `language/default.nix`.

The public language attrset exposes no evaluation authority. Supported internal callers pass private envelopes, and evaluator entry points re-admit them before semantic dispatch. Importing an internal module directly does not turn matching records into public trusted evidence.

The direct evaluator is a small recursive statement of the equations. It is an oracle for bounded terms, not the deep-stack implementation. The machine uses `genericClosure` with `eval` and `return` control plus one `apply-operator` frame. Its state owns semantic-node count, semantic depth, transition fuel, trace, terminal value, and structured failure.

Evaluation is call by name. Application evaluates the operator and stores the operand as a syntax/environment thunk. A closure extends its captured environment with that thunk. Variable lookup forces a thunk when its absolute level is demanded, without updating or memoizing the cell. Neutral application appends the untouched thunk to its elimination spine.

An environment carries `nextLevel` and cells addressed by decimal absolute-level keys. Exact-key lookup doesn't traverse a positional spine. Extension doesn't derive meaning from key order. `hasAttr` distinguishes a missing level from a present lazy cell without forcing the cell. Decimal key spelling is representation, not semantic ordering.

A semantic value is a closure or neutral. A closure carries a validated body and creation environment. A neutral carries an absolute-level head and ordered elimination spine. An environment cell is either a semantic value or an unevaluated term with its environment.

Success includes open neutrals. Resource exhaustion distinguishes nodes, depth, and fuel. Internal failures use stable codes:

- `AXIOM-EVAL-001` means an environment lacked the requested level
- `AXIOM-EVAL-002` means validated syntax reached an unknown constructor
- `AXIOM-EVAL-003` means application received neither closure nor neutral
- `AXIOM-EVAL-004` means machine control, frame, or terminal state was impossible
- `AXIOM-EVAL-005` means lookup found an unknown environment-cell variant
- `AXIOM-EVAL-006` means a private semantic value came from a missing or stale evaluation generation

The defaults are 256 semantic nodes, depth 64 from root depth zero, and 4096 machine transitions. Node and depth limits are checked before the next term is inspected. A successful dispatch charges one node. Annotation erases its second child without a charge or event. Fuel is checked before each machine transition, and refusal reports the count before the refused operation. Syntax admission and evaluation keep separate budgets even where defaults match.

Trace events are prepended during evaluation and reversed once at the result boundary. Semantic events cover charge, lookup, force, closure creation, closure application, neutral application, and annotation erasure. Machine control and frame traffic aren't semantic events.

`projection.nix` is bounded test support. It may traverse complete closure environments by explicit recorded levels, so it isn't used for forcing claims. Evaluation never calls it. Its closed primitive output and host equality support implementation tests only; they don't define conversion or semantic equality.

Dependencies point from this subsystem into the private core representation and admission operations. Core, syntax, boundary policy, legacy `src/`, and the public facade don't import evaluation.

Change impact:

- a syntax constructor changes both evaluator dispatches, traces, generated agreement tests, and this contract
- a cell or value representation changes lookup, closure application, neutral spines, projection, poison gates, and internal-state fixtures
- a forcing change touches both equations, duplicated-thunk tests, inactive-operand gates, traces, and resource accounting
- a resource change touches charge sites, exact and one-over tests, deep-machine tests, and this contract
- a trace change touches both evaluators, projection, deterministic event tests, and equivalence gates
- an internal-state change touches its exact `AXIOM-EVAL-*` code and focused private fixture

Permanent gates from the repository root:

- `nix build --no-link -L .#checks.x86_64-linux.axiom-language`
- `nix flake check -L`
- `nix develop -c statix check .`
- `nix fmt -- --fail-on-change`
