# Core syntax and rule families

This subsystem admits scope-valid syntax and decides the dedicated level algebra. It doesn't assign types, compare terms by definitional equality, or carry proofs. Formation calculations are executable law evidence, not checker results.

Core syntax generation `axiom-core-syntax-2` admits variable, lambda, application, annotation, universe, pi, sigma, binary sum, unit, empty, pair and projections, injections and dependent case, identity, refl, and general J. Levels are a separate zero, successor, and maximum sort. Closed level expressions normalize to a bounded successor chain; exact canonical equality provides the non-cumulative universe arithmetic.

Variables use absolute De Bruijn levels. Pi and sigma codomains bind one level. Sum motive and branches each bind one level. Unit and empty motives bind one level. General J's motive binds source, target, and evidence in that order; its refl branch binds only the witness. Generic binder-body opening and closing operate on an explicit ordered consecutive top segment and never discover binders from syntax or manifests.

Public envelopes are forgeable. Admission checks `axiom-core-syntax-2`, exact shapes, scope, resources, and metadata before rebuilding private canonical nodes. Missing or stale generations fail before term traversal. Names and locations remain outside structural identity.

`rule-families.nix` records syntax, formation, introduction, elimination, computation, equality, eta status, semantics, diagnostics, laws, and the subsystem responsible for each implemented operation. Checking, conversion, quotation, and readback remain reserved for separate trusted layers and aren't implemented here. Structural and evaluator dispatch don't reference manifest data, which supplies no semantic authority.

A constructor change touches representation, the structural machine, operations, both evaluators, projection, executable completeness fixtures, manifests, and this contract. A binder change also touches the ordered opening/closing gates. A level-law change touches normalization, formation calculators, universe fixtures, and output-accounting limits.

Permanent gates from the repository root:

- `nix build --no-link -L .#checks.x86_64-linux.axiom-language`
- `nix flake check -L`
- `nix develop -c statix check .`
- `nix fmt -- --fail-on-change`
