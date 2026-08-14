{
  computation,
  transition,
  stack,
}:
let
  closed =
    kinds:
    builtins.length kinds == builtins.length (
      builtins.attrNames (
        builtins.listToAttrs (
          map (kind: {
            name = kind;
            value = true;
          }) kinds
        )
      )
    );
  fold =
    {
      kinds,
      root,
      state,
      inspect,
      reduce,
      invalidInventory,
    }:
    if !closed kinds then
      computation.fail invalidInventory
    else
      let
        final = transition.run {
          initial = {
            status = "running";
            instructions = stack.push {
              kind = "visit";
              frame = root;
            } stack.empty;
            values = stack.empty;
            callerState = state;
            failure = null;
          };
          terminal = current: current.status != "running";
          step =
            current:
            if stack.isEmpty current.instructions then
              current // { status = "done"; }
            else
              let
                instruction = stack.top current.instructions;
                remaining = stack.pop current.instructions;
                refuse =
                  failure: callerState:
                  current
                  // {
                    status = "refused";
                    instructions = stack.empty;
                    inherit failure callerState;
                  };
              in
              if instruction.kind == "visit" then
                let
                  inspected = inspect {
                    inherit (instruction) frame;
                    state = current.callerState;
                  };
                in
                if !inspected.ok then
                  refuse inspected.failure inspected.state
                else if !(builtins.elem inspected.kind kinds) || !(builtins.isList inspected.children) then
                  refuse invalidInventory inspected.state
                else
                  current
                  // {
                    callerState = inspected.state;
                    # children stay in declaration order and reduction follows the final child
                    instructions = stack.prependWrittenOrder (
                      map (frame: {
                        kind = "visit";
                        inherit frame;
                      }) inspected.children
                      ++ [
                        {
                          kind = "reduce";
                          nodeKind = inspected.kind;
                          inherit (inspected) descriptor;
                          remainingChildren = builtins.length inspected.children;
                          children = [ ];
                        }
                      ]
                    ) remaining;
                  }
              else if instruction.remainingChildren > 0 then
                if stack.isEmpty current.values then
                  refuse invalidInventory current.callerState
                else
                  current
                  // {
                    values = stack.pop current.values;
                    instructions = stack.push (
                      instruction
                      // {
                        remainingChildren = instruction.remainingChildren - 1;
                        children = [ (stack.top current.values) ] ++ instruction.children;
                      }
                    ) remaining;
                  }
              else
                let
                  reduced = reduce {
                    kind = instruction.nodeKind;
                    inherit (instruction) descriptor children;
                    state = current.callerState;
                  };
                in
                if !reduced.ok then
                  refuse reduced.failure reduced.state
                else
                  # successful reduction roots are WHNF-strict between transitions; caller state stays opaque
                  builtins.seq reduced.value (
                    current
                    // {
                      callerState = reduced.state;
                      values = stack.push reduced.value current.values;
                      instructions = remaining;
                    }
                  );
        };
      in
      if final.status == "refused" || stack.isEmpty final.values then
        computation.fail (if final.status == "refused" then final.failure else invalidInventory)
      else
        computation.pure {
          value = stack.top final.values;
          inherit (final) callerState;
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
      let
        builder = builtins.foldl' (
          previous: leftValue: continuation:
          previous (
            difference: rightValue:
            continuation (
              tail:
              difference (
                [
                  {
                    inherit leftValue rightValue;
                  }
                ]
                ++ tail
              )
            )
          )
        ) (continuation: continuation (tail: tail)) left;
        consumer = builder (difference: difference [ ]);
        pairs = builtins.foldl' (current: current) consumer right;
      in
      computation.traverse (pair: combine pair.leftValue pair.rightValue) pairs;
  rewrite =
    {
      kinds,
      root,
      state,
      inspect,
      rewriteNode,
      invalidInventory,
    }:
    fold {
      inherit
        kinds
        root
        state
        inspect
        invalidInventory
        ;
      reduce =
        {
          descriptor,
          children,
          state,
          ...
        }:
        rewriteNode { inherit descriptor children state; };
    };
  bounded = fold;
}
