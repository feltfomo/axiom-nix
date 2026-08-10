# Core syntax

This subsystem admits scope-valid untyped syntax. It doesn’t assign types, evaluate terms, compare by definitional equality, or carry proofs. Accurate wording is “admitted scope-valid syntax.”

The structural inventory is variable, lambda, application, and annotation. Variables use absolute De Bruijn levels. A lambda introduces the current scope size, and its body runs at scope plus one. Annotation contains two syntax children and has no typing meaning.

Public input is a forgeable generation-bearing envelope. The syntax decoder checks the envelope, traverses the term, and rebuilds canonical nodes. Core constructors and admitted nodes aren’t exported from `language/default.nix`. The frozen syntax generation is `axiom-core-syntax-1`; missing, unknown, and stale generations fail before node traversal.

Names and locations live in one sparse parallel metadata list keyed by structural paths. The decoder derives valid paths from the canonical tree, rejects duplicate or nonexistent paths, and orders accepted entries by structural traversal. Metadata, path, and location spines are charged before component inspection. Validation observes at most 257 metadata cells, 65 path cells, and 17 location cells; the refused component remains untouched. Paths stop at depth 64. Locations contain at most 16 string or integer components. Metadata doesn’t participate in structural identity.

Weakening and renaming preserve metadata because they preserve shape. Substitution and opening remove metadata at replaced variables, then prefix replacement metadata at every insertion site. Closing adds one binder entry and prefixes body metadata. Final admission validates and orders the resulting channel again.

The root is depth 0. A traversal admits 256 demanded nodes through depth 64. It charges before outer classification, so the first refused node isn’t inspected. Traversal uses a first-order `genericClosure` worklist. Children are prepended in bounded groups, results are prepended, and the final value is selected once. There’s no growing-list append, repeated name scan, or per-node scope-map indexing.

Failures are boundary mismatch, host failure, resource exhaustion, and internal bug. A successfully classified non-attr node is a mismatch. A catchable failure during outer classification is a host failure. Core operations return internal structured data; the public decoder projects those classes through the Stage 1 result vocabulary.

Dependencies point from syntax decoding into the private core assembly. Core files import no boundary module, legacy `src/`, evaluator, checker, or semantic layer. Tests may assemble core and decoder directly.

Change impact:

- a constructor change touches representation, machine dispatch, operations, generated laws, decoder shape rejection, and this inventory;
- a scope rule change touches machine admission, scope transformations, substitution laws, and malformed-reference gates;
- a limit change touches representation, exact-limit tests, poison tests, metadata validation, and this contract;
- a metadata path change touches decoder canonicalization, replacement splicing, opening/closing remapping, and metadata gates;
- a generation change touches representation, stale-generation tests, and public export fixtures.

Permanent gates from the repository root:

- `nix build --no-link -L .#checks.x86_64-linux.axiom-language`
- `nix flake check -L`
- `nix develop -c statix check .`
- `nix fmt -- --fail-on-change`
