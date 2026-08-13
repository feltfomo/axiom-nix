{ worklist }:
{
  fold =
    {
      value,
      limit,
      initial,
      consume,
    }:
    let
      outer = builtins.tryEval (builtins.isList value);
      final =
        if !outer.success || !outer.value then
          null
        else
          # list-tail traversal is admitted only behind limit; item observation follows resource refusal
          worklist.run {
            initial = {
              status = "running";
              remaining = value;
              consumed = 0;
              accumulator = initial;
              refusal = null;
            };
            terminal = state: state.status != "running";
            step =
              state:
              let
                empty = builtins.tryEval (state.remaining == [ ]);
              in
              if !empty.success then
                state
                // {
                  status = "done";
                  refusal = "malformed-spine";
                }
              else if empty.value then
                state // { status = "done"; }
              else if state.consumed >= limit then
                state
                // {
                  status = "done";
                  refusal = "resource";
                }
              else
                let
                  observed = builtins.tryEval (
                    let
                      item = builtins.head state.remaining;
                      tail = builtins.tail state.remaining;
                    in
                    builtins.seq item (builtins.seq tail { inherit item tail; })
                  );
                  consumed =
                    if observed.success then
                      builtins.tryEval (consume state.accumulator observed.value.item)
                    else
                      { success = false; };
                in
                if !observed.success || !consumed.success then
                  state
                  // {
                    status = "done";
                    refusal = "malformed-item";
                  }
                else
                  state
                  // {
                    remaining = observed.value.tail;
                    consumed = state.consumed + 1;
                    accumulator = consumed.value;
                  };
          };
    in
    if final == null then
      {
        ok = false;
        reason = "malformed-spine";
        consumed = 0;
      }
    else if final.refusal != null then
      {
        ok = false;
        reason = final.refusal;
        inherit (final) consumed accumulator;
      }
    else
      {
        ok = true;
        inherit (final) consumed accumulator;
      };
}
