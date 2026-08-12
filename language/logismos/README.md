# Logismos

Logismos is the private composition layer for the Axiom language line. The dependency direction is inward: private semantic subsystems may import Logismos, while Logismos depends only on its own closed machinery and host builtins. `language/default.nix` does not import or export it.

The computation carrier is a closed first-order instruction program. Bind prepends one private continuation instruction, and `builtins.genericClosure` advances an explicit worklist. Runtime-produced instructions run before the older continuation in their own written order. Failure makes the remaining worklist unreachable without forcing it and retains the state at the refusing operation.

The permanent computation laws are left identity, observational right identity, observational associativity, failure as left zero, and map identity and composition. Product and traversal preserve left-to-right premise and charge order. Failed continuations and unselected branches remain unforced. Reader access observes the supplied environment, and dynamic continuations observe the latest state.

Relations, transitions, traversals, and finite budget vectors provide reusable mathematical composition. They do not admit syntax, define semantic truth, manufacture trusted evidence, merge failure taxonomies, or materialize judgment results. Boundary, evaluation, and kernel adapters remain outside the carrier and preserve their own shapes.

The interpreter retains linear `genericClosure` state history to avoid recursive-stack collapse under Nix. States stay compact: no debug trace, copied output history, or semantic evidence belongs in the carrier.

`language-tests/logismos` owns the focused law and adversarial suite. Its permanent gates include poisoned continuations, unselected branches, exact resource bounds, materialization for all three result families, closed export surfaces, oldest-first replay, and computation and transition pipelines at depth 10000.
