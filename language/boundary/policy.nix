{
  result,
  budget,
  logismos,
}:
let
  lists = import ../internal/lists.nix;
  inherit (lists) reverse;
  inherit (logismos) computation transition traversal;
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

  validateFieldHeaders =
    {
      fields,
      state,
      depth,
      pathRev,
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
          fieldPathRev = [ "field-spec:${toString current.index}" ] ++ pathRev;
          fieldPath = reverse fieldPathRev;
        in
        if !empty.success then
          current
          // {
            status = "failed";
            failure = result.hostFailure {
              operation = "validate-plan";
              path = fieldPath;
              guardedOperation = "observation-plan-field-validation";
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
              operation = "validate-plan";
              path = fieldPath;
              budgetName = "plan";
              budget = budget.planSpec;
              state = current.usage;
              inherit depth;
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
                        "name"
                        "plan"
                      ]
                    && builtins.isString field.name;
                  name = if valid then field.name else "";
                  child = if valid then field.plan else null;
                in
                builtins.seq valid (
                  builtins.seq name (
                    builtins.seq tail {
                      inherit
                        valid
                        name
                        child
                        tail
                        ;
                    }
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
                  operation = "validate-plan";
                  path = fieldPath;
                  guardedOperation = "observation-plan-field-validation";
                };
              }
            else if !inspected.value.valid || builtins.hasAttr inspected.value.name current.seen then
              current
              // {
                status = "failed";
                usage = charged.state;
                failure = result.mismatch {
                  operation = "validate-plan";
                  path = fieldPath;
                  expected = "unique-host-observation-field";
                  observed = "malformed-or-duplicate-field";
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
                    name = inspected.value.name;
                    plan = inspected.value.child;
                  }
                ]
                ++ current.canonical;
                usage = charged.state;
              };
    };

  validateNode =
    state: plan:
    let
      folded = traversal.fold {
        kinds = [
          "attrs"
          "category"
          "list"
          "opaque"
        ];
        root = {
          inherit plan;
          depth = 0;
          pathRev = [ ];
        };
        inherit state;
        invalidInventory = result.internalBug {
          operation = "validate-plan";
          path = [ ];
          code = result.codes.unknownPlanDispatch;
          context = { };
        };
        inspect =
          { frame, state }:
          let
            path = reverse frame.pathRev;
            charged = budget.charge {
              operation = "validate-plan";
              inherit path;
              budgetName = "plan";
              budget = budget.planSpec;
              inherit state;
              inherit (frame) depth;
            };
          in
          if !charged.ok then
            {
              ok = false;
              inherit (charged) failure;
              inherit state;
            }
          else
            let
              inspected = inspectPlan frame.plan;
            in
            if !inspected.success then
              {
                ok = false;
                inherit (charged) state;
                failure = result.hostFailure {
                  operation = "validate-plan";
                  inherit path;
                  guardedOperation = "observation-plan-node-validation";
                };
              }
            else if inspected.value.kind == "invalid" then
              {
                ok = false;
                inherit (charged) state;
                failure = result.mismatch {
                  operation = "validate-plan";
                  inherit path;
                  expected = "valid-host-observation-plan-node";
                  observed = "malformed-host-observation-plan-node";
                };
              }
            else if inspected.value.kind == "list" then
              {
                ok = true;
                kind = "list";
                descriptor = { };
                children = [
                  {
                    plan = inspected.value.element;
                    depth = frame.depth + 1;
                    pathRev = [ "element" ] ++ frame.pathRev;
                  }
                ];
                inherit (charged) state;
              }
            else if inspected.value.kind == "attrs" then
              let
                fields = validateFieldHeaders {
                  inherit (inspected.value) fields;
                  inherit (charged) state;
                  inherit (frame) depth pathRev;
                };
              in
              if fields.status == "failed" then
                {
                  ok = false;
                  inherit (fields) failure;
                  state = fields.usage;
                }
              else
                {
                  ok = true;
                  kind = "attrs";
                  descriptor = {
                    names = map (field: field.name) fields.canonical;
                  };
                  children = map (field: {
                    inherit (field) plan;
                    depth = frame.depth + 1;
                    pathRev = [ "field:${field.name}" ] ++ frame.pathRev;
                  }) fields.canonical;
                  state = fields.usage;
                }
            else
              {
                ok = true;
                inherit (inspected.value) kind;
                descriptor = inspected.value;
                children = [ ];
                inherit (charged) state;
              };
        reduce =
          {
            kind,
            descriptor,
            children,
            state,
          }:
          if kind == "list" then
            {
              ok = true;
              value = {
                kind = "list";
                element = builtins.head children;
              };
              inherit state;
            }
          else if kind == "attrs" then
            let
              canonical = builtins.genList (index: {
                name = builtins.elemAt descriptor.names index;
                plan = builtins.elemAt children index;
              }) (builtins.length descriptor.names);
            in
            {
              ok = true;
              value = {
                kind = "attrs";
                fields = builtins.sort (left: right: builtins.lessThan left.name right.name) canonical;
              };
              inherit state;
            }
          else
            {
              ok = true;
              value = descriptor;
              inherit state;
            };
      };
      executed = computation.run {
        computation = folded;
        reader = null;
        state = null;
      };
    in
    if executed.kind == "failure" then
      {
        ok = false;
        inherit (executed) failure;
      }
    else
      {
        ok = true;
        canonical = executed.value.value;
        state = executed.value.callerState;
      };
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
      validated = validateNode budget.initial plan;
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
