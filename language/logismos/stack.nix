let
  # null is empty; immutable value/rest cells share older tails across retained states
  empty = null;
  push = value: rest: { inherit value rest; };
  isEmpty = value: value == empty;
  top = value: value.value;
  pop = value: value.rest;
  reverse = builtins.foldl' (values: value: [ value ] ++ values) [ ];
  # newest-first program lists become oldest-first runtime stacks in one linear conversion
  prependNewestFirst = values: rest: builtins.foldl' (current: value: push value current) rest values;
  prependWrittenOrder = values: rest: prependNewestFirst (reverse values) rest;
  fromNewestFirst = values: prependNewestFirst values empty;
in
{
  inherit
    empty
    isEmpty
    push
    top
    pop
    prependNewestFirst
    prependWrittenOrder
    fromNewestFirst
    ;
}
