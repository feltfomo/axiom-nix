let
  poison = throw "forced host-boundary poison";
  divergentCallback = value: builtins.seq value (divergentCallback value);
  recursiveList = [ recursiveList ];
  recursiveAttrs = {
    self = recursiveAttrs;
  };
  derivation = builtins.derivation {
    name = "axiom-boundary-poison";
    system = "x86_64-linux";
    builder = "/bin/false";
  };
in
{
  inherit
    poison
    divergentCallback
    recursiveList
    recursiveAttrs
    derivation
    ;
  contextString = "${derivation}";
  throwingCallback = _value: poison;
  malformedCallback = _value: "not-an-int";
  poisonedList = [
    1
    poison
  ];
  poisonedAttrs = {
    selected = 1;
    hidden = poison;
  };
}
