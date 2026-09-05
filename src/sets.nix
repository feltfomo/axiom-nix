{ lib }:
let
  checked =
    values:
    if builtins.isList values && lib.all builtins.isString values then
      values
    else
      throw "axiom: sets values must be a list of strings";

  index =
    values:
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = true;
      }) (checked values)
    );

  unique =
    values:
    let
      entries = lib.imap0 (position: name: {
        inherit name;
        value = position;
      }) (checked values);
      first = builtins.listToAttrs entries;
    in
    map (entry: entry.name) (builtins.filter (entry: first.${entry.name} == entry.value) entries);

  difference =
    left: right:
    let
      members = index right;
    in
    builtins.filter (name: !(builtins.hasAttr name members)) (unique left);

  intersection =
    left: right:
    let
      members = index right;
    in
    builtins.filter (name: builtins.hasAttr name members) (unique left);

  union = left: right: unique (checked left ++ checked right);
in
{
  inherit
    index
    unique
    difference
    intersection
    union
    ;
}
