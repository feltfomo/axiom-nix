{
  exact =
    names: value:
    builtins.isAttrs value && builtins.attrNames value == builtins.sort builtins.lessThan names;
}
