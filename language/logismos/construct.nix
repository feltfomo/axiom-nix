{
  observer,
  relationFactory ? {
    identity = "production";
    build = args: import ./relation.nix args;
  },
}:
let
  validFactory =
    builtins.isAttrs relationFactory
    &&
      builtins.attrNames relationFactory == [
        "build"
        "identity"
      ]
    && builtins.isFunction relationFactory.build
    && builtins.isString relationFactory.identity;
  stack = import ./stack.nix;
  computation = import ./computation.nix { inherit stack observer; };
  transition = import ./transition.nix { inherit stack observer; };
  relation =
    if validFactory then
      let
        candidate = relationFactory.build { inherit computation; };
        validRelation =
          builtins.isAttrs candidate
          &&
            builtins.attrNames candidate == [
              "dependentProduct"
              "extensional"
              "pointwise"
              "product"
              "sum"
            ]
          && builtins.all builtins.isFunction (builtins.attrValues candidate);
      in
      if validRelation then candidate else throw "invalid logismos relation implementation"
    else
      throw "invalid logismos relation factory";
  traversal = import ./traversal.nix { inherit computation transition stack; };
  budget = import ./budget.nix { inherit computation; };
  public = {
    inherit
      computation
      relation
      transition
      traversal
      budget
      ;
  };
in
{
  inherit public;
  components = { inherit computation relation transition; };
  wiring = {
    observer = observer.identity;
    relation = relationFactory.identity;
  };
}
