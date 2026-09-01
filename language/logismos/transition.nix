{ stack, observer }:
let
  last = values: builtins.elemAt values (builtins.length values - 1);
  run =
    {
      initial,
      terminal,
      step,
    }:
    # one retained state per step keeps long runs off the nix call stack
    last (
      builtins.genericClosure {
        startSet = [ (initial // { key = 0; }) ];
        operator =
          current:
          if terminal current then
            [ ]
          else
            [
              (
                (observer.emit { operation = "logismos.transition.step"; } (step current))
                // {
                  key = current.key + 1;
                }
              )
            ];
      }
    );
in
{
  inherit run;

  compose =
    transitions: value: builtins.foldl' (current: transition: transition current) value transitions;

  iterate = run;

  replay =
    {
      initial,
      spine,
      step,
    }:
    run {
      initial = {
        value = initial;
        # spines are newest-first in storage but the runtime stack exposes the oldest item first
        remaining = stack.fromNewestFirst spine;
      };
      terminal = state: stack.isEmpty state.remaining;
      step = state: {
        value = step state.value (stack.top state.remaining);
        remaining = stack.pop state.remaining;
      };
    };
}
