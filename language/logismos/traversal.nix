{ computation, transition }:
let
  reverse = builtins.foldl' (values: value: [ value ] ++ values) [ ];
  exactHandlers =
    kinds: handlers: builtins.attrNames handlers == builtins.sort builtins.lessThan kinds;
  take = count: values: builtins.genList (index: builtins.elemAt values index) count;
  drop =
    count: values:
    builtins.genList (index: builtins.elemAt values (index + count)) (builtins.length values - count);

  fold =
    {
      kinds,
      handlers,
      root,
      limit,
      refusal,
    }:
    if !exactHandlers kinds handlers then
      computation.fail refusal
    else
      let
        final = transition.run {
          initial = {
            status = "running";
            instructions = [
              {
                kind = "visit";
                node = root;
              }
            ];
            values = [ ];
            consumed = 0;
            failure = null;
          };
          terminal = state: state.status != "running";
          step =
            state:
            if state.instructions == [ ] then
              state // { status = "done"; }
            else
              let
                instruction = builtins.head state.instructions;
                remaining = builtins.tail state.instructions;
              in
              if instruction.kind == "visit" then
                # refusal happens before the protected node is read
                if state.consumed >= limit then
                  state
                  // {
                    status = "refused";
                    failure = refusal;
                    instructions = [ ];
                  }
                else
                  let
                    inherit (instruction) node;
                    admitted = builtins.elem node.kind kinds;
                    inherit (node) children;
                  in
                  if !admitted then
                    state
                    // {
                      status = "refused";
                      failure = refusal;
                      instructions = [ ];
                    }
                  else
                    state
                    // {
                      consumed = state.consumed + 1;
                      # children keep declaration order and reduce only after the last child
                      instructions =
                        map (child: {
                          kind = "visit";
                          node = child;
                        }) children
                        ++ [
                          {
                            kind = "reduce";
                            inherit node;
                            childCount = builtins.length children;
                          }
                        ]
                        ++ remaining;
                    }
              else
                let
                  newestChildren = take instruction.childCount state.values;
                  olderValues = drop instruction.childCount state.values;
                  value = handlers.${instruction.node.kind} instruction.node (reverse newestChildren);
                in
                state
                // {
                  values = [ value ] ++ olderValues;
                  instructions = remaining;
                };
        };
      in
      if final.status == "refused" then
        computation.fail final.failure
      else
        computation.pure {
          value = builtins.head final.values;
          inherit (final) consumed;
        };
in
{
  inherit fold;

  zipFold =
    {
      left,
      right,
      mismatch,
      combine,
    }:
    if builtins.length left != builtins.length right then
      computation.fail mismatch
    else
      computation.traverse (index: combine (builtins.elemAt left index) (builtins.elemAt right index)) (
        builtins.genList (index: index) (builtins.length left)
      );

  rewrite =
    {
      kinds,
      root,
      limit,
      refusal,
      rewriteNode,
    }:
    fold {
      inherit
        kinds
        root
        limit
        refusal
        ;
      handlers = builtins.listToAttrs (
        map (kind: {
          name = kind;
          value = node: children: rewriteNode (node // { inherit children; });
        }) kinds
      );
    };

  bounded = fold;
}
