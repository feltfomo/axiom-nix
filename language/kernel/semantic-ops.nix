{
  core,
  evaluation,
  representation,
  result,
  budget,
  logismos,
}:
let
  r = core.representation;
  sem = evaluation.representation;
  inherit (logismos) computation;
  semanticFailure =
    judgment: depth: checked:
    computation.fail (
      result.internal judgment depth (
        if checked.reason == "stale" then result.codes.staleGeneration else result.codes.malformedSemantic
      )
    );
  evalRoot =
    judgment: environment: root:
    let
      environmentChecked = representation.environmentShape environment;
      admitted =
        if environmentChecked.ok then
          core.operations.admitted (r.envelope environment.nextLevel root [ ])
        else
          { ok = false; };
      evaluated =
        if admitted.ok then
          evaluation.direct.runRoot {
            inherit environment;
            root = admitted.value.root;
          }
        else
          { ok = false; };
      valueChecked =
        if evaluated.ok then
          representation.semanticShape evaluated.value
        else
          {
            ok = false;
            reason = "malformed";
          };
    in
    if !environmentChecked.ok then
      semanticFailure judgment 0 environmentChecked
    else if !admitted.ok then
      computation.fail (result.internal judgment environment.nextLevel result.codes.malformedSemantic)
    else if !evaluated.ok then
      computation.fail (result.internal judgment environment.nextLevel result.codes.evaluation)
    else if !valueChecked.ok then
      semanticFailure judgment environment.nextLevel valueChecked
    else
      computation.pure evaluated.value;
  demand =
    judgment: limits: depth: cell:
    computation.bind (budget.charge judgment limits "readback" depth) (
      _charged:
      let
        cellChecked = representation.cellShape cell;
      in
      if !cellChecked.ok then
        semanticFailure judgment depth cellChecked
      else if cell.kind == "value" then
        let
          valueChecked = representation.semanticShape cell.value;
        in
        if !valueChecked.ok then
          semanticFailure judgment depth valueChecked
        else
          computation.pure cell.value
      else if cell.kind == "thunk" then
        computation.bind (evalRoot judgment cell.environment cell.term) (
          value:
          computation.bind (computation.modify (state: state // { forced = (state.forced or 0) + 1; })) (
            _forced: computation.pure value
          )
        )
      else
        computation.fail (result.internal judgment depth result.codes.malformedSemantic)
    );
  apply =
    judgment: limits: depth: function: argument:
    computation.bind (budget.charge judgment limits "readback" depth) (
      _charged:
      let
        functionChecked = representation.semanticShape function;
        callableChecked =
          if !functionChecked.ok then
            functionChecked
          else if functionChecked.kind == "closure" then
            representation.closureShape function
          else if functionChecked.kind == "neutral" then
            representation.neutralShape function
          else
            functionChecked;
        argumentChecked = representation.cellShape argument;
      in
      if !functionChecked.ok then
        semanticFailure judgment depth functionChecked
      else if !callableChecked.ok then
        semanticFailure judgment depth callableChecked
      else if !argumentChecked.ok then
        semanticFailure judgment depth argumentChecked
      else if function.kind == "closure" then
        let
          extended = sem.extendEnvironment function.environment argument;
        in
        if !extended.ok then
          computation.fail (result.internal judgment depth result.codes.staleGeneration)
        else
          evalRoot judgment extended.value function.body
      else if function.kind == "neutral" then
        computation.pure (
          sem.extendNeutral function {
            kind = "application";
            inherit argument;
          }
        )
      else
        computation.fail (result.internal judgment depth result.codes.malformedSemantic)
    );
  project =
    judgment: limits: depth: direction: value:
    computation.bind (budget.charge judgment limits "readback" depth) (
      _charged:
      let
        checked = representation.semanticShape value;
        projectedChecked =
          if checked.ok && checked.kind == "neutral" then representation.neutralShape value else checked;
      in
      if !checked.ok then
        semanticFailure judgment depth checked
      else if !projectedChecked.ok then
        semanticFailure judgment depth projectedChecked
      else if value.kind == "pair" then
        demand judgment limits depth value.${direction}
      else if value.kind == "neutral" then
        computation.pure (
          sem.extendNeutral value {
            kind = if direction == "first" then "first-projection" else "second-projection";
          }
        )
      else
        computation.fail (result.internal judgment depth result.codes.malformedSemantic)
    );
  applyMany =
    judgment: limits: depth: closure: arguments:
    let
      checked = representation.closureShape closure;
      entered = builtins.foldl' (
        program: argument:
        computation.bind program (
          environment:
          computation.bind (budget.charge judgment limits "readback" depth) (
            _charged:
            let
              cell = representation.cellShape argument;
              extended = if cell.ok then sem.extendEnvironment environment argument else { ok = false; };
            in
            if !cell.ok then
              semanticFailure judgment depth cell
            else if !extended.ok then
              computation.fail (result.internal judgment depth result.codes.staleGeneration)
            else
              computation.pure extended.value
          )
        )
      ) (computation.pure closure.environment) arguments;
    in
    if !checked.ok then
      semanticFailure judgment depth checked
    else
      computation.bind entered (environment: evalRoot judgment environment closure.body);
  execute =
    {
      judgment,
      state,
      program,
    }:
    computation.run {
      computation = program;
      reader = { inherit judgment; };
      inherit state;
    };
  runStateful =
    args:
    let
      executed = execute args;
    in
    if executed.kind == "success" then
      {
        ok = true;
        inherit (executed) value;
        inherit (executed) state;
      }
    else
      {
        ok = false;
        inherit (executed) failure;
        inherit (executed) state;
      };
  run =
    args:
    let
      executed = runStateful args;
    in
    if executed.ok then executed else executed.failure;
in
{
  inherit
    evalRoot
    demand
    apply
    applyMany
    project
    run
    runStateful
    ;
}
