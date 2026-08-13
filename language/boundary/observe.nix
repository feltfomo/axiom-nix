{
  result,
  policy,
  budget,
  logismos,
}:
let
  lists = import ../internal/lists.nix;
  inherit (lists) reverse;
  inherit (logismos) transition;

  outerAt =
    operation: path: value:
    let
      checked = builtins.tryEval (builtins.typeOf value);
    in
    if !checked.success then
      result.hostFailure {
        inherit operation path;
        guardedOperation = "host-type-classification";
      }
    else
      let
        category = policy.fromHost checked.value;
      in
      if category == null then
        result.internalBug {
          inherit operation path;
          code = result.codes.unknownHostCategory;
          context = {
            hostCategory = checked.value;
          };
        }
      else
        result.success {
          inherit operation path category;
          policy = "outer";
          payload = value;
        };

  meterSpine =
    {
      category,
      entries,
      total,
      budgetName,
      budgetSpec,
      state,
    }:
    transition.run {
      initial = {
        status = "running";
        position = 0;
        usage = state;
        failure = null;
      };
      terminal = current: current.status != "running";
      step =
        current:
        if current.position == total then
          current // { status = "done"; }
        else
          let
            label =
              if category == "list" then toString current.position else builtins.elemAt entries current.position;
            path = [ "${if category == "list" then "index" else "field"}:${label}" ];
            charged = budget.charge {
              operation = "observe-spine";
              inherit path budgetName;
              budget = budgetSpec;
              state = current.usage;
              depth = 1;
            };
          in
          if charged.ok then
            current
            // {
              position = current.position + 1;
              usage = charged.state;
            }
          else
            current
            // {
              status = "failed";
              inherit (charged) failure;
            };
    };

  validateSelections =
    {
      fields,
      budgetName,
      budgetSpec,
      state,
    }:
    transition.run {
      initial = {
        status = "running";
        remaining = fields;
        index = 0;
        seen = { };
        canonical = [ ];
        usage = state;
        failure = null;
      };
      terminal = current: current.status != "running";
      step =
        current:
        let
          empty = builtins.tryEval (current.remaining == [ ]);
          path = [ "selection:${toString current.index}" ];
        in
        if !empty.success then
          current
          // {
            status = "failed";
            failure = result.hostFailure {
              operation = "validate-fields";
              inherit path;
              guardedOperation = "selected-field-specification-validation";
            };
          }
        else if empty.value then
          current
          // {
            status = "done";
            canonical = reverse current.canonical;
          }
        else
          let
            charged = budget.charge {
              operation = "validate-fields";
              inherit path budgetName;
              budget = budgetSpec;
              state = current.usage;
              depth = 1;
            };
          in
          if !charged.ok then
            current
            // {
              status = "failed";
              inherit (charged) failure;
            }
          else
            let
              inspected = builtins.tryEval (
                let
                  field = builtins.head current.remaining;
                  tail = builtins.tail current.remaining;
                  valid =
                    builtins.isAttrs field
                    &&
                      builtins.attrNames field == [
                        "category"
                        "name"
                      ]
                    && builtins.isString field.name
                    && builtins.isString field.category;
                  name = if valid then field.name else "";
                  category = if valid then field.category else "";
                in
                builtins.seq valid (
                  builtins.seq name (
                    builtins.seq category (
                      builtins.seq tail {
                        inherit
                          valid
                          name
                          category
                          tail
                          ;
                      }
                    )
                  )
                )
              );
            in
            if !inspected.success then
              current
              // {
                status = "failed";
                usage = charged.state;
                failure = result.hostFailure {
                  operation = "validate-fields";
                  inherit path;
                  guardedOperation = "selected-field-specification-validation";
                };
              }
            else if
              !inspected.value.valid
              || !policy.isCategory inspected.value.category
              || builtins.hasAttr inspected.value.name current.seen
            then
              current
              // {
                status = "failed";
                usage = charged.state;
                failure = result.mismatch {
                  operation = "validate-fields";
                  inherit path;
                  expected = "unique-valid-field-selection";
                  observed = "malformed-or-duplicate-selection";
                };
              }
            else
              current
              // {
                remaining = inspected.value.tail;
                index = current.index + 1;
                seen = current.seen // {
                  "${inspected.value.name}" = true;
                };
                canonical = [
                  {
                    inherit (inspected.value) name category;
                  }
                ]
                ++ current.canonical;
                usage = charged.state;
              };
    };

  observeSelections =
    {
      fields,
      value,
      budgetName,
      budgetSpec,
      state,
    }:
    transition.run {
      initial = {
        status = "running";
        remaining = fields;
        observations = [ ];
        usage = state;
        failure = null;
      };
      terminal = current: current.status != "running";
      step =
        current:
        if current.remaining == [ ] then
          current
          // {
            status = "done";
            observations = reverse current.observations;
          }
        else
          let
            field = builtins.head current.remaining;
            path = [ "field:${field.name}" ];
            charged = budget.charge {
              operation = "observe-fields";
              inherit path budgetName;
              budget = budgetSpec;
              state = current.usage;
              depth = 1;
            };
          in
          if !charged.ok then
            current
            // {
              status = "failed";
              inherit (charged) failure;
            }
          else if !(builtins.hasAttr field.name value) then
            current
            // {
              status = "failed";
              usage = charged.state;
              failure = result.mismatch {
                operation = "observe-fields";
                inherit path;
                expected = "field:${field.name}";
                observed = "missing-field";
              };
            }
          else
            let
              observed = outerAt "observe-fields" path value.${field.name};
            in
            if observed.kind != "success" then
              current
              // {
                status = "failed";
                usage = charged.state;
                failure = observed;
              }
            else if observed.category != field.category then
              current
              // {
                status = "failed";
                usage = charged.state;
                failure = result.mismatch {
                  operation = "observe-fields";
                  inherit path;
                  expected = field.category;
                  observed = observed.category;
                };
              }
            else
              current
              // {
                remaining = builtins.tail current.remaining;
                observations = [
                  {
                    inherit (field) name;
                    inherit (observed) category;
                  }
                ]
                ++ current.observations;
                usage = charged.state;
              };
    };
