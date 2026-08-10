{ representation }:
let
  inherit (representation) limits;
  exact = names: value: builtins.isAttrs value && builtins.attrNames value == names;
  reverse = builtins.foldl' (values: value: [ value ] ++ values) [ ];
  failure = kind: path: detail: {
    ok = false;
    inherit kind path detail;
  };

  finish =
    state:
    state
    // {
      jobs = [ ];
      status = "done";
    };

  advance =
    onVariable: state:
    if state.status != "running" || state.jobs == [ ] then
      [ ]
    else
      let
        job = builtins.head state.jobs;
        rest = builtins.tail state.jobs;
        nextKey = state.key + 1;
        next = value: state // value // { key = nextKey; };
      in
      # build jobs consume child values in reverse visit order
      # so parent reconstruction stays iterative
      if job.action == "build-lambda" then
        let
          body = builtins.head state.values;
          values = [ (representation.lambda body) ] ++ builtins.tail state.values;
        in
        [
          (next {
            inherit values;
            jobs = rest;
            status = if rest == [ ] then "done" else "running";
          })
        ]
      else if job.action == "build-application" then
        let
          argument = builtins.head state.values;
          function = builtins.head (builtins.tail state.values);
          values = [
            (representation.application function argument)
          ]
          ++ builtins.tail (builtins.tail state.values);
        in
        [
          (next {
            inherit values;
            jobs = rest;
            status = if rest == [ ] then "done" else "running";
          })
        ]
      else if job.action == "build-annotation" then
        let
          annotation = builtins.head state.values;
          subject = builtins.head (builtins.tail state.values);
          values = [
            (representation.annotation subject annotation)
          ]
          ++ builtins.tail (builtins.tail state.values);
        in
        [
          (next {
            inherit values;
            jobs = rest;
            status = if rest == [ ] then "done" else "running";
          })
        ]
      else if job.depth > limits.depth then
        [
          (finish (next {
            result = failure "resource-exhaustion" job.path "depth";
          }))
        ]
      else if state.consumed >= limits.nodes then
        [
          (finish (next {
            result = failure "resource-exhaustion" job.path "nodes";
          }))
        ]
      else
        let
          consumed = state.consumed + 1;
          outer = builtins.tryEval (builtins.typeOf job.node);
        in
        if !outer.success then
          [
            (finish (next {
              inherit consumed;
              result = failure "host-failure" job.path "node-outer";
            }))
          ]
        else if outer.value != "set" then
          [
            (finish (next {
              inherit consumed;
              result = failure "boundary-mismatch" job.path "node-${outer.value}";
            }))
          ]
        else
          let
            inspected = builtins.tryEval (
              let
                names = builtins.attrNames job.node;
                kind = job.node.kind;
              in
              builtins.seq names (builtins.seq kind { inherit names kind; })
            );
          in
          if !inspected.success then
            [
              (finish (next {
                inherit consumed;
                result = failure "host-failure" job.path "node-control";
              }))
            ]
          else if inspected.value.kind == "variable" then
            let
              checked = builtins.tryEval (
                exact [ "kind" "level" ] job.node
                && builtins.isInt job.node.level
                && job.node.level >= 0
                && job.node.level < job.scope
              );
            in
            if !checked.success then
              [
                (finish (next {
                  inherit consumed;
                  result = failure "host-failure" job.path "variable-control";
                }))
              ]
            else if !checked.value then
              [
                (finish (next {
                  inherit consumed;
                  result = failure "boundary-mismatch" job.path "variable";
                }))
              ]
            else
              let
                mapped = builtins.tryEval (onVariable {
                  inherit (job)
                    node
                    scope
                    depth
                    path
                    ;
                });
              in
              if !mapped.success then
                [
                  (finish (next {
                    inherit consumed;
                    result = failure "internal-bug" job.path "variable-map";
                  }))
                ]
              else
                let
                  values = [ mapped.value ] ++ state.values;
                  paths = [ job.path ] ++ state.paths;
                  variables = [
                    {
                      inherit (job) path;
                      inherit (job.node) level;
                    }
                  ]
                  ++ state.variables;
                in
                [
                  (next {
                    inherit
                      consumed
                      values
                      paths
                      variables
                      ;
                    jobs = rest;
                    status = if rest == [ ] then "done" else "running";
                  })
                ]
          else if inspected.value.kind == "lambda" then
            if !exact [ "body" "kind" ] job.node then
              [
                (finish (next {
                  inherit consumed;
                  result = failure "boundary-mismatch" job.path "lambda";
                }))
              ]
            else
              [
                (next {
                  inherit consumed;
                  paths = [ job.path ] ++ state.paths;
                  jobs = [
                    {
                      action = "visit";
                      node = job.node.body;
                      scope = job.scope + 1;
                      depth = job.depth + 1;
                      path = job.path ++ [ "body" ];
                    }
                    { action = "build-lambda"; }
                  ]
                  ++ rest;
                })
              ]
          else if inspected.value.kind == "application" then
            if !exact [ "argument" "function" "kind" ] job.node then
              [
                (finish (next {
                  inherit consumed;
                  result = failure "boundary-mismatch" job.path "application";
                }))
              ]
            else
              [
                (next {
                  inherit consumed;
                  paths = [ job.path ] ++ state.paths;
                  jobs = [
                    {
                      action = "visit";
                      node = job.node.function;
                      inherit (job) scope;
                      depth = job.depth + 1;
                      path = job.path ++ [ "function" ];
                    }
                    {
                      action = "visit";
                      node = job.node.argument;
                      inherit (job) scope;
                      depth = job.depth + 1;
                      path = job.path ++ [ "argument" ];
                    }
                    { action = "build-application"; }
                  ]
                  ++ rest;
                })
              ]
          else if inspected.value.kind == "annotation" then
            if !exact [ "annotation" "kind" "subject" ] job.node then
              [
                (finish (next {
                  inherit consumed;
                  result = failure "boundary-mismatch" job.path "annotation";
                }))
              ]
            else
              [
                (next {
                  inherit consumed;
                  paths = [ job.path ] ++ state.paths;
                  jobs = [
                    {
                      action = "visit";
                      node = job.node.subject;
                      inherit (job) scope;
                      depth = job.depth + 1;
                      path = job.path ++ [ "subject" ];
                    }
                    {
                      action = "visit";
                      node = job.node.annotation;
                      inherit (job) scope;
                      depth = job.depth + 1;
                      path = job.path ++ [ "annotation" ];
                    }
                    { action = "build-annotation"; }
                  ]
                  ++ rest;
                })
              ]
          else
            [
              (finish (next {
                inherit consumed;
                result = failure "boundary-mismatch" job.path "constructor";
              }))
            ];

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
      leftChecked = rewrite {
        root = left;
        inherit scope;
      };
      rightChecked = rewrite {
        root = right;
        inherit scope;
      };
      states = builtins.genericClosure {
        startSet = [
          {
            key = 0;
            status = "running";
            consumed = 0;
            jobs = [ { inherit left right; } ];
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
              nextKey = state.key + 1;
              stop = equalValue: [
                (
                  state
                  // {
                    key = nextKey;
                    status = "done";
                    jobs = [ ];
                    inherit equalValue;
                  }
                )
              ];
              continue = jobs: [
                (
                  state
                  // {
                    key = nextKey;
                    consumed = state.consumed + 1;
                    inherit jobs;
                    status = if jobs == [ ] then "done" else "running";
                  }
                )
              ];
            in
            if state.consumed >= limits.nodes then
              stop false
            else if job.left.kind != job.right.kind then
              stop false
            else if job.left.kind == "variable" then
              if job.left.level == job.right.level then continue rest else stop false
            else if job.left.kind == "lambda" then
              continue (
                [
                  {
                    left = job.left.body;
                    right = job.right.body;
                  }
                ]
                ++ rest
              )
            else if job.left.kind == "application" then
              continue (
                [
                  {
                    left = job.left.function;
                    right = job.right.function;
                  }
                  {
                    left = job.left.argument;
                    right = job.right.argument;
                  }
                ]
                ++ rest
              )
            else
              continue (
                [
                  {
                    left = job.left.subject;
                    right = job.right.subject;
                  }
                  {
                    left = job.left.annotation;
                    right = job.right.annotation;
                  }
                ]
                ++ rest
              );
      };
      final = builtins.elemAt states (builtins.length states - 1);
    in
    leftChecked.ok && rightChecked.ok && final.status == "done" && (final.equalValue or true);
in
{
  inherit rewrite equal;
  validate = rewrite;
}
