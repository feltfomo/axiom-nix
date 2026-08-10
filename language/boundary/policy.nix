{
  result,
  budget,
}:
let
  categories = [
    "null"
    "bool"
    "int"
    "float"
    "string"
    "path"
    "list"
    "attrs"
    "function"
  ];
  policies = [
    "opaque"
    "outer"
    "spine"
    "selected-fields"
    "typed-deep"
  ];
  hostCategories = {
    null = "null";
    bool = "bool";
    int = "int";
    float = "float";
    string = "string";
    path = "path";
    list = "list";
    set = "attrs";
    lambda = "function";
  };

  guardedChoice =
    operation: expected: choices: value:
    let
      checked = builtins.tryEval (
        let
          valid = builtins.isString value && builtins.elem value choices;
          observed = if builtins.isString value then value else builtins.typeOf value;
        in
        builtins.seq valid (builtins.seq observed { inherit valid observed; })
      );
    in
    if !checked.success then
      result.hostFailure {
        inherit operation;
        path = [ ];
        guardedOperation = "${operation}-control-validation";
      }
    else if !checked.value.valid then
      result.mismatch {
        inherit operation expected;
        path = [ ];
        observed = checked.value.observed;
      }
    else
      result.success {
        inherit operation;
        path = [ ];
        policy = "control";
        category = null;
        payload = value;
      };

  inspectPlan =
    plan:
    builtins.tryEval (
      let
        attrs = builtins.isAttrs plan;
        names = if attrs then builtins.attrNames plan else [ ];
        kind = if attrs && plan ? kind && builtins.isString plan.kind then plan.kind else null;
        inspected =
          if kind == "opaque" && names == [ "kind" ] then
            { kind = "opaque"; }
          else if
            kind == "category"
            &&
              names == [
                "category"
                "kind"
              ]
            && builtins.isString plan.category
            && builtins.elem plan.category categories
          then
            {
              kind = "category";
              inherit (plan) category;
            }
          else if
            kind == "list"
            &&
              names == [
                "element"
                "kind"
              ]
          then
            {
              kind = "list";
              inherit (plan) element;
            }
          else if
            kind == "attrs"
            &&
              names == [
                "fields"
                "kind"
              ]
            && builtins.isList plan.fields
          then
            {
              kind = "attrs";
              inherit (plan) fields;
            }
          else
            { kind = "invalid"; };
      in
      builtins.seq inspected.kind inspected
    );

  validateNode =
    state: depth: path: plan:
    let
      charged = budget.charge {
        operation = "validate-plan";
        inherit path depth state;
        budgetName = "plan";
        budget = budget.planSpec;
      };
    in
    if !charged.ok then
      {
        ok = false;
        inherit (charged) failure;
      }
    else
      let
        inspected = inspectPlan plan;
      in
      if !inspected.success then
        {
          ok = false;
          failure = result.hostFailure {
            operation = "validate-plan";
            inherit path;
            guardedOperation = "observation-plan-node-validation";
          };
        }
      else if inspected.value.kind == "invalid" then
        {
          ok = false;
          failure = result.mismatch {
            operation = "validate-plan";
            inherit path;
            expected = "valid-host-observation-plan-node";
            observed = "malformed-host-observation-plan-node";
          };
        }
      else if inspected.value.kind == "list" then
        let
          child = validateNode charged.state (depth + 1) (path ++ [ "element" ]) inspected.value.element;
        in
        if !child.ok then
          child
        else
          {
            ok = true;
            inherit (child) state;
            canonical = {
              kind = "list";
              element = child.canonical;
            };
          }
      else if inspected.value.kind == "attrs" then
        let
          fields = validateFields charged.state depth path 0 { } [ ] inspected.value.fields;
        in
        if !fields.ok then
          fields
        else
          {
            ok = true;
            inherit (fields) state;
            canonical = {
              kind = "attrs";
              fields = builtins.sort (left: right: builtins.lessThan left.name right.name) fields.canonical;
            };
          }
      else
        {
          ok = true;
          inherit (charged) state;
          canonical = inspected.value;
        };

  validateFields =
    state: depth: path: index: seen: canonical: fields:
    if fields == [ ] then
      {
        ok = true;
        inherit state canonical;
      }
    else
      let
        fieldPath = path ++ [ "field-spec:${toString index}" ];
        charged = budget.charge {
          operation = "validate-plan";
          path = fieldPath;
          inherit state depth;
          budgetName = "plan";
          budget = budget.planSpec;
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
                    "name"
                    "plan"
                  ]
                && builtins.isString field.name;
              name = if valid then field.name else "";
              child = if valid then field.plan else null;
            in
            builtins.seq valid (
              builtins.seq name {
                inherit valid name child;
              }
            )
          );
        in
        if !inspected.success then
          {
            ok = false;
            failure = result.hostFailure {
              operation = "validate-plan";
              path = fieldPath;
              guardedOperation = "observation-plan-field-validation";
            };
          }
        else if !inspected.value.valid || builtins.hasAttr inspected.value.name seen then
          {
            ok = false;
            failure = result.mismatch {
              operation = "validate-plan";
              path = fieldPath;
              expected = "unique-host-observation-field";
              observed = "malformed-or-duplicate-field";
            };
          }
        else
          let
            child = validateNode charged.state (depth + 1) (
              path ++ [ "field:${inspected.value.name}" ]
            ) inspected.value.child;
          in
          if !child.ok then
            child
          else
            validateFields child.state depth path (index + 1) (seen // { "${inspected.value.name}" = true; }) (
              [
                {
                  name = inspected.value.name;
                  plan = child.canonical;
                }
              ]
              ++ canonical
            ) (builtins.tail fields);
in
{
  inherit categories policies;

  isCategory = category: builtins.isString category && builtins.elem category categories;
  fromHost =
    category: if builtins.hasAttr category hostCategories then hostCategories.${category} else null;

  validatePolicy = policy: guardedChoice "validate-policy" "known-forcing-policy" policies policy;
  validateCategory =
    category: guardedChoice "validate-category" "known-host-category" categories category;

  validatePlan =
    plan:
    let
      validated = validateNode { consumed = 0; } 0 [ ] plan;
    in
    if !validated.ok then
      validated.failure
    else
      result.success {
        operation = "validate-plan";
        path = [ ];
        policy = "typed-deep";
        category = null;
        payload = validated.canonical;
      };
}
