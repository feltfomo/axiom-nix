{
  reverse = builtins.foldl' (values: value: [ value ] ++ values) [ ];
  last = values: builtins.elemAt values (builtins.length values - 1);
}
