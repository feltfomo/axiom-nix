# Runtime types and stable composition

This is the `src/` API, independent of `language/`. It checks ordinary Nix values at subsystem boundaries. Descriptions are ordinary attrsets, not static types, unforgeable certificates, normalization proofs, or permission grants. No kernel calculus or Logismos evaluator is imported.

## A small type algebra

Every description provides `name`, inspectable `description` data, `validate value`, and `check value`. `validate` returns an Axiom validation result. `check` projects success to a boolean and discards error detail.

| Constructor | Boundary |
| --- | --- |
| `opaque` | Accept without forcing even the outer value. |
| `string`, `int`, `float`, `bool`, `path`, `function` | Check the corresponding Nix outer type. Functions are not called. |
| `attrs`, `list` | Check only the container, not its contents. |
| `listOf element` | Check every reachable element, with zero-based index paths. |
| `attrsOf element` | Check every field in sorted name order. |
| `record fields` | Closed product with every declared field required. Uses `schema.compile`. |
| `nullOr element` | Accept null or check the element type. |
| `enum strings` | Non-empty string vocabulary; duplicates do not change membership. |
| `refine name base predicate` | Run the predicate only after base validation succeeds. |
| `oneOf name alternatives` | Try alternatives in order; stop at the first success. If all fail, retain their diagnostics in alternative order. |
| `variant cases` | Validate the selected payload of a `tagged.mk` value. Other cases stay lazy. |

```nix
serviceType = axiom.types.record {
  name = axiom.types.string;
  ports = axiom.types.listOf (
    axiom.types.refine "TCP port" axiom.types.int (n: n > 0 && n < 65536)
  );
  implementation = axiom.types.opaque;
};

result = serviceType.validate {
  name = "api";
  ports = [ 0 "invalid" ];
  implementation = throw "not inspected";
};
```

The two issues have paths `[ "ports" 0 ]` and `[ "ports" 1 ]`. Each issue contains only `path`, `expected`, `actual`, and `reason`. `actual` is an outer Nix type or the sentinel `missing`/`unknown`; the original input is never attached. Reasons are `type`, `refinement`, `missing-field`, `unknown-field`, and `unknown-variant`.

Malformed containers stop descent. Closed records diagnose unknown names first without evaluating their values, then declared fields in sorted order. Independent errors accumulate; they do not authorize inspecting inactive payloads. Use `opaque` for implementations, derivation internals, secrets, and deferred values. Descriptions do not serialize refinement predicates. Infinite structures, arbitrary recursion, and thrown callback errors are not converted into type issues or bounded automatically.

For optional/defaulted fields, retain the existing schema owner and use a parser field:

```nix
parse = axiom.schema.compile {
  fields.ports = {
    default = [ 8080 ];
    parse = (axiom.types.listOf axiom.types.int).validate;
  };
  onRecord = _: "expected a record";
  onUnknown = name: _: "unknown field ${name}";
};
```

A parser owns both validation and normalization and returns one validation result. It cannot be combined with `validate`, `normalize`, or `onInvalid`. Present values and defaults follow exactly the same parser. Missing-field policy remains the schema's responsibility. Map neutral type issues into your own diagnostic representation before mixing them with domain diagnostics; Krisis provides `validateType` for this.

## Independent and dependent composition

- `validation.map2` and `sequence` accumulate independent failures, left to right.
- `validation.andThen f result` runs a dependent stage only after success and returns its result without nesting.
- `validation.traverseAttrs f attrs` accumulates in sorted key order and retains lazy successful values.
- `validation.mapDiagnostics f result` maps individual diagnostics without touching successful payloads.

For canonical results built with `success` or non-empty `failure`, and total callbacks that return such results, `andThen` obeys left identity, right identity, and associativity with `success`. Its fail-fast application is deliberately not interchangeable with accumulating `map2`. There is no claim that both define one coherent monad/applicative instance. Tests live in `tests/algebra.nix` and `tests/types.nix`, in the existing nix-unit tree.

## String sets and indexed algorithms

`sets.index strings` creates a name-membership attrset. `unique`, `union`, `intersection`, and `difference` return lists, preserving first occurrence order from the left operand (`union` then appends unseen right members). These operations accept strings only, not arbitrary Nix values. They do not redefine Ownerships claim intersection or merge semantics.

`unique` records first positions with `listToAttrs` rather than repeatedly scanning an expanding result. Requirements normalize the required list once per observation and test membership through a provided-name index. Phases index the declared vocabulary and group valid registrations once. Schema checks unknown names by attribute membership. Caller ordering and disabled-candidate laziness are unchanged.

## Measurement

Run `python3 tests/benchmark.py` with Python 3 and Nix/Lix on PATH. For upstream Nix, enable the pipe feature in its configuration before running the script, since it imports `src/` directly rather than applying flake settings. The script reads this checkout's nixpkgs pin and `src/`, performs one warm-up and three measured evaluations per workload, checks every output, and prints raw samples. These are wall-clock synthetic evaluations, including evaluator startup, not a full Lexicon build benchmark or timing assertions in the semantic gate.

On the same x86_64 Linux host with Lix `2.96.0-dev-pre20260728-dev_64c99ac`, before and after this change:

| Workload | Before samples, seconds | After samples, seconds | Before median | After median |
| --- | --- | --- | --- | --- |
| 2,048 capabilities across 24 candidates | 1.307866, 1.349978, 1.386540 | 0.120737, 0.118374, 0.116058 | 1.349978 | 0.118374 |
| 8,192 registrations across 256 phases | 0.238238, 0.246016, 0.222438 | 0.077428, 0.077119, 0.080391 | 0.238238 | 0.077428 |
| 2,048 declared schema fields | 0.109914, 0.121273, 0.117400 | 0.086621, 0.087396, 0.079963 | 0.117400 | 0.086621 |

Outputs remained 24 qualified candidates, 8,192 grouped registrations, and 2,048 normalized fields. The workload script was unchanged between those runs. These small sample sets establish a local observation, not a cross-machine speed guarantee. The complete Axiom gate also passes; no test was replaced by a timing check.

## Pipe syntax and compatibility

Shared source uses `|>` for left-to-right composition. Nix 2.25 requires `extra-experimental-features = pipe-operators` (plural); accept the flake's setting or pass the feature explicitly when importing source outside a flake. Axiom's nix-unit runner enables it explicitly. The tested Lix development version parses pipes without a feature flag and warns if given the Nix-only flag. The pinned nixfmt, statix, and deadnix accept this source. Pipes change notation, not evaluation costs or laziness.

## Design influences

[Bend](https://github.com/denful/bend) motivates parsing a boundary once and retaining its result. [nix-effects](https://github.com/kleisli-io/nix-effects) motivates inspectable type descriptions and path-aware errors, without importing its effect runtime or proof claims. [Ned](https://github.com/denful/ned) and [Zen](https://github.com/denful/zen) explore lazy streams and module/actor organization; those mechanisms are not introduced here because current consumers need boundary validation, not another execution engine.

The Nix 2.25 [built-ins](https://nix.dev/manual/nix/2.25/language/builtins), [operators](https://nix.dev/manual/nix/2.25/language/operators), and [syntax](https://nix.dev/manual/nix/2.25/language/syntax) define the underlying evaluation behavior. The foundation isolation tests still verify that `src/` works without `language/`; only their stable-export inventory was extended with `sets` and `types`.
