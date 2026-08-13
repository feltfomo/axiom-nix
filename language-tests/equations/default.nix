{ core, testCases }:
let
  inherit (core) equations representation;
  structuralFields = [
    "forcing"
    "id"
    "operations"
    "owner"
    "permanentTestCaseIds"
    "resources"
  ];
  levelFields = [
    "forcing"
    "id"
    "instanceMembers"
    "owner"
    "permanentTestCaseIds"
    "resources"
  ];
  familyFields = [
    "binderOrder"
    "computation"
    "constructors"
    "elimination"
    "equality"
    "etaStatus"
    "forcing"
    "formation"
    "introduction"
    "permanentTestCaseIds"
    "rejectedLaws"
    "resources"
    "semanticOwners"
  ];
  unique =
    values:
    builtins.length values == builtins.length (
      builtins.attrNames (
        builtins.listToAttrs (
          map (value: {
            name = value;
            value = true;
          }) values
        )
      )
    );
  knownTestIds = builtins.concatLists (
    map (owner: map (name: "${owner}.${name}") (builtins.attrNames testCases.${owner})) (
      builtins.attrNames testCases
    )
  );
  structuralRows = builtins.attrValues equations.structural;
  levelRows = builtins.attrValues equations.levels;
  familyRows = builtins.attrValues equations.families;
  allRows = structuralRows ++ levelRows ++ familyRows;
  allTestIds = builtins.concatLists (map (row: row.permanentTestCaseIds) allRows);
  constructors = builtins.concatLists (map (row: row.constructors) familyRows);
  operations = builtins.concatLists (map (row: row.operations) structuralRows);
  members = builtins.concatLists (map (row: row.instanceMembers) levelRows);
  structuralIds = map (row: row.id) structuralRows;
  levelIds = map (row: row.id) levelRows;
  requiredOperations = [
    "admitted"
    "validate"
    "weaken"
    "rename"
    "substitute"
    "open"
    "close"
    "closeBinderBody"
    "openBinderBody"
    "structurallyEqual"
  ];
  requiredMembers = [
    "zero"
    "successor"
    "join"
    "height"
    "canonicalize"
    "equal"
    "requireExact"
  ];
  deduplicated =
    values:
    builtins.attrNames (
      builtins.listToAttrs (
        map (value: {
          name = value;
          value = true;
        }) values
      )
    );
  exactSetCoverage =
    references: required:
    builtins.all (value: builtins.elem value required) references
    && builtins.all (value: builtins.elem value references) required
    && deduplicated references == builtins.sort builtins.lessThan required;
  schemaSource = builtins.readFile ../../language/core/schema.nix;
  contains = needle: text: builtins.replaceStrings [ needle ] [ "" ] text != text;
  cases = {
    coreExportSet =
      builtins.attrNames core == [
        "equations"
        "levels"
        "operations"
        "representation"
        "schema"
        "traversal"
      ];
    traversalExportSet =
      builtins.attrNames core.traversal == [
        "rewrite"
        "validate"
      ];
    closedInventories =
      builtins.attrNames equations == [
        "families"
        "levels"
        "structural"
      ];
    exactStructuralRows = builtins.all (row: builtins.attrNames row == structuralFields) structuralRows;
    exactLevelRows = builtins.all (row: builtins.attrNames row == levelFields) levelRows;
    exactFamilyRows = builtins.all (row: builtins.attrNames row == familyFields) familyRows;
    constructorCoverage =
      builtins.sort builtins.lessThan constructors
      == builtins.sort builtins.lessThan representation.termKinds
      && builtins.length constructors == builtins.length representation.termKinds;
    operationSetCoverage = exactSetCoverage operations requiredOperations;
    levelSetCoverage = exactSetCoverage members requiredMembers;
    definingIds =
      unique structuralIds
      && unique levelIds
      && builtins.all (id: builtins.substring 0 3 id == "S1-") structuralIds
      && builtins.all (id: builtins.substring 0 3 id == "S2-") levelIds;
    permanentTestsNonEmpty = builtins.all (
      row:
      builtins.isList row.permanentTestCaseIds
      && row.permanentTestCaseIds != [ ]
      && builtins.all builtins.isString row.permanentTestCaseIds
    ) allRows;
    permanentTestsResolve = builtins.all (value: builtins.elem value knownTestIds) allTestIds;
    rejectedFamiliesHaveTestOwners = builtins.all (
      row:
      row.rejectedLaws == [ ]
      || builtins.any (value: builtins.elem value knownTestIds) row.permanentTestCaseIds
    ) familyRows;
    admittedEta =
      equations.families.pi.etaStatus == "extensional"
      && equations.families.sigma.etaStatus == "surjective-pair"
      && equations.families.unit.etaStatus == "typed-uniqueness";
    rejectedEta =
      equations.families.sum.etaStatus == "none"
      && equations.families.empty.etaStatus == "none"
      && equations.families.identity.etaStatus == "none";
    generalJ =
      equations.families.identity.binderOrder.motive == [
        "source"
        "target"
        "evidence"
      ]
      && equations.families.identity.binderOrder.reflBranch == [ "witness" ];
    rejectedIdentity =
      builtins.all (value: builtins.elem value equations.families.identity.rejectedLaws)
        [
          "equality reflection"
          "UIP"
          "proof irrelevance"
          "postulates"
        ];
    declarativeOnly =
      builtins.all (
        row: builtins.all builtins.isString (builtins.attrValues row.semanticOwners)
      ) familyRows
      && builtins.all (name: !(builtins.hasAttr name equations)) [
        "evaluate"
        "form"
        "infer"
        "check"
        "convert"
        "quote"
        "readback"
      ];
    schemaStructuralOnly = builtins.all (needle: !(contains needle schemaSource)) [
      "evaluate"
      "infer"
      "check"
      "convert"
      "readback"
    ];
  };
  failed = builtins.filter (name: !cases.${name}) (builtins.attrNames cases);
in
{
  inherit cases;
  ok =
    if failed == [ ] then
      true
    else
      throw "axiom equation tests FAILED: ${builtins.concatStringsSep ", " failed}";
}
