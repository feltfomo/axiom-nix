{ lib }:
let
  axiom = import ../src { inherit lib; };
  v = axiom.validation;
  s = axiom.sets;
  poison = throw "unreachable algebra payload";
  bad = expression: !(builtins.tryEval (builtins.deepSeq expression true)).success;
  samples = [
    [ ]
    [ "" ]
    [
      "b"
      "a"
      "b"
      ""
      "a"
    ]
    [
      "a"
      "A"
      "a.b"
      "a/b"
    ]
  ];
  parse = axiom.schema.compile {
    order = [
      "b"
      "a"
      "payload"
    ];
    fields = {
      a = {
        default = 1;
        parse = x: v.success (x + 1);
      };
      b = {
        default = 0;
        parse =
          _:
          v.failure [
            "first"
            "second"
          ];
      };
      payload = {
        parse = v.success;
      };
    };
    onRecord = _: "record";
    onUnknown = name: _: "unknown-${name}";
  };
  phases =
    registrations:
    axiom.phases.compile {
      names = [
        "z"
        "a"
        "empty"
      ];
      inherit registrations;
      phaseOf = r: r.phase;
      runnable = r: r.valid;
      onUnknown = r: _: "unknown-${r.id}";
      onInvalid = r: _: "invalid-${r.id}";
    };
  phasePlan = phases [
    {
      phase = "a";
      valid = true;
      id = "first";
      payload = poison;
    }
    {
      phase = "z";
      valid = true;
      id = "middle";
      payload = poison;
    }
    {
      phase = "a";
      valid = true;
      id = "last";
      payload = poison;
    }
  ];
  f = x: v.success (x + 1);
  g = x: if x > 0 then v.success (x * 2) else v.failure [ "nonpositive" ];
  results = [
    (v.success 2)
    (v.failure [ "a" ])
    (v.failure [
      "b"
      "c"
    ])
  ];
in
{
  andThen-left-identity = v.andThen f (v.success 1) == f 1;
  andThen-right-identity = lib.all (r: v.andThen v.success r == r) results;
  andThen-associativity = lib.all (
    r: v.andThen g (v.andThen f r) == v.andThen (x: v.andThen g (f x)) r
  ) results;
  andThen-failure-skips-value =
    (v.andThen (_: poison) {
      diagnostics = [ "bad" ];
      value = poison;
    }).diagnostics == [ "bad" ];
  andThen-checks-result = bad (v.andThen (_: { diagnostics = [ ]; }) (v.success 1));
  diagnostic-map-identity = lib.all (r: v.mapDiagnostics (x: x) r == r) results;
  diagnostic-map-composition =
    v.mapDiagnostics (x: "[${x}]") (v.mapDiagnostics lib.toUpper (v.failure [ "a" ]))
    == v.mapDiagnostics (x: "[${lib.toUpper x}]") (v.failure [ "a" ]);
  diagnostic-map-success-lazy = v.isSuccess (v.mapDiagnostics (_: poison) (v.success poison));
  diagnostic-map-items-lazy =
    builtins.length (v.mapDiagnostics (_: poison) (v.failure [ poison ])).diagnostics == 1;
  traverse-attrs-order =
    (v.traverseAttrs (name: _: v.failure [ name ]) {
      z = poison;
      a = poison;
    }).diagnostics == [
      "a"
      "z"
    ];
  traverse-attrs-value =
    v.traverseAttrs (_: x: v.success (x + 1)) {
      a = 1;
      b = 2;
    } == v.success {
      a = 2;
      b = 3;
    };
  traverse-attrs-lazy =
    builtins.attrNames (v.traverseAttrs (_: v.success) { a = poison; }).value == [ "a" ];
  traverse-attrs-empty = v.traverseAttrs (_: _: poison) { } == v.success { };
  independent-versus-dependent =
    (v.map2 (_: _: poison) (v.failure [ "a" ]) (v.failure [ "b" ])).diagnostics == [
      "a"
      "b"
    ]
    && (v.andThen (_: v.failure [ "b" ]) (v.failure [ "a" ])).diagnostics == [ "a" ];
  parser-order-and-default-errors =
    (parse {
      extra = poison;
      payload = poison;
    }).diagnostics == [
      "unknown-extra"
      "first"
      "second"
    ];
  parser-default-normalization =
    (axiom.schema.compile {
      fields = {
        a = {
          default = 1;
          parse = x: v.success (x + 1);
        };
      };
      onRecord = _: "record";
      onUnknown = _: _: "unknown";
    } { }).value.a == 2;
  parser-payload-lazy = v.isSuccess (
    axiom.schema.compile {
      fields = {
        a.parse = v.success;
      };
      onRecord = _: "record";
      onUnknown = _: _: "unknown";
    } { a = poison; }
  );
  parser-conflict-rejected = bad (
    axiom.schema.compile {
      fields = {
        a = {
          parse = v.success;
          normalize = x: x;
        };
      };
      onRecord = _: "record";
      onUnknown = _: _: "unknown";
    } { }
  );
  parser-malformed-result = bad (
    axiom.schema.compile {
      fields = {
        a.parse = _: { diagnostics = [ ]; };
      };
      onRecord = _: "record";
      onUnknown = _: _: "unknown";
    } { a = poison; }
  );
  unique-equivalence = lib.all (xs: s.unique xs == lib.unique xs) samples;
  unique-idempotence = lib.all (xs: s.unique (s.unique xs) == s.unique xs) samples;
  union-idempotence = lib.all (xs: s.union xs xs == s.unique xs) samples;
  intersection-idempotence = lib.all (xs: s.intersection xs xs == s.unique xs) samples;
  difference-self-empty = lib.all (xs: s.difference xs xs == [ ]) samples;
  set-order =
    s.union [ "b" "a" ] [ "c" "a" ] == [
      "b"
      "a"
      "c"
    ]
    &&
      s.intersection [ "c" "b" "a" "b" ] [ "a" "b" ] == [
        "b"
        "a"
      ]
    &&
      s.difference [ "c" "b" "c" "a" ] [ "b" ] == [
        "c"
        "a"
      ];
  set-shape-checked = bad (s.unique [ 1 ]) && bad (s.index "x");
  requirement-equivalence = lib.all (
    required:
    lib.all (
      provided:
      let
        result = axiom.requirements.evaluate required provided;
      in
      result.required == lib.unique required
      && result.provided == lib.unique provided
      && result.missing == builtins.filter (x: !(builtins.elem x provided)) (lib.unique required)
    ) samples
  ) samples;
  disabled-provides-stays-lazy =
    (builtins.head
      (axiom.requirements.observe {
        required = [
          "x"
          "x"
        ];
        candidates = [ poison ];
        enabled = _: false;
        providedBy = _: poison;
      }).rejected
    ).missing == [ "x" ];
  phase-declaration-order =
    phasePlan.value.order == [
      "z"
      "a"
      "empty"
    ];
  phase-registration-order =
    map (r: r.id) (phasePlan.value.for "a") == [
      "first"
      "last"
    ];
  phase-empty-group = phasePlan.value.for "empty" == [ ];
  phase-diagnostic-precedence =
    (phases [
      {
        phase = "a";
        valid = false;
        id = "first";
      }
      {
        phase = "missing";
        valid = poison;
        id = "second";
      }
      {
        phase = 1;
        valid = poison;
        id = "third";
      }
    ]).diagnostics == [
      "unknown-second"
      "unknown-third"
      "invalid-first"
    ];
}
