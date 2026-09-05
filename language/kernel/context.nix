{
  evaluation,
  representation,
  result,
  budget,
  logismos,
}:
let
  semantic = evaluation.representation;
  semanticFailure =
    judgment: depth: checked:
    result.internal judgment depth (
      if checked.reason == "stale" then result.codes.staleGeneration else result.codes.malformedSemantic
    );
  inherit (logismos) computation;
  validate = representation.contextShape;
  empty = representation.context 0 (semantic.initialEnvironment 0) { };
  extend =
    context: type:
    if !validate context then
      result.internal "context" 0 result.codes.malformedContext
    else
      let
        typeShape = representation.semanticShape type;
      in
      if !typeShape.ok then
        semanticFailure "context" context.depth typeShape
      else if
        context.depth >= representation.limits.context || context.depth >= representation.limits.depth
      then
        result.resource "context" context.depth "context" representation.limits.context context.depth
      else
        let
          level = context.depth;
          cell = semantic.valueCell (semantic.neutral level);
          extended = semantic.extendEnvironment context.environment cell;
        in
        if !extended.ok then
          result.internal "context" context.depth result.codes.staleGeneration
        else
          let
            next = representation.context (level + 1) extended.value (
              context.entries
              // {
                ${toString level} = representation.contextEntry level type;
              }
            );
          in
          if validate next then
            {
              ok = true;
              value = next;
            }
          else
            result.internal "context" level result.codes.impossibleState;
  extendComputed =
    judgment: limits: context: type:
    # context usage belongs to trusted insertion rather than work performed under the context
    budget.protect judgment limits "insertContextEntry" context.depth (
      _charged:
      let
        extended = extend context type;
      in
      if extended.ok then computation.pure extended.value else computation.fail extended
    );
  lookup =
    context: level:
    if !validate context then
      result.internal "context" 0 result.codes.malformedContext
    else if !builtins.isInt level || level < 0 || level >= context.depth then
      result.failure "inference" context.depth result.codes.outOfScope [
        "variable"
      ] "in-scope level" "out-of-scope level"
    else
      {
        ok = true;
        type = context.entries.${toString level}.type;
      };
in
{
  inherit
    validate
    empty
    extend
    extendComputed
    lookup
    ;
}
