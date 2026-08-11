# Evaluation engine

This private subsystem gives weak-head call-by-name meaning to the complete admitted core syntax. It doesn't form or check types, define conversion, quote values, execute host callbacks, or expose evaluator authority through `language/default.nix`.

Evaluation generation `axiom-evaluation-2` stamps environments, cells, closures, values, and neutral spine items. A demanded record's stamp is checked before its variant payload. Inactive domains, families, motives, branches, pair components, injection payloads, identity endpoints, and unrelated environment cells aren't recursively validated or forced.

Pi and sigma values carry an inactive domain cell and codomain closure. Sum types carry inactive component cells. Pairs, injections, and refl carry thunks. Identity types carry inactive carrier and endpoint cells. Universes carry normalized dedicated level syntax.

Eliminators evaluate only their scrutinee. Projections demand one selected pair cell. Sum elimination evaluates one selected branch. Unit evaluates its case. Empty has no canonical branch. J on refl applies the one-binder refl branch to the stored witness. Motives stay inactive.

Open eliminations extend a neutral spine. Items are stored newest-first with an explicit checked count, then reversed once by bounded projection support. Spine items cover application, both projections, sum, unit, empty, and identity elimination.

The direct evaluator states the equations recursively. The first-order machine uses eval and return control with apply, projection, sum, unit, empty, and identity frames. Sum and J frames retain raw inactive syntax and its environment until the scrutinee chooses a canonical or neutral path.

Defaults remain 256 semantic nodes, depth 64, and 4096 transitions. Node and depth refusal precedes term inspection. Fuel refusal precedes machine control or frame advancement. Incompatible canonical eliminations are internal semantic-state failures because this subsystem assumes, but doesn't establish, the relevant type invariant.

Permanent gates from the repository root:

- `nix build --no-link -L .#checks.x86_64-linux.axiom-language`
- `nix flake check -L`
- `nix develop -c statix check .`
- `nix fmt -- --fail-on-change`
