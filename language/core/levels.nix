{ limits }:
let
  failure = kind: detail: consumed: {
    ok = false;
    inherit kind detail consumed;
  };
  zero = {
    kind = "zero";
  };
  suc = level: {
    kind = "suc";
    inherit level;
  };
  max = left: right: {
    kind = "max";
    inherit left right;
  };
  exact = names: value: builtins.isAttrs value && builtins.attrNames value == names;

  # concrete levels normalize to one successor chain rather than exposing the counter used to build it
  normalizeInput =
    {
      value,
      consumed ? 0,
      depth ? 0,
    }:
    let
      states = builtins.genericClosure {
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
            # raw level nodes continue the containing term's input account
            else if job.depth > limits.depth then
              stop (failure "resource-exhaustion" "depth" state.consumed)
            else if state.consumed >= limits.nodes then
              stop (failure "resource-exhaustion" "nodes" state.consumed)
            else
              let
                consumed = state.consumed + 1;
                outer = builtins.tryEval (builtins.typeOf job.node);
              in
              if !outer.success then
                stop (failure "host-failure" "level-outer" consumed)
              else if outer.value != "set" then
                stop (failure "boundary-mismatch" "level" consumed)
              else
                let
                  inspected = builtins.tryEval {
                    names = builtins.attrNames job.node;
                    kind = job.node.kind;
                  };
                in
                if !inspected.success then
                  stop (failure "host-failure" "level-control" consumed)
                else if inspected.value.kind == "zero" then
                  if exact [ "kind" ] job.node then
                    next {
                      inherit consumed;
                      jobs = rest;
                      values = [ 0 ] ++ state.values;
                    }
                  else
                    stop (failure "boundary-mismatch" "level-zero" consumed)
                else if inspected.value.kind == "suc" then
                  if exact [ "kind" "level" ] job.node then
                    next {
                      inherit consumed;
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
                    stop (failure "boundary-mismatch" "level-suc" consumed)
                else if inspected.value.kind == "max" then
                  if exact [ "kind" "left" "right" ] job.node then
                    next {
                      inherit consumed;
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
                    stop (failure "boundary-mismatch" "level-max" consumed)
                else
                  stop (failure "boundary-mismatch" "level-constructor" consumed);
      };
      final = builtins.elemAt states (builtins.length states - 1);
      height = if final.result == null && final.values != [ ] then builtins.head final.values else null;
      rebuilt = if height == null then null else rebuildCanonical height;
    in
    if final.result != null then
      final.result
    else if !rebuilt.ok then
      rebuilt // { inputConsumed = final.consumed; }
    else
      rebuilt
      // {
        inherit height;
        inherit (final) consumed;
      };

  normalize = value: normalizeInput { inherit value; };

  # output construction is charged independently after the input tree has consumed its traversal budget
  rebuildCanonical =
    height:
    let
      outputNodes = if builtins.isInt height && height >= 0 then height + 1 else limits.nodes + 1;
      build = count: if count == 0 then zero else suc (build (count - 1));
    in
    if !builtins.isInt height || height < 0 then
      failure "boundary-mismatch" "level-output-height" 0
    else if outputNodes > limits.nodes then
      failure "resource-exhaustion" "level-output-nodes" limits.nodes
    else if height > limits.depth then
      failure "resource-exhaustion" "level-output-depth" limits.depth
    else
      {
        ok = true;
        value = build height;
        outputConsumed = outputNodes;
      };

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
    ;
  formation = {
    universe = successor;
    pi = maximum;
    sigma = maximum;
    sum = maximum;
    unit = zero;
    empty = zero;
    identity = normalize;
  };
}
