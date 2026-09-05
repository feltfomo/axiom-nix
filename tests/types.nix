{ lib }:
let
  axiom = import ../src { inherit lib; };
  t = axiom.types;
  v = axiom.validation;
  poison = throw "unreachable type payload";
  paths = result: map (problem: problem.path) result.diagnostics;
  bad = expression: !(builtins.tryEval (builtins.deepSeq expression true)).success;
  positive = t.refine "positive integer" t.int (n: n > 0);
  item = t.record {
    name = t.string;
    ports = t.listOf positive;
    payload = t.opaque;
  };
  broken = item.validate {
    name = false;
    ports = [
      0
      "bad"
      1
    ];
    payload = poison;
    unexpected = poison;
  };
in
{
  primitives = lib.all (x: x) [
    (t.string.check "x")
    (t.int.check 1)
    (t.float.check 1.5)
    (t.bool.check false)
    (t.path.check ./types.nix)
    (t.function.check (_: poison))
    (t.attrs.check { x = poison; })
    (t.list.check [ poison ])
    (!(t.int.check 1.5))
    (!(t.string.check null))
  ];
  opaque-does-not-force = v.isSuccess (t.opaque.validate poison);
  opaque-record-value = v.isSuccess (
    item.validate {
      name = "service";
      ports = [
        1
        2
      ];
      payload = poison;
    }
  );
  reachable-errors =
    paths broken == [
      [ "unexpected" ]
      [ "name" ]
      [
        "ports"
        0
      ]
      [
        "ports"
        1
      ]
    ];
  no-failed-value = !(broken ? value);
  issues-do-not-carry-input = lib.all (
    problem:
    builtins.attrNames problem == [
      "actual"
      "expected"
      "path"
      "reason"
    ]
  ) broken.diagnostics;
  safe-issue-metadata = builtins.deepSeq broken.diagnostics true;
  missing-fields =
    paths (item.validate { }) == [
      [ "name" ]
      [ "payload" ]
      [ "ports" ]
    ];
  missing-kind = (builtins.head (item.validate { }).diagnostics).actual == "missing";
  malformed-parent-stops-descent = paths ((t.record { field = poison; }).validate 1) == [ [ ] ];
  list-parent-stops-descent = (t.listOf t.int).check false == false;
  empty-containers =
    (t.listOf t.int).validate [ ] == v.success [ ] && (t.attrsOf t.int).validate { } == v.success { };
  sorted-attribute-paths =
    paths (
      (t.attrsOf (t.listOf t.bool)).validate {
        z = [ 0 ];
        a = [
          1
          2
        ];
      }
    ) == [
      [
        "a"
        0
      ]
      [
        "a"
        1
      ]
      [
        "z"
        0
      ]
    ];
  normalized-record =
    (t.record {
      b = t.int;
      a = t.string;
    }).validate
      {
        a = "x";
        b = 2;
      } == v.success {
      a = "x";
      b = 2;
    };
  refinement-after-base = !(t.refine "never reached" t.int (_: poison)).check "x";
  refinement-failure = (builtins.head (positive.validate 0).diagnostics).reason == "refinement";
  callback-errors-propagate = bad ((t.refine "callback" t.int (_: poison)).validate 1);
  nullable = (t.nullOr t.int).check null && (t.nullOr t.int).check 1 && !(t.nullOr t.int).check false;
  enums =
    (t.enum [
      "a"
      "b"
      "a"
    ]).check
      "b"
    && !(t.enum [ "a" ]).check "c";
  invalid-enums = bad (t.enum [ ]) && bad (t.enum [ 1 ]);
  first-alternative-wins =
    (t.oneOf "text" [
      t.string
      poison
    ]).validate
      "x" == v.success "x";
  later-alternative =
    (t.oneOf "text or integer" [
      t.string
      t.int
    ]).validate
      1 == v.success 1;
  alternatives-accumulate-only-on-failure =
    builtins.length
      (
        (t.oneOf "text or integer" [
          t.string
          t.int
        ]).validate
        false
      ).diagnostics == 2;
  alternative-nested-path =
    paths (
      (t.oneOf "argument" [
        t.string
        (t.record { param = t.string; })
      ]).validate
        { param = 1; }
    ) == [
      [ ]
      [ "param" ]
    ];
  empty-alternatives-rejected = bad (t.oneOf "empty" [ ]);
  selected-variant-only = v.isSuccess (
    (t.variant {
      yes = t.opaque;
      no = poison;
    }).validate
      (axiom.tagged.mk "yes" poison)
  );
  unknown-variant-skips-payload =
    paths ((t.variant { yes = t.int; }).validate (axiom.tagged.mk "no" poison)) == [ [ "tag" ] ];
  variant-path =
    paths ((t.variant { yes = t.listOf t.int; }).validate (axiom.tagged.mk "yes" [ false ])) == [
      [
        "value"
        0
      ]
    ];
  variant-result =
    (t.variant { yes = t.int; }).validate (axiom.tagged.mk "yes" 1)
    == v.success (axiom.tagged.mk "yes" 1);
  non-string-tag =
    paths (
      (t.variant { yes = t.int; }).validate {
        __axiom = "axiom/tagged";
        tag = 1;
        value = poison;
      }
    ) == [ [ "tag" ] ];
  description-without-input =
    (t.record { ports = t.listOf positive; }).description.fields.ports.element.kind == "refinement";
}
