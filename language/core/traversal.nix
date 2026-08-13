{
  representation,
  levels,
  schema,
  computation,
  traversal,
}:
let
  inherit (representation) limits;
  attrs = import ../internal/attrs.nix;
  lists = import ../internal/lists.nix;
  inherit (attrs) exact;
  inherit (lists) reverse;
  failure = kind: path: detail: {
    ok = false;
    inherit kind path detail;
  };
  failed = state: result: {
    ok = false;
    failure = result // {
      inherit (state) consumed;
    };
    inherit state;
  };
  accepted = state: kind: descriptor: children: {
    ok = true;
    inherit
      state
      kind
      descriptor
      children
      ;
  };
  child = frame: field: scope: {
    node = frame.node.${field};
    inherit scope;
    depth = frame.depth + 1;
    path = frame.path ++ [ field ];
  };
  constant =
    kind:
    if kind == "unit-type" then
      representation.unitType
    else if kind == "unit" then
      representation.unit
    else
      representation.emptyType;
  inspect =
    frame: state:
    if frame.depth > limits.depth then
      failed state (failure "resource-exhaustion" frame.path "depth")
    else if state.consumed >= limits.nodes then
      # charge refusal precedes every protected node inspection
      failed state (failure "resource-exhaustion" frame.path "nodes")
    else
      let
        charged = state // {
          consumed = state.consumed + 1;
        };
        outer = builtins.tryEval (builtins.typeOf frame.node);
      in
      if !outer.success then
        failed charged (failure "host-failure" frame.path "node-outer")
      else if outer.value != "set" then
        failed charged (failure "boundary-mismatch" frame.path "node")
      else
        let
          names = builtins.attrNames frame.node;
          hasKind = builtins.elem "kind" names && frame.node ? kind;
          observedKind =
            if hasKind then
              builtins.tryEval (builtins.seq frame.node.kind frame.node.kind)
            else
              {
                success = true;
                value = null;
              };
        in
        if !hasKind then
          failed charged (failure "boundary-mismatch" frame.path "node-kind")
        else if !observedKind.success then
          failed charged (failure "host-failure" frame.path "node-control")
        else if !builtins.isString observedKind.value then
          failed charged (failure "boundary-mismatch" frame.path "node-kind")
        else
          let
            kind = observedKind.value;
            nextState = charged // {
              paths = [ frame.path ] ++ charged.paths;
            };
          in
          if kind == "variable" then
            if
              exact [ "kind" "level" ] frame.node
              && builtins.isInt frame.node.level
              && frame.node.level >= 0
              && frame.node.level < frame.scope
            then
              accepted nextState kind { inherit kind frame; } [ ]
            else
              failed charged (failure "boundary-mismatch" frame.path "variable")
          else if kind == "universe" then
            if !exact [ "kind" "level" ] frame.node then
              failed charged (failure "boundary-mismatch" frame.path "universe")
            else
              let
                # level input continues the enclosing term account while output remains independent
                normalized = levels.normalizeInput {
                  value = frame.node.level;
                  inherit (charged) consumed;
                  depth = frame.depth + 1;
                };
                normalizedState = nextState // {
                  consumed = normalized.inputConsumed or normalized.consumed;
                };
              in
              if !normalized.ok then
                failed normalizedState (failure normalized.kind (frame.path ++ [ "level" ]) normalized.detail)
              else
                accepted (nextState // { inherit (normalized) consumed; }) kind {
                  inherit kind;
                  value = representation.universe normalized.value;
                } [ ]
          else if
            builtins.elem kind [
              "unit-type"
              "unit"
              "empty-type"
            ]
          then
            if exact [ "kind" ] frame.node then
              accepted nextState kind {
                inherit kind;
                value = constant kind;
              } [ ]
            else
              failed charged (failure "boundary-mismatch" frame.path kind)
          else
            let
              entry = schema.byKind.${kind} or null;
            in
            if entry == null || !exact entry.fields frame.node then
              failed charged (failure "boundary-mismatch" frame.path "constructor")
            else
              accepted nextState kind { inherit kind entry frame; } (
                builtins.genList (
                  index:
                  let
                    field = builtins.elemAt entry.children index;
                    binder = builtins.elemAt entry.binders index;
                  in
                  child frame field (frame.scope + binder)
                ) (builtins.length entry.children)
              );
  reduce =
    onVariable:
    {
      descriptor,
      children,
      state,
    }:
    if descriptor.kind == "variable" then
      let
        mapped = builtins.tryEval (onVariable {
          inherit (descriptor.frame)
            node
            scope
            depth
            path
            ;
        });
      in
      if !mapped.success then
        failed state (failure "internal-bug" descriptor.frame.path "variable-map")
      else
        {
          ok = true;
          inherit (mapped) value;
          state = state // {
            variables = [
              {
                inherit (descriptor.frame) path;
                inherit (descriptor.frame.node) level;
              }
            ]
            ++ state.variables;
          };
        }
    else if descriptor ? value then
      {
        ok = true;
        inherit (descriptor) value;
        inherit state;
      }
    else
      let
        rebuilt = builtins.tryEval (descriptor.entry.rebuild representation children);
      in
      if !rebuilt.success then
        failed state (failure "internal-bug" descriptor.frame.path "rebuild")
      else
        {
          ok = true;
          inherit (rebuilt) value;
          inherit state;
        };
  rewrite =
    {
      root,
      scope,
      onVariable ? ({ node, ... }: representation.variable node.level),
    }:
    let
      program = traversal.fold {
        kinds = representation.termKinds;
        root = {
          inherit root scope;
          depth = 0;
          path = [ ];
          node = root;
        };
        state = {
          consumed = 0;
          paths = [ ];
          variables = [ ];
        };
        inspect = args: inspect args.frame args.state;
        reduce = args: reduce onVariable { inherit (args) descriptor children state; };
        invalidInventory = (failure "internal-bug" [ ] "traversal-inventory") // {
          consumed = 0;
        };
      };
      executed = computation.run {
        computation = program;
        reader = null;
        state = null;
      };
    in
    if executed.kind == "failure" then
      executed.failure
    else
      {
        ok = true;
        value = executed.value.value;
        inherit (executed.value.callerState) consumed;
        paths = reverse executed.value.callerState.paths;
        variables = reverse executed.value.callerState.variables;
      };
  validate =
    { root, scope }:
    rewrite {
      inherit root scope;
      onVariable = { node, ... }: representation.variable node.level;
    };
in
{
  inherit rewrite validate;
}
