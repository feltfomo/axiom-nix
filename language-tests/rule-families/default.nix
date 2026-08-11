{ core }:
let
  manifests = core.ruleFamilies;
  families = [
    "empty"
    "identity"
    "pi"
    "sigma"
    "sum"
    "unit"
    "universe"
  ];
  required = [
    "computation"
    "diagnostics"
    "elimination"
    "equality"
    "etaStatus"
    "formation"
    "introduction"
    "laws"
    "ownership"
    "semantics"
    "syntax"
  ];
  owners = [
    "checking"
    "conversion"
    "evaluation"
    "formation"
    "lawEvidence"
    "levels"
    "quotation"
    "readback"
    "scope"
    "syntax"
  ];
  exact =
    name:
    builtins.attrNames manifests.${name} == builtins.sort builtins.lessThan (
      required
      ++ (
        if name == "identity" then
          [
            "binderOrder"
            "excluded"
            "rejectedSyntax"
          ]
        else
          [ ]
      )
    );
  typed =
    name:
    let
      row = manifests.${name};
    in
    builtins.isList row.syntax
    && builtins.isString row.formation
    && builtins.isList row.introduction
    && builtins.isList row.elimination
    && builtins.isList row.computation
    && builtins.isList row.equality
    && builtins.isString row.etaStatus
    && builtins.isList row.semantics
    && builtins.isString row.diagnostics
    && builtins.isList row.laws
    && builtins.attrNames row.ownership == owners
    && builtins.all (
      owner: builtins.isString row.ownership.${owner} && row.ownership.${owner} != ""
    ) owners;
  cases = {
    inventory = builtins.attrNames manifests == families;
    durableSchema = builtins.all exact families && builtins.all typed families;
    implementedOwners = builtins.all (
      name:
      manifests.${name}.ownership.checking == "private kernel"
      && manifests.${name}.ownership.conversion == "private kernel"
      && manifests.${name}.ownership.readback == "private kernel"
    ) families;
    admittedEta =
      manifests.pi.etaStatus == "extensional eta"
      && manifests.sigma.etaStatus == "surjective-pair eta"
      && manifests.unit.etaStatus == "typed uniqueness";
    rejectedEta =
      manifests.sum.etaStatus == "none"
      && manifests.empty.etaStatus == "none"
      && manifests.identity.etaStatus == "none";
    generalJ =
      manifests.identity.binderOrder.motive == [
        "source"
        "target"
        "evidence"
      ]
      && manifests.identity.binderOrder.reflBranch == [ "witness" ];
    descriptiveOnly = !(manifests ? evaluate) && !(manifests ? traverse) && !(manifests ? check);
  };
  failed = builtins.filter (name: !cases.${name}) (builtins.attrNames cases);
in
{
  inherit cases;
  ok =
    if failed == [ ] then
      true
    else
      throw "axiom rule family tests FAILED: ${builtins.concatStringsSep ", " failed}";
}
