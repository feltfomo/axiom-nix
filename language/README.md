# Language foundation

This directory is the source of truth for the isolated language generation. It exposes generation identities, guarded host observation, and scope-valid core syntax. No typed semantics exist yet.

The language generation identity is `axiom-language-1`. The syntax generation identity is `axiom-core-syntax-1`.

Dependencies point from flake packaging and `language-tests/` into this directory. Files here must not import `../src`, and the legacy `src/` line must not import this directory. The isolation gate evaluates each production root from a store closure containing only that root.

Permanent gates, run from the repository root:

- `nix eval --raw .#lib.axiomLanguage.generation`
- `nix build -L .#checks.x86_64-linux.axiom-language`
- `nix flake check -L`
- `nix fmt -- --fail-on-change`
