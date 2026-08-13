{
  result,
  policy,
  budget,
  observe,
  logismos,
}:
let
  lists = import ../internal/lists.nix;
  inherit (lists) reverse;
  inherit (logismos) transition;
  stack = import ../logismos/stack.nix;

  dispatch =
    state: job: rest:
    if job.plan.kind == "opaque" then
      state
      // {
        pending = rest;
        category = if job.pathRev == [ ] then null else state.category;
      }
    else
      let
        path = reverse job.pathRev;
        observed = observe.outerAt "observe-deep" path job.value;
      in
      if observed.kind != "success" then
        state
        // {
          status = "failed";
          pending = stack.empty;
          failure = observed;
        }
      else if job.plan.kind == "category" then
        if observed.category != job.plan.category then
          state
          // {
            status = "failed";
            pending = stack.empty;
            failure = result.mismatch {
              operation = "observe-deep";
              inherit path;
              expected = job.plan.category;
              observed = observed.category;
            };
          }
        else
          state
          // {
            pending = rest;
            category = if job.pathRev == [ ] then observed.category else state.category;
          }
      else if job.plan.kind == "list" then
        if observed.category != "list" then
          state
          // {
            status = "failed";
            pending = stack.empty;
            failure = result.mismatch {
              operation = "observe-deep";
              inherit path;
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
              status = "failed";
              pending = stack.empty;
              failure = result.hostFailure {
                operation = "observe-deep";
                inherit path;
                guardedOperation = "typed-deep-list-length";
              };
            }
          else
            state
            // {
              pending = stack.push {
                kind = "list-cursor";
                remaining = job.value;
                inherit (job) depth pathRev;
                plan = job.plan.element;
                index = 0;
                length = lengthAttempt.value;
              } rest;
              category = if job.pathRev == [ ] then "list" else state.category;
            }
      else if job.plan.kind == "attrs" then
        if observed.category != "attrs" then
          state
          // {
            status = "failed";
            pending = stack.empty;
            failure = result.mismatch {
              operation = "observe-deep";
              inherit path;
              expected = "attrs";
              observed = observed.category;
            };
          }
        else
          state
          // {
            pending = stack.push {
              kind = "attrs-cursor";
              inherit (job) value depth pathRev;
              fields = job.plan.fields;
              position = 0;
            } rest;
            category = if job.pathRev == [ ] then "attrs" else state.category;
          }
      else
        state
        // {
          status = "failed";
          pending = stack.empty;
          failure = result.internalBug {
            operation = "observe-deep";
            inherit path;
            code = result.codes.unknownPlanDispatch;
            context = {
              kind = job.plan.kind;
            };
          };
        };

  step =
    state:
    let
      job = stack.top state.pending;
      rest = stack.pop state.pending;
    in
    if job.kind == "list-cursor" then
      if job.index == job.length then
        state // { pending = rest; }
      else
        let
          pathRev = [ "index:${toString job.index}" ] ++ job.pathRev;
          path = reverse pathRev;
          depth = job.depth + 1;
          charged = budget.charge {
            operation = "observe-deep";
            inherit path;
            inherit (state) budgetName budget;
            state = state.usage;
            inherit depth;
          };
        in
        if !charged.ok then
          state
          // {
            status = "failed";
            pending = stack.empty;
            inherit (charged) failure;
          }
        else
          let
            inspected = builtins.tryEval (
              let
                tail = builtins.tail job.remaining;
              in
              builtins.seq tail {
                value = builtins.head job.remaining;
                inherit tail;
              }
            );
          in
          if !inspected.success then
            state
            // {
              status = "failed";
              usage = charged.state;
              pending = stack.empty;
              failure = result.hostFailure {
                operation = "observe-deep";
                inherit path;
                guardedOperation = "typed-deep-list-cursor";
              };
            }
          else
            state
            // {
              usage = charged.state;
              pending =
                stack.push
                  {
                    kind = "node";
                    charged = true;
                    inherit (job) plan;
                    value = inspected.value.value;
                    inherit pathRev depth;
                  }
                  (
                    stack.push (
                      job
                      // {
                        remaining = inspected.value.tail;
                        index = job.index + 1;
                      }
                    ) rest
                  );
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
          pending = stack.push {
            kind = "field-node";
            inherit field;
            inherit (job) value;
            pathRev = [ "field:${field.name}" ] ++ job.pathRev;
            depth = job.depth + 1;
          } (stack.push (job // { position = job.position + 1; }) rest);
        }
    else
      let
        path = reverse job.pathRev;
        charged =
          if job.charged or false then
            {
              ok = true;
              state = state.usage;
            }
          else
            budget.charge {
              operation = "observe-deep";
              inherit path;
              inherit (state) budgetName budget;
              state = state.usage;
              inherit (job) depth;
            };
      in
      if !charged.ok then
        state
        // {
          status = "failed";
          pending = stack.empty;
          inherit (charged) failure;
        }
      else if job.kind == "field-node" then
        if !(builtins.hasAttr job.field.name job.value) then
          state
          // {
            status = "failed";
            usage = charged.state;
            pending = stack.empty;
            failure = result.mismatch {
              operation = "observe-deep";
              inherit path;
              expected = "field:${job.field.name}";
              observed = "missing-field";
            };
          }
        else
          dispatch (state // { usage = charged.state; }) {
            kind = "node";
            plan = job.field.plan;
            value = job.value.${job.field.name};
            inherit (job) pathRev depth;
          } rest
      else if job.kind == "node" then
        dispatch (state // { usage = charged.state; }) job rest
      else
        state
        // {
          status = "failed";
          usage = charged.state;
          pending = stack.empty;
          failure = result.internalBug {
            operation = "observe-deep";
            inherit path;
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
    transition.run {
      initial = {
        status = "running";
        pending = stack.push {
          kind = "node";
          inherit plan value;
          pathRev = [ ];
          depth = 0;
        } stack.empty;
        usage = budget.initial;
        failure = null;
        category = null;
        budgetName = name;
        budget = spec;
      };
      terminal = state: state.status != "running" || stack.isEmpty state.pending;
      inherit step;
    };
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
      if machine.status == "failed" then
        machine.failure
      else
        result.success {
          operation = "observe-deep";
          path = [ ];
          policy = "typed-deep";
          inherit (machine) category;
          payload = {
            inherit value;
            consumed = machine.usage.nodes;
          };
        };
}