in
{
  inherit outerAt;

  opaque =
    value:
    result.success {
      operation = "observe-opaque";
      path = [ ];
      policy = "opaque";
      category = null;
      payload = value;
    };

  outer = value: outerAt "observe-outer" [ ] value;

  spine =
    { name, value }:
    let
      resolved = budget.resolve {
        operation = "observe-spine";
        path = [ ];
        inherit name;
      };
      observed = if resolved.kind == "success" then outerAt "observe-spine" [ ] value else null;
    in
    if resolved.kind != "success" then
      resolved
    else
      let
        root = budget.charge {
          operation = "observe-spine";
          path = [ ];
          budgetName = name;
          budget = resolved.payload;
          state = budget.initial;
          depth = 0;
        };
      in
      if !root.ok then
        root.failure
      else if observed.kind != "success" then
        observed
      else if
        !builtins.elem observed.category [
          "list"
          "attrs"
        ]
      then
        result.mismatch {
          operation = "observe-spine";
          path = [ ];
          expected = "list-or-attrs";
          observed = observed.category;
        }
      else
        let
          spineAttempt =
            if observed.category == "list" then
              builtins.tryEval (builtins.length value)
            else
              builtins.tryEval (builtins.attrNames value);
        in
        if !spineAttempt.success then
          result.hostFailure {
            operation = "observe-spine";
            path = [ ];
            guardedOperation = if observed.category == "list" then "list-length" else "attr-names";
          }
        else
          let
            total =
              if observed.category == "list" then spineAttempt.value else builtins.length spineAttempt.value;
            machine = meterSpine {
              inherit (observed) category;
              entries = if observed.category == "list" then [ ] else spineAttempt.value;
              inherit total;
              budgetName = name;
              budgetSpec = resolved.payload;
              inherit (root) state;
            };
          in
          if machine.status == "failed" then
            machine.failure
          else
            result.success {
              operation = "observe-spine";
              path = [ ];
              policy = "spine";
              inherit (observed) category;
              payload = {
                size = total;
                consumed = machine.usage.nodes;
              };
            };

  fields =
    {
      name,
      fields,
      value,
    }:
    let
      resolved = budget.resolve {
        operation = "observe-fields";
        path = [ ];
        inherit name;
      };
    in
    if resolved.kind != "success" then
      resolved
    else
      let
        validated = validateSelections {
          inherit fields;
          budgetName = name;
          budgetSpec = resolved.payload;
          state = budget.initial;
        };
      in
      if validated.status == "failed" then
        validated.failure
      else
        let
          root = budget.charge {
            operation = "observe-fields";
            path = [ ];
            budgetName = name;
            budget = resolved.payload;
            state = validated.usage;
            depth = 0;
          };
          observed = if root.ok then outerAt "observe-fields" [ ] value else null;
        in
        if !root.ok then
          root.failure
        else if observed.kind != "success" then
          observed
        else if observed.category != "attrs" then
          result.mismatch {
            operation = "observe-fields";
            path = [ ];
            expected = "attrs";
            observed = observed.category;
          }
        else
          let
            machine = observeSelections {
              fields = validated.canonical;
              inherit value;
              budgetName = name;
              budgetSpec = resolved.payload;
              inherit (root) state;
            };
          in
          if machine.status == "failed" then
            machine.failure
          else
            result.success {
              operation = "observe-fields";
              path = [ ];
              policy = "selected-fields";
              category = "attrs";
              payload = {
                inherit value;
                inherit (machine) observations;
                consumed = machine.usage.nodes;
              };
            };

  invoke =
    {
      callback,
      argument,
      expected,
    }:
    let
      expectedResult = policy.validateCategory expected;
      callable = outerAt "invoke-callback" [ ] callback;
    in
    if expectedResult.kind != "success" then
      expectedResult
    else if callable.kind != "success" then
      callable
    else if callable.category != "function" then
      result.mismatch {
        operation = "invoke-callback";
        path = [ ];
        expected = "function";
        observed = callable.category;
      }
    else
      let
        called = builtins.tryEval (
          let
            returned = callback argument;
            hostCategory = builtins.typeOf returned;
          in
          builtins.seq hostCategory { inherit returned hostCategory; }
        );
      in
      if !called.success then
        result.hostFailure {
          operation = "invoke-callback";
          path = [ ];
          guardedOperation = "callback-application";
        }
      else
        let
          category = policy.fromHost called.value.hostCategory;
        in
        if category == null then
          result.internalBug {
            operation = "invoke-callback";
            path = [ ];
            code = result.codes.unknownHostCategory;
            context = {
              hostCategory = called.value.hostCategory;
            };
          }
        else if category != expectedResult.payload then
          result.mismatch {
            operation = "invoke-callback";
            path = [ ];
            expected = expectedResult.payload;
            observed = category;
          }
        else
          result.success {
            operation = "invoke-callback";
            path = [ ];
            policy = "outer";
            inherit category;
            payload = called.value.returned;
          };
}
