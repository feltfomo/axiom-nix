{ lists }:
{
  # genericClosure retains one compact keyed state per step; callers own the state payload
  runLinear = specification: lists.last (builtins.genericClosure specification);
  run =
    {
      initial,
      terminal,
      step,
    }:
    lists.last (
      builtins.genericClosure {
        startSet = [ (initial // { key = 0; }) ];
        operator =
          current: if terminal current then [ ] else [ ((step current) // { key = current.key + 1; }) ];
      }
    );
}
