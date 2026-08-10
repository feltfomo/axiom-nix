{
  result,
  policy,
  budget,
}:
let
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

  last = values: builtins.elemAt values (builtins.length values - 1);
  reverse = values: builtins.foldl' (reversed: value: [ value ] ++ reversed) [ ] values;

  meterSpine =
    {
      category,
      entries,
      total,
      budgetName,
      budgetSpec,
      state,
    }:
    let
      steps = builtins.genericClosure {
        startSet = [
          {
            key = 0;
            machine = {
              position = 0;
              inherit state;
              failure = null;
            };
          }
        ];
        operator =
          item:
          if item.machine.failure != null || item.machine.position == total then
            [ ]
          else
            let
              position = item.machine.position;
              label = if category == "list" then toString position else builtins.elemAt entries position;
              path = [ "${if category == "list" then "index" else "field"}:${label}" ];
              charged = budget.charge {
                operation = "observe-spine";
                inherit path budgetName;
                budget = budgetSpec;
                state = item.machine.state;
                depth = 1;
              };
            in
            [
              {
                key = item.key + 1;
                machine =
                  if charged.ok then
                    {
                      position = position + 1;
                      inherit (charged) state;
                      failure = null;
                    }
                  else
                    {
                      inherit position;
                      state = item.machine.state;
                      inherit (charged) failure;
                    };
              }
            ];
      };
    in
    (last steps).machine;

  validateSelections =
    {
      fields,
      budgetName,
      budgetSpec,
      state,
      index,
      seen,
      canonical,
    }:
    if fields == [ ] then
      {
        ok = true;
        inherit state;
        canonical = reverse canonical;
      }
    else
      let
        path = [ "selection:${toString index}" ];
        charged = budget.charge {
          operation = "validate-fields";
          inherit path budgetName;
          budget = budgetSpec;
          inherit state;
          depth = 1;
        };
      in
      if !charged.ok then
        {
          ok = false;
          inherit (charged) failure;
        }
      else
        let
          inspected = builtins.tryEval (
            let
              field = builtins.head fields;
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
                builtins.seq category {
                  inherit valid name category;
                }
              )
            )
          );
        in
        if !inspected.success then
          {
            ok = false;
            failure = result.hostFailure {
              operation = "validate-fields";
              inherit path;
              guardedOperation = "selected-field-specification-validation";
            };
          }
        else if
          !inspected.value.valid
          || !policy.isCategory inspected.value.category
          || builtins.hasAttr inspected.value.name seen
        then
          {
            ok = false;
            failure = result.mismatch {
              operation = "validate-fields";
              inherit path;
              expected = "unique-valid-field-selection";
              observed = "malformed-or-duplicate-selection";
            };
          }
        else
          validateSelections {
            fields = builtins.tail fields;
            inherit budgetName budgetSpec;
            inherit (charged) state;
            index = index + 1;
            seen = seen // {
              "${inspected.value.name}" = true;
            };
            canonical = [
              {
                inherit (inspected.value) name category;
              }
            ]
            ++ canonical;
          };

  observeSelections =
    {
      fields,
      value,
      budgetName,
      budgetSpec,
      state,
      observations,
    }:
    if fields == [ ] then
      result.success {
        operation = "observe-fields";
        path = [ ];
        policy = "selected-fields";
        category = "attrs";
        payload = {
          inherit value;
          observations = reverse observations;
          inherit (state) consumed;
        };
      }
    else
      let
        field = builtins.head fields;
        path = [ "field:${field.name}" ];
        charged = budget.charge {
          operation = "observe-fields";
          inherit path budgetName;
          budget = budgetSpec;
          inherit state;
          depth = 1;
        };
      in
      if !charged.ok then
        charged.failure
      else if !(builtins.hasAttr field.name value) then
        result.mismatch {
          operation = "observe-fields";
          inherit path;
          expected = "field:${field.name}";
          observed = "missing-field";
        }
      else
        let
          observed = outerAt "observe-fields" path value.${field.name};
        in
        if observed.kind != "success" then
          observed
        else if observed.category != field.category then
          result.mismatch {
            operation = "observe-fields";
            inherit path;
            expected = field.category;
            observed = observed.category;
          }
        else
          observeSelections {
            fields = builtins.tail fields;
            inherit value budgetName budgetSpec;
            inherit (charged) state;
            observations = [
              {
                inherit (field) name;
                inherit (observed) category;
              }
            ]
            ++ observations;
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
        root = budget.charge {
          operation = "observe-spine";
          path = [ ];
          budgetName = name;
          budget = resolved.payload;
          state = {
            consumed = 0;
          };
          depth = 0;
        };
        spineAttempt =
          if observed.category == "list" then
            builtins.tryEval (builtins.length value)
          else
            builtins.tryEval (builtins.attrNames value);
      in
      if !root.ok then
        root.failure
      else if !spineAttempt.success then
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
        if machine.failure != null then
          machine.failure
        else
          result.success {
            operation = "observe-spine";
            path = [ ];
            policy = "spine";
            inherit (observed) category;
            payload = {
              size = total;
              inherit (machine.state) consumed;
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
          state = {
            consumed = 0;
          };
          index = 0;
          seen = { };
          canonical = [ ];
        };
      in
      if !validated.ok then
        validated.failure
      else
        let
          observed = outerAt "observe-fields" [ ] value;
          root = budget.charge {
            operation = "observe-fields";
            path = [ ];
            budgetName = name;
            budget = resolved.payload;
            inherit (validated) state;
            depth = 0;
          };
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
          observeSelections {
            fields = validated.canonical;
            inherit value;
            budgetName = name;
            budgetSpec = resolved.payload;
            inherit (root) state;
            observations = [ ];
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
