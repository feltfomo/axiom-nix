{
  result,
  policy,
  budget,
  observe,
}:
let
  last = values: builtins.elemAt values (builtins.length values - 1);

  dispatch =
    state: job: rest:
    if job.plan.kind == "opaque" then
      state
      // {
        pending = rest;
        category = if job.path == [ ] then null else state.category;
      }
    else
      let
        observed = observe.outerAt "observe-deep" job.path job.value;
      in
      if observed.kind != "success" then
        state
        // {
          pending = [ ];
          failure = observed;
        }
      else if job.plan.kind == "category" then
        if observed.category != job.plan.category then
          state
          // {
            pending = [ ];
            failure = result.mismatch {
              operation = "observe-deep";
              inherit (job) path;
              expected = job.plan.category;
              observed = observed.category;
            };
          }
        else
          state
          // {
            pending = rest;
            category = if job.path == [ ] then observed.category else state.category;
          }
      else if job.plan.kind == "list" then
        if observed.category != "list" then
          state
          // {
            pending = [ ];
            failure = result.mismatch {
              operation = "observe-deep";
              inherit (job) path;
              expected = "list";
              observed = observed.category;
            };
          }
        else
          let
            lengthAttempt = builtins.tryEval (builtins.length job.value);
          in
          if !lengthAttempt.success then
            state
            // {
              pending = [ ];
              failure = result.hostFailure {
                operation = "observe-deep";
                inherit (job) path;
                guardedOperation = "typed-deep-list-length";
              };
            }
          else
            state
            // {
              pending = [
                {
                  kind = "list-cursor";
                  inherit (job) value path depth;
                  plan = job.plan.element;
                  index = 0;
                  length = lengthAttempt.value;
                }
              ]
              ++ rest;
              category = if job.path == [ ] then "list" else state.category;
            }
      else if job.plan.kind == "attrs" then
        if observed.category != "attrs" then
          state
          // {
            pending = [ ];
            failure = result.mismatch {
              operation = "observe-deep";
              inherit (job) path;
              expected = "attrs";
              observed = observed.category;
            };
          }
        else
          state
          // {
            pending = [
              {
                kind = "attrs-cursor";
                inherit (job) value path depth;
                fields = job.plan.fields;
                position = 0;
              }
            ]
            ++ rest;
            category = if job.path == [ ] then "attrs" else state.category;
          }
      else
        state
        // {
          pending = [ ];
          failure = result.internalBug {
            operation = "observe-deep";
            inherit (job) path;
            code = result.codes.unknownPlanDispatch;
            context = {
              kind = job.plan.kind;
            };
          };
        };

  step =
    state:
    let
      job = builtins.head state.pending;
      rest = builtins.tail state.pending;
    in
    if job.kind == "list-cursor" then
      if job.index == job.length then
        state // { pending = rest; }
      else
        state
        // {
          pending = [
            {
              kind = "node";
              inherit (job) plan;
              value = builtins.elemAt job.value job.index;
              path = job.path ++ [ "index:${toString job.index}" ];
              depth = job.depth + 1;
            }
            (job // { index = job.index + 1; })
          ]
          ++ rest;
        }
    else if job.kind == "attrs-cursor" then
      if job.position == builtins.length job.fields then
        state // { pending = rest; }
      else
        let
          field = builtins.elemAt job.fields job.position;
        in
        state
        // {
          pending = [
            {
              kind = "field-node";
              inherit field;
              inherit (job) value;
              path = job.path ++ [ "field:${field.name}" ];
              depth = job.depth + 1;
            }
            (job // { position = job.position + 1; })
          ]
          ++ rest;
        }
    else
      let
        charged = budget.charge {
          operation = "observe-deep";
          inherit (job) path depth;
          inherit (state) budgetName;
          inherit (state) budget;
          state = { inherit (state) consumed; };
        };
      in
      if !charged.ok then
        state
        // {
          pending = [ ];
          inherit (charged) failure;
        }
      else if job.kind == "field-node" then
        if !(builtins.hasAttr job.field.name job.value) then
          state
          // {
            consumed = charged.state.consumed;
            pending = [ ];
            failure = result.mismatch {
              operation = "observe-deep";
              inherit (job) path;
              expected = "field:${job.field.name}";
              observed = "missing-field";
            };
          }
        else
          dispatch (state // { consumed = charged.state.consumed; }) {
            kind = "node";
            plan = job.field.plan;
            value = job.value.${job.field.name};
            inherit (job) path depth;
          } rest
      else if job.kind == "node" then
        dispatch (state // { consumed = charged.state.consumed; }) job rest
      else
        state
        // {
          consumed = charged.state.consumed;
          pending = [ ];
          failure = result.internalBug {
            operation = "observe-deep";
            inherit (job) path;
            code = result.codes.impossibleTraversal;
            context = { inherit (job) kind; };
          };
        };

  runMachine =
    {
      name,
      spec,
      plan,
      value,
    }:
    let
      states = builtins.genericClosure {
        startSet = [
          {
            key = 0;
            machine = {
              pending = [
                {
                  kind = "node";
                  inherit plan value;
                  path = [ ];
                  depth = 0;
                }
              ];
              consumed = 0;
              failure = null;
              category = null;
              budgetName = name;
              budget = spec;
            };
          }
        ];
        operator =
          item:
          if item.machine.failure != null || item.machine.pending == [ ] then
            [ ]
          else
            [
              {
                key = item.key + 1;
                machine = step item.machine;
              }
            ];
      };
    in
    (last states).machine;
in
{
  run =
    {
      name,
      plan,
      value,
    }:
    let
      validated = policy.validatePlan plan;
      resolved = budget.resolve {
        operation = "observe-deep";
        path = [ ];
        inherit name;
      };
    in
    if validated.kind != "success" then
      validated
    else if resolved.kind != "success" then
      resolved
    else
      let
        machine = runMachine {
          inherit name value;
          spec = resolved.payload;
          plan = validated.payload;
        };
      in
      if machine.failure != null then
        machine.failure
      else
        result.success {
          operation = "observe-deep";
          path = [ ];
          policy = "typed-deep";
          inherit (machine) category;
          payload = {
            inherit value;
            inherit (machine) consumed;
          };
        };
}
