{ representation }:
let
  inherit (representation) limits;
  lists = import ../internal/lists.nix;
  worklist = import ../internal/worklist.nix { inherit lists; };
  attrs = import ../internal/attrs.nix;
  inherit (attrs) exact;
  failure = kind: detail: consumed: {
    ok = false;
    inherit kind detail consumed;
  };
  zero = representation.levelZero;
  suc = representation.levelSuc;
  max = representation.levelMax;
  normalizeInput =
    {
      value,
      consumed ? 0,
      depth ? 0,
    }:
    let
      final = worklist.runLinear {
        startSet = [
          {
            key = 0;
            status = "running";
            jobs = [
              {
                action = "visit";
                node = value;
                inherit depth;
              }
            ];
            values = [ ];
            inherit consumed;
            result = null;
          }
        ];
        operator =
          state:
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
            if job.action == "build-suc" then
              next {
                jobs = rest;
                values = [ (builtins.head state.values + 1) ] ++ builtins.tail state.values;
              }
            else if job.action == "build-max" then
              let
                right = builtins.head state.values;
                left = builtins.head (builtins.tail state.values);
              in
              next {
                jobs = rest;
                values = [ (if left > right then left else right) ] ++ builtins.tail (builtins.tail state.values);
              }
            else if job.depth > limits.depth then
              stop (failure "resource-exhaustion" "depth" state.consumed)
            else if state.consumed >= limits.nodes then
              # raw level nodes continue the enclosing term input account
              stop (failure "resource-exhaustion" "nodes" state.consumed)
            else
              let
                charged = state.consumed + 1;
                outer = builtins.tryEval (builtins.typeOf job.node);
              in
              if !outer.success then
                stop (failure "host-failure" "level-outer" charged)
              else if outer.value != "set" then
                stop (failure "boundary-mismatch" "level" charged)
              else
                let
                  names = builtins.attrNames job.node;
                  hasKind = builtins.elem "kind" names && job.node ? kind;
                  observedKind =
                    if hasKind then
                      builtins.tryEval (builtins.seq job.node.kind job.node.kind)
                    else
                      {
                        success = true;
                        value = null;
                      };
                in
                if !hasKind then
                  stop (failure "boundary-mismatch" "level-kind" charged)
                else if !observedKind.success then
                  stop (failure "host-failure" "level-control" charged)
                else if !builtins.isString observedKind.value then
                  stop (failure "boundary-mismatch" "level-kind" charged)
                else if observedKind.value == "zero" then
                  if exact [ "kind" ] job.node then
                    next {
                      consumed = charged;
                      jobs = rest;
                      values = [ 0 ] ++ state.values;
                    }
                  else
                    stop (failure "boundary-mismatch" "level-zero" charged)
                else if observedKind.value == "suc" then
                  if exact [ "kind" "level" ] job.node then
                    next {
                      consumed = charged;
                      jobs = [
                        {
                          action = "visit";
                          node = job.node.level;
                          depth = job.depth + 1;
                        }
                        { action = "build-suc"; }
                      ]
                      ++ rest;
                    }
                  else
                    stop (failure "boundary-mismatch" "level-suc" charged)
                else if observedKind.value == "max" then
                  if exact [ "kind" "left" "right" ] job.node then
                    next {
                      consumed = charged;
                      jobs = [
                        {
                          action = "visit";
                          node = job.node.left;
                          depth = job.depth + 1;
                        }
                        {
                          action = "visit";
                          node = job.node.right;
                          depth = job.depth + 1;
                        }
                        { action = "build-max"; }
                      ]
                      ++ rest;
                    }
                  else
                    stop (failure "boundary-mismatch" "level-max" charged)
                else
                  stop (failure "boundary-mismatch" "level-constructor" charged);
      };
      heightValue =
        if final.result == null && final.values != [ ] then builtins.head final.values else null;
      rebuilt = if heightValue == null then null else rebuildCanonical heightValue;
    in
    if final.result != null then
      final.result
    else if !rebuilt.ok then
      rebuilt // { inputConsumed = final.consumed; }
    else
      rebuilt
      // {
        height = heightValue;
        inherit (final) consumed;
      };
  normalize = value: normalizeInput { inherit value; };
  # canonical output has an account independent from input observation
  rebuildCanonical =
    heightValue:
    let
      outputNodes =
        if builtins.isInt heightValue && heightValue >= 0 then heightValue + 1 else limits.nodes + 1;
      build = count: if count == 0 then zero else suc (build (count - 1));
    in
    if !builtins.isInt heightValue || heightValue < 0 then
      failure "boundary-mismatch" "level-output-height" 0
    else if outputNodes > limits.nodes then
      failure "resource-exhaustion" "level-output-nodes" limits.nodes
    else if heightValue > limits.depth then
      failure "resource-exhaustion" "level-output-depth" limits.depth
    else
      {
        ok = true;
        value = build heightValue;
        outputConsumed = outputNodes;
      };
  height =
    level:
    let
      normalized = normalize level;
    in
    if !normalized.ok then normalized else normalized // { value = normalized.height; };
  equal =
    left: right:
    let
      a = normalize left;
      b = normalize right;
    in
    a.ok && b.ok && a.height == b.height;
  successor =
    level:
    let
      normalized = normalize level;
    in
    if !normalized.ok then normalized else normalize (suc normalized.value);
  maximum =
    left: right:
    let
      a = normalize left;
      b = normalize right;
    in
    if !a.ok then
      a
    else if !b.ok then
      b
    else
      normalize (max a.value b.value);
  requireExact = expected: actual: equal expected actual;
  joinSemilattice = {
    inherit
      zero
      successor
      height
      equal
      requireExact
      ;
    join = maximum;
    canonicalize = normalize;
  };
  formation = {
    universe = successor;
    pi = maximum;
    sigma = maximum;
    sum = maximum;
    unit = zero;
    empty = zero;
    identity = normalize;
  };
in
{
  inherit
    zero
    suc
    max
    normalizeInput
    normalize
    rebuildCanonical
    equal
    successor
    maximum
    requireExact
    joinSemilattice
    formation
    ;
}
