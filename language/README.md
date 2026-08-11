# Axiom language

The language line admits bounded core syntax with explicit universes, dependent functions and pairs, binary sums, Unit, Empty, and intensional identity. Absolute De Bruijn levels are shared by syntax, semantic environments, and the private kernel.

The public module remains limited to `boundary`, `generation`, and `syntax`. Core operations, evaluation, and trusted judgments are private repository subsystems.

Weak-head call-by-name evaluation has independent direct and first-order implementations. Semantic values retain explicit closures, lazy cells, and newest-first neutral spines.

The private kernel validates contexts, forms types, infers and checks terms, compares semantic values by type-directed normalization by evaluation, and independently checks conversion through bounded canonical readback.
