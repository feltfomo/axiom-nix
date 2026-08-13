# Evaluation

Evaluation provides two independent weak-head call-by-name witnesses over the same admitted syntax and semantic representation.

Generation: `axiom-evaluation-2`.

## Evaluators

`direct.nix` owns a recursive equation interpreter. Its local `evaluate`, `demand`, `apply`, and `eliminate` functions use Logismos computation composition for state, sequencing, and failure propagation. It is not a second explicit machine.

`machine.nix` owns a closed eval/return transition algebra executed by `logismos.transition.run`. Machine frames use the private persistent owner in `language/logismos/stack.nix`.

Both evaluators independently own live closed term and eliminator handler inventories, demand, application, canonical eliminator selection, and neutral eliminator construction. The handler inventories drive dispatch and are checked against the admitted constructor and eliminator sets.

Neither evaluator imports or calls the other.

## Shared substrate

The evaluators may share only:

- representation and schema
- result constructors and materializers
- the evaluation-specific budget algebra
- core admission
- Logismos composition operators
- test-only projection

No shared evaluation-local module selects an equation from `term.kind` or selects canonical or neutral elimination from a semantic value kind.

## Resource algebra

`language/evaluation/budget.nix` owns the Logismos `{ depth, fuel, nodes }` vector.

Named costs are:

- semantic node: `{ depth = 0; fuel = 0; nodes = 1; }`
- machine step: `{ depth = 0; fuel = 1; nodes = 0; }`

Default limits remain 256 nodes, depth 64, and fuel 4096.

Direct evaluation uses node/depth charging. Machine evaluation charges fuel before control or frame access, then charges node/depth before `term.kind`. Depth refusal precedes node refusal. Failed charges preserve pre-operation usage. Direct successes omit fuel; machine successes include it.

## Weak-head call-by-name laws

Applications evaluate the operator and retain the argument as a thunk. Closures retain raw bodies and environments. Only demand evaluates a thunk.

Inactive arguments, branches, motives, family bodies, pair components, identity endpoints, and unrelated environment cells remain unforced until the selected local equation demands them.

Generation checks inspect the owning stamp before cell, function, environment, frame, or semantic payload variants.

Neutral eliminations extend the persistent newest-first spine in constant time. Bounded test projection restores semantic order.

## Agreement projection

Production evaluation has no projection owner. `language/evaluation/projection.nix` remains deleted.

`language-tests/support/projection.nix` is the sole projection owner. It uses a bounded closed Logismos traversal with explicit value, cell, closure, environment, and spine-item descriptors. Operational cursors are bounded transitions. Ordered collections use prepend plus one reverse, and environment cells are assembled with one `builtins.listToAttrs` after generated-level uniqueness is established.

Recursive equality and `builtins.toJSON` are permitted only on the fully projected bounded first-order test value. Raw semantic values, closures, environments, cells, and opaque payloads never reach a deep observer.

## Independence and agreement gates

The evaluation suite proves:

- complete local constructor and eliminator inventories in both evaluators
- no direct-to-machine or machine-to-direct dependency
- no semantic dispatch in shared evaluation-local modules
- projected value and semantic trace agreement
- negative sensitivity to changed projected values and trace events
- exact and one-over node, depth, and fuel behavior
- applicable direct/machine resource-trace prefix agreement
- inactive-term forcing isolation
- generation ownership
- bounded projection and neutral-spine order
- existing Logismos stack ownership
- zero evaluation imports of obsolete internal worklist/spine owners

`language/internal/worklist.nix` and `language/internal/spine.nix` remain present for live out-of-scope consumers. No compatibility shim is added.
