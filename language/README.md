# Language foundation

This directory is the source of truth for the isolated language generation. The public surface exposes generation identity, guarded host observation, and scope-valid syntax only. Private evaluation covers the complete admitted structural core; no trusted checking, conversion, quotation, readback, or public typed-language API exists.

The language generation is `axiom-language-1`. Core syntax is `axiom-core-syntax-2`. Private semantics is `axiom-evaluation-2`.

The admitted syntax contains variables, lambdas, applications, annotations, explicit levels, universes, dependent functions and pairs, binary sums, unit, empty, and intensional identity with general J. Rule-family manifests describe the laws and record which operations belong to syntax, scope, levels, and evaluation, but don't drive structural traversal or evaluation.

Dependencies point from flake packaging and `language-tests/` into this directory. Files here don't import `../src`, and the legacy line doesn't import this directory. Evaluation remains private and is gated by direct-oracle and first-order-machine agreement.

Permanent gates from the repository root:

- `nix build --no-link -L .#checks.x86_64-linux.axiom-language`
- `nix flake check -L`
- `nix develop -c statix check .`
- `nix fmt -- --fail-on-change`
