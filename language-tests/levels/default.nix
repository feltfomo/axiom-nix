{ core }:
let
  inherit (core) levels representation;
  z = representation.levelZero;
  s = representation.levelSuc;
  m = representation.levelMax;
  values = [
    z
    (s z)
    (s (s z))
    (s (s (s z)))
  ];
  triples = builtins.concatLists (
    map (a: builtins.concatLists (map (b: map (c: { inherit a b c; }) values) values)) values
  );
  poison = throw "level input poison was forced";
  exactCombinedNodes = levels.normalizeInput {
    value = z;
    consumed = 255;
    depth = 1;
  };
  overCombinedNodes = levels.normalizeInput {
    value = poison;
    consumed = 256;
    depth = 1;
  };
  exactCombinedDepth = levels.normalizeInput {
    value = z;
    consumed = 0;
    depth = 64;
  };
  overCombinedDepth = levels.normalizeInput {
    value = poison;
    consumed = 0;
    depth = 65;
  };
  sharedUniverses = core.operations.admitted (
    representation.envelope 0 (representation.pair (representation.universe z) (
      representation.universe (s z)
    )) [ ]
  );
  cases = {
    exactCombinedInputNodes = exactCombinedNodes.ok && exactCombinedNodes.consumed == 256;
    oneOverCombinedInputNodes =
      !overCombinedNodes.ok && overCombinedNodes.detail == "nodes" && overCombinedNodes.consumed == 256;
    exactCombinedInputDepth = exactCombinedDepth.ok;
    oneOverCombinedInputDepth =
      !overCombinedDepth.ok && overCombinedDepth.detail == "depth" && overCombinedDepth.consumed == 0;
    multipleUniversesShareInputBudget = sharedUniverses.ok && sharedUniverses.nodes == 6;
    normalizationStable = builtins.all (
      level:
      let
        n = levels.normalize level;
      in
      n.ok && levels.equal n.value level
    ) values;
    associativity = builtins.all (x: levels.equal (m x.a (m x.b x.c)) (m (m x.a x.b) x.c)) triples;
    commutativity = builtins.all (x: levels.equal (m x.a x.b) (m x.b x.a)) triples;
    idempotence = builtins.all (level: levels.equal (m level level) level) values;
    zero = builtins.all (level: levels.equal (m z level) level) values;
    successorMaximum = builtins.all (x: levels.equal (s (m x.a x.b)) (m (s x.a) (s x.b))) triples;
    universeSuccessor = builtins.all (
      level:
      let
        formed = levels.formation.universe level;
      in
      formed.ok && !levels.requireExact formed.value level
    ) values;
    noCumulativity = !levels.requireExact z (s z);
    outputExact =
      let
        built = levels.rebuildCanonical 64;
      in
      built.ok && built.outputConsumed == 65;
    outputOneOver =
      let
        refused = levels.rebuildCanonical 65;
      in
      !refused.ok && refused.detail == "level-output-depth";
    malformedOutputHeight = !(levels.rebuildCanonical "65").ok;
    formationLevels =
      levels.equal (levels.formation.pi (s z) (s (s z))).value (s (s z))
      && levels.equal levels.formation.unit z
      && levels.equal levels.formation.empty z;
  };
  failing = builtins.filter (name: !cases.${name}) (builtins.attrNames cases);
in
{
  inherit cases;
  ok =
    if failing == [ ] then
      true
    else
      throw "axiom level tests FAILED: ${builtins.concatStringsSep ", " failing}";
}
