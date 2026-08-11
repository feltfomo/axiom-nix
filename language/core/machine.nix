{ representation, levels }:
let
  inherit (representation) limits;
  exact = names: value: builtins.isAttrs value && builtins.attrNames value == names;
  reverse = builtins.foldl' (xs: x: [ x ] ++ xs) [ ];
  failure = kind: path: detail: {
    ok = false;
    inherit kind path detail;
  };
  child = job: field: scope: {
    action = "visit";
    node = job.node.${field};
    inherit scope;
    depth = job.depth + 1;
    path = job.path ++ [ field ];
  };
  # child scopes carry absolute binder starts rather than an index-relative depth
  spec =
    job:
    let
      n = job.node;
      s = job.scope;
      plain = field: child job field s;
      bound = field: count: child job field (s + count);
      shape = names: children: {
        ok = exact names n;
        inherit children;
      };
    in
    if n.kind == "lambda" then
      shape [ "body" "kind" ] [ (bound "body" 1) ]
    else if n.kind == "application" then
      shape [ "argument" "function" "kind" ] [ (plain "function") (plain "argument") ]
    else if n.kind == "annotation" then
      shape [ "annotation" "kind" "subject" ] [ (plain "subject") (plain "annotation") ]
    else if n.kind == "pi" then
      shape [ "codomain" "domain" "kind" ] [ (plain "domain") (bound "codomain" 1) ]
    else if n.kind == "sigma" then
      shape [ "codomain" "domain" "kind" ] [ (plain "domain") (bound "codomain" 1) ]
    else if n.kind == "sum-type" then
      shape [ "kind" "left" "right" ] [ (plain "left") (plain "right") ]
    else if n.kind == "pair" then
      shape [ "first" "kind" "second" ] [ (plain "first") (plain "second") ]
    else if n.kind == "first-projection" then
      shape [ "kind" "pair" ] [ (plain "pair") ]
    else if n.kind == "second-projection" then
      shape [ "kind" "pair" ] [ (plain "pair") ]
    else if n.kind == "left-injection" then
      shape [ "kind" "value" ] [ (plain "value") ]
    else if n.kind == "right-injection" then
      shape [ "kind" "value" ] [ (plain "value") ]
    # sum motive and branches bind separate witnesses at the same absolute level
    else if n.kind == "sum-elimination" then
      shape
        [ "kind" "leftBranch" "motive" "rightBranch" "scrutinee" ]
        [ (plain "scrutinee") (bound "motive" 1) (bound "leftBranch" 1) (bound "rightBranch" 1) ]
    else if n.kind == "unit-elimination" then
      shape
        [ "case" "kind" "motive" "scrutinee" ]
        [ (plain "scrutinee") (bound "motive" 1) (plain "case") ]
    else if n.kind == "empty-elimination" then
      shape [ "kind" "motive" "scrutinee" ] [ (plain "scrutinee") (bound "motive" 1) ]
    else if n.kind == "identity-type" then
      shape [ "carrier" "kind" "left" "right" ] [ (plain "carrier") (plain "left") (plain "right") ]
    else if n.kind == "refl" then
      shape [ "kind" "value" ] [ (plain "value") ]
    # source target and evidence occupy consecutive levels while the refl branch binds only source
    else if n.kind == "identity-elimination" then
      shape
        [ "kind" "motive" "reflBranch" "scrutinee" ]
        [ (plain "scrutinee") (bound "motive" 3) (bound "reflBranch" 1) ]
    else
      {
        ok = false;
        children = [ ];
      };
  build =
    kind: values:
    let
      ordered = reverse values;
      at = i: builtins.elemAt ordered i;
    in
    if kind == "lambda" then
      representation.lambda (at 0)
    else if kind == "application" then
      representation.application (at 0) (at 1)
    else if kind == "annotation" then
      representation.annotation (at 0) (at 1)
    else if kind == "pi" then
      representation.pi (at 0) (at 1)
    else if kind == "sigma" then
      representation.sigma (at 0) (at 1)
    else if kind == "sum-type" then
      representation.sumType (at 0) (at 1)
    else if kind == "pair" then
      representation.pair (at 0) (at 1)
    else if kind == "first-projection" then
      representation.firstProjection (at 0)
    else if kind == "second-projection" then
      representation.secondProjection (at 0)
    else if kind == "left-injection" then
      representation.leftInjection (at 0)
    else if kind == "right-injection" then
      representation.rightInjection (at 0)
    else if kind == "sum-elimination" then
      representation.sumElimination (at 0) (at 1) (at 2) (at 3)
    else if kind == "unit-elimination" then
      representation.unitElimination (at 0) (at 1) (at 2)
    else if kind == "empty-elimination" then
      representation.emptyElimination (at 0) (at 1)
    else if kind == "identity-type" then
      representation.identityType (at 0) (at 1) (at 2)
    else if kind == "refl" then
      representation.refl (at 0)
    else if kind == "identity-elimination" then
      representation.identityElimination (at 0) (at 1) (at 2)
    else
      null;
  advance =
    onVariable: state:
    if state.status != "running" || state.jobs == [ ] then
      [ ]
    else
      let
        job = builtins.head state.jobs;
        rest = builtins.tail state.jobs;
        next = update: [ (state // update // { key = state.key + 1; }) ];
        stop =
          result:
          next {
            status = "done";
            jobs = [ ];
            inherit result;
          };
      in
      if job.action == "build" then
        let
          selected = builtins.genList (i: builtins.elemAt state.values i) job.count;
          remaining = builtins.genList (i: builtins.elemAt state.values (i + job.count)) (
            builtins.length state.values - job.count
          );
          value = build job.kind selected;
        in
        if value == null then
          stop (failure "internal-bug" job.path "build")
        else
          next {
            jobs = rest;
            values = [ value ] ++ remaining;
            status = if rest == [ ] then "done" else "running";
          }
      else if job.depth > limits.depth then
        stop (failure "resource-exhaustion" job.path "depth")
      else if state.consumed >= limits.nodes then
        stop (failure "resource-exhaustion" job.path "nodes")
      else
        let
          consumed = state.consumed + 1;
          outer = builtins.tryEval (builtins.typeOf job.node);
        in
        if !outer.success then
          stop (failure "host-failure" job.path "node-outer")
        else if outer.value != "set" then
          stop (failure "boundary-mismatch" job.path "node")
        else
          let
            inspected = builtins.tryEval {
              names = builtins.attrNames job.node;
              kind = job.node.kind;
            };
          in
          if !inspected.success then
            stop (failure "host-failure" job.path "node-control")
          else if inspected.value.kind == "variable" then
            let
              valid =
                exact [ "kind" "level" ] job.node
                && builtins.isInt job.node.level
                && job.node.level >= 0
                && job.node.level < job.scope;
              mapped =
                if valid then
                  builtins.tryEval (onVariable {
                    inherit (job)
                      node
                      scope
                      depth
                      path
                      ;
                  })
                else
                  {
                    success = true;
                    value = null;
                  };
            in
            if !valid then
              stop (failure "boundary-mismatch" job.path "variable")
            else if !mapped.success then
              stop (failure "internal-bug" job.path "variable-map")
            else
              next {
                inherit consumed;
                jobs = rest;
                values = [ mapped.value ] ++ state.values;
                paths = [ job.path ] ++ state.paths;
                variables = [
                  {
                    inherit (job) path;
                    inherit (job.node) level;
                  }
                ]
                ++ state.variables;
                status = if rest == [ ] then "done" else "running";
              }
          else if inspected.value.kind == "universe" then
            if !exact [ "kind" "level" ] job.node then
              stop (failure "boundary-mismatch" job.path "universe")
            else
              let
                # level children share the enclosing term's node and depth account
                normalized = levels.normalizeInput {
                  value = job.node.level;
                  inherit consumed;
                  depth = job.depth + 1;
                };
              in
              if !normalized.ok then
                next {
                  status = "done";
                  jobs = [ ];
                  consumed = normalized.inputConsumed or normalized.consumed;
                  result = failure normalized.kind (job.path ++ [ "level" ]) normalized.detail;
                }
              else
                next {
                  inherit (normalized) consumed;
                  jobs = rest;
                  values = [ (representation.universe normalized.value) ] ++ state.values;
                  paths = [ job.path ] ++ state.paths;
                  status = if rest == [ ] then "done" else "running";
                }
          else if
            builtins.elem inspected.value.kind [
              "unit-type"
              "unit"
              "empty-type"
            ]
          then
            if !exact [ "kind" ] job.node then
              stop (failure "boundary-mismatch" job.path inspected.value.kind)
            else
              let
                value =
                  if inspected.value.kind == "unit-type" then
                    representation.unitType
                  else if inspected.value.kind == "unit" then
                    representation.unit
                  else
                    representation.emptyType;
              in
              next {
                inherit consumed;
                jobs = rest;
                values = [ value ] ++ state.values;
                paths = [ job.path ] ++ state.paths;
                status = if rest == [ ] then "done" else "running";
              }
          else
            let
              described = spec job;
            in
            if !described.ok then
              stop (failure "boundary-mismatch" job.path "constructor")
            else
              next {
                inherit consumed;
                paths = [ job.path ] ++ state.paths;
                jobs =
                  described.children
                  ++ [
                    {
                      action = "build";
                      kind = inspected.value.kind;
                      count = builtins.length described.children;
                      inherit (job) path;
                    }
                  ]
                  ++ rest;
              };
  rewrite =
    {
      root,
      scope,
      onVariable ? ({ node, ... }: representation.variable node.level),
    }:
    let
      states = builtins.genericClosure {
        startSet = [
          {
            key = 0;
            status = "running";
            consumed = 0;
            values = [ ];
            paths = [ ];
            variables = [ ];
            result = null;
            jobs = [
              {
                action = "visit";
                inherit root scope;
                depth = 0;
                path = [ ];
                node = root;
              }
            ];
          }
        ];
        operator = advance onVariable;
      };
      final = builtins.elemAt states (builtins.length states - 1);
    in
    if final.result != null then
      final.result // { inherit (final) consumed; }
    else if final.status == "done" && builtins.length final.values == 1 then
      {
        ok = true;
        value = builtins.head final.values;
        inherit (final) consumed;
        paths = reverse final.paths;
        variables = reverse final.variables;
      }
    else
      failure "internal-bug" [ ] "machine-final-state";
  equal =
    {
      left,
      right,
      scope,
    }:
    let
      a = rewrite {
        root = left;
        inherit scope;
      };
      b = rewrite {
        root = right;
        inherit scope;
      };
    in
    a.ok && b.ok && a.value == b.value;
in
{
  inherit rewrite equal;
  validate = rewrite;
}
