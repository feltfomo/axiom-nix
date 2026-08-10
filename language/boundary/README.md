# Host boundary

This subsystem observes arbitrary Nix values. Its records are boundary-checked information about one named crossing, not types, proofs, core nodes, or trusted annotations. Public result shapes are forgeable. Recognition checks control-field shape and never authenticates a producer or forces a payload.

`opaque` doesn't force the value. Its success uses a null category to mean unobserved. `outer` performs one guarded `typeOf`. Nix `set` maps to `attrs` and `lambda` maps to `function`. Derivations stay `attrs`; context-bearing strings stay `string`.

Policy names, budget names, callback expectations, selected-field specifications, and observation-plan nodes are inspected by separate guarded operations. Successfully observed malformed control data is a boundary mismatch. A catchable failure while inspecting hostile control data is a host failure.

The forcing policies are `opaque`, `outer`, `spine`, `selected-fields`, and `typed-deep`. Lists use increasing indices. Attr plans use lexicographically sorted field names. Selected fields use declaration order. Paths record list entries as `index:N` and fields as `field:name`.

The root is depth 0. A demanded node is charged before observation. Children are queued at their parent depth plus one. A refused node isn't counted or forced. `single` admits 1 observation node through depth 1, `shallow` admits 8 through depth 4, and `standard` admits 256 through depth 32. Those are the complete public budget names. Plan validation receives a private 256-node, depth-64 specification through an internal path. `plan` isn't publicly selectable and ordinary budget resolution rejects it.

Plan validation threads one global node count through the tree, charges field specifications and plan nodes against the same private plan specification, and builds canonical output during that bounded pass. A keyed seen-set detects duplicate fields, canonical fields are prepended, and lexicographic sorting is the single final ordering pass. Selected-field validation uses a keyed seen-set and prepends canonical selections. Observations are also prepended; each list is reversed once to restore declaration order. Both validators stop before inspecting the first refused control node.

After list length or attr-name enumeration returns, spine metering advances one position at a time with `genericClosure`. It allocates only the current machine state and the first refused path, not a path list for the unvisited remainder. The host length and attr-name primitives remain whole-container operations that can diverge or fail before per-entry metering starts.

Typed-deep uses a first-order `genericClosure` machine. State carries pending node and cursor jobs, consumed count, path, depth, deterministic list or field position, root category, and the first failure. Cursor steps enqueue one child and one continuation. The first refused node stops the machine before its value is inspected.

`tryEval` surrounds named catchable operations only. It can't contain divergence, stack overflow, process abort, interrupts, out-of-memory failure, derivation realization, or a deliberately invoked callback that never returns. Ordinary observation never calls a function. The explicit callback boundary can classify a terminating return or report a catchable throw.

Failures are `boundary-mismatch`, `host-failure`, `resource-exhaustion`, and `internal-bug`. Plan-validation exhaustion and observation exhaustion share the resource class but retain their operation, budget, dimension, limit, consumed count, and refused path. No rendered diagnostic sentence belongs here.

Permanent gates, run from the repository root:

- `nix build --no-link -L .#checks.x86_64-linux.axiom-language`
- `nix flake check -L`
- `nix develop -c statix check .`
- `nix fmt -- --fail-on-change`