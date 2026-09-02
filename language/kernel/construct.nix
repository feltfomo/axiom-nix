{
  core,
  evaluation,
  logismos,
  observer,
  budgetFactory ? {
    identity = "production";
    build = args: import ./budget.nix args;
  },
  advanceFactory ? {
    identity = "production";
    select = _capabilities: baseAdvance: baseAdvance;
  },
}:
let
  validBudgetFactory =
    builtins.isAttrs budgetFactory
    &&
      builtins.attrNames budgetFactory == [
        "build"
        "identity"
      ]
    && builtins.isFunction budgetFactory.build
    && builtins.isString budgetFactory.identity;
  validAdvanceFactory =
    builtins.isAttrs advanceFactory
    &&
      builtins.attrNames advanceFactory == [
        "identity"
        "select"
      ]
    && builtins.isString advanceFactory.identity
    && builtins.isFunction advanceFactory.select;
  representation = import ./representation.nix { inherit evaluation; };
  result = import ./result.nix { inherit representation core; };
  budget =
    if validBudgetFactory then
      budgetFactory.build { inherit logismos representation result; }
    else
      throw "invalid kernel budget factory";
  context = import ./context.nix {
    inherit
      evaluation
      representation
      result
      budget
      logismos
      ;
  };
  semantic = import ./semantic.nix {
    inherit
      core
      evaluation
      representation
      result
      budget
      logismos
      ;
  };
  neutralTransition =
    if validAdvanceFactory then
      import ./neutral-transition.nix {
        inherit
          evaluation
          representation
          result
          context
          semantic
          budget
          logismos
          observer
          advanceFactory
          ;
      }
    else
      throw "invalid kernel transition advance factory";
  readback = import ./readback.nix {
    inherit
      core
      evaluation
      representation
      result
      context
      budget
      semantic
      neutralTransition
      logismos
      ;
  };
  conversion = import ./conversion.nix {
    inherit
      core
      evaluation
      representation
      result
      context
      readback
      semantic
      budget
      neutralTransition
      logismos
      observer
      ;
  };
  checking = import ./checking.nix {
    inherit
      core
      evaluation
      representation
      result
      context
      conversion
      semantic
      budget
      logismos
      ;
  };
  public = {
    inherit (representation) generation limits;
    inherit (checking)
      checkContext
      form
      infer
      check
      ;
    inherit (conversion) convertTypes convertTerms oracle;
    inherit (readback) quote quoteType normalize;
  };
in
{
  inherit public;
  components = {
    inherit
      budget
      conversion
      neutralTransition
      result
      ;
  };
  wiring = {
    observer = observer.identity;
    budget = budgetFactory.identity;
    transitionAdvance = advanceFactory.identity;
    core = core.representation.generation;
    evaluation = evaluation.representation.generation;
    logismos = "logismos-computation-1";
  };
}
