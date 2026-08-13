# Host boundary

The host boundary is the only public forcing boundary for Axiom values. It turns bounded host observations into ordinary result values without exporting semantic authority.

## Public surface

`language/boundary/default.nix` exports:

- `budgets`
- `categories`
- `policies`
- `validatePolicy`
- `validatePlan`
- `result`
- `observeOpaque`
- `observeOuter`
- `observeSpine`
- `observeFields`
- `observeDeep`
- `invoke`

The language root continues to export exactly `boundary`, `generation`, and `syntax`.

## Budgets

Public traversal budgets are fixed:

| Name | Nodes | Depth |
| --- | ---: | ---: |
| `single` | 1 | 1 |
| `shallow` | 8 | 4 |
| `standard` | 256 | 32 |

Plan validation uses the private `plan` budget with 256 nodes and depth 64.

The boundary owns a Logismos `{ depth, nodes }` budget instance. Every attempted observation compares depth first. A depth refusal preserves pre-operation usage and reports the attempted path. Node capacity is tested only after depth succeeds, and nodes increase only after a successful charge. Protected inspection begins after both checks.

## Operational decomposition

Canonical plan structure is validated by `logismos.traversal.fold`. Selected-field validation, selected-field observation, spine metering, and typed-deep observation are closed `logismos.transition.run` machines.

Typed-deep list observation performs one guarded whole-container length operation to establish the spine bound. That operation measures the list spine but does not force list elements. Iteration then retains the unvisited remainder and a logical index. Each child path is charged before the guarded cursor step takes the next item, and refusal leaves the refused element and later elements untouched. The cursor does not repeatedly select from the original list by numeric index.

Typed-deep pending jobs use the private persistent owner in `language/logismos/stack.nix`. Boundary code does not copy its value/rest representation.

## Forcing contract

`observeOpaque` returns its payload without classification.

All other host observations keep guarded `tryEval` operations in boundary code. The guarded operations include:

- budget-name validation
- policy and category validation
- plan-node and plan-field validation
- selected-field specification validation
- host `typeOf`
- list length
- attribute names
- callback application

Charging precedes protected node inspection. Unselected fields and inactive descendants are never placed in the internal pending stack. Paths may be held newest-first internally, but public paths retain their established root-to-leaf bytes.

## Result taxonomy

Boundary results remain ordinary data with stable codes `AXIOM-HOST-001` through `AXIOM-HOST-005`. Success, mismatch, host failure, resource exhaustion, and internal bug remain distinct. Resource failures retain `operation`, `path`, `budget`, `dimension`, `limit`, and pre-refusal node `consumed`.

## Ownership

Boundary modules do not import `language/internal/worklist.nix` or `language/internal/spine.nix`. Those internal modules may remain for unrelated live consumers.

## Permanent checks

The host-boundary suite covers forcing isolation, hostile control inputs, exact and one-over resource boundaries, path and ordering stability, private plan limits, public result shapes, persistent-stack ownership, and zero obsolete boundary imports.
