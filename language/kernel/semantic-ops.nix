{
  core,
  evaluation,
  representation,
  result,
  context,
  resources,
}:
let
  r = core.representation;
  semantic = evaluation.representation;
  inherit (resources) merge initial;
  semanticFailure =
    depth: checked:
    result.internal "readback" depth (
      if checked.reason == "stale" then result.codes.staleGeneration else result.codes.malformedSemantic
    );
  charge =
    limits: budget: state: depth:
    resources.charge "readback" limits budget state depth;
  chargeAmount =
    limits: budget: state: depth: amount:
    resources.chargeAmount "readback" limits budget state depth amount;
  emit =
    limits: state: depth: value:
    let
      paid = charge limits "output" state depth;
    in
    if !paid.ok then
      paid
    else
      {
        ok = true;
        inherit value;
        inherit (paid) state;
      };
  extendContext =
    limits: state: ctx: type:
    if state.context >= limits.context then
      result.resource "context" ctx.depth "context" limits.context state.context
    else
      let
        extended = context.extend ctx type;
      in
      if !extended.ok then
        extended
      else
        {
          inherit (extended) value;
          ok = true;
          state = state // {
            context = state.context + 1;
            depth = if extended.value.depth > state.depth then extended.value.depth else state.depth;
          };
        };
  evalRoot =
    environment: root:
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
      semanticFailure 0 environmentChecked
    else if !admitted.ok then
      result.internal "readback" environment.nextLevel result.codes.malformedSemantic
    else if !evaluated.ok then
      result.internal "readback" environment.nextLevel result.codes.evaluation
    else if !valueChecked.ok then
      semanticFailure environment.nextLevel valueChecked
    else
      {
        ok = true;
        inherit (evaluated) value;
      };
  demand =
    limits: state: depth: cell:
    let
      paid = charge limits "readback" state depth;
    in
    if !paid.ok then
      paid
    else
      let
        cellChecked = representation.cellShape cell;
      in
      if !cellChecked.ok then
        semanticFailure depth cellChecked
      else if cell.kind == "value" then
        let
          valueChecked = representation.semanticShape cell.value;
        in
        if !valueChecked.ok then
          semanticFailure depth valueChecked
        else
          {
            ok = true;
            inherit (cell) value;
            inherit (paid) state;
          }
      else if cell.kind == "thunk" then
        let
          forced = evalRoot cell.environment cell.term;
        in
        if !forced.ok then
          forced
        else
          {
            ok = true;
            inherit (forced) value;
            state = paid.state // {
              forced = paid.state.forced + 1;
            };
          }
      else
        result.internal "readback" depth result.codes.malformedSemantic;
  apply =
    limits: state: depth: function: argument:
    let
      paid = charge limits "readback" state depth;
    in
    if !paid.ok then
      paid
    else
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
        semanticFailure depth functionChecked
      else if !callableChecked.ok then
        semanticFailure depth callableChecked
      else if !argumentChecked.ok then
        semanticFailure depth argumentChecked
      else if function.kind == "closure" then
        let
          extended = semantic.extendEnvironment function.environment argument;
        in
        if !extended.ok then
          result.internal "readback" depth result.codes.staleGeneration
        else
          let
            value = evalRoot extended.value function.body;
          in
          if !value.ok then
            value
          else
            {
              ok = true;
              inherit (value) value;
              inherit (paid) state;
            }
      else if function.kind == "neutral" then
        {
          ok = true;
          value = semantic.extendNeutral function {
            kind = "application";
            inherit argument;
          };
          inherit (paid) state;
        }
      else
        result.internal "readback" depth result.codes.malformedSemantic;
  project =
    limits: state: depth: direction: value:
    let
      paid = charge limits "readback" state depth;
    in
    if !paid.ok then
      paid
    else
      let
        checked = representation.semanticShape value;
        projectedChecked =
          if checked.ok && checked.kind == "neutral" then representation.neutralShape value else checked;
      in
      if !checked.ok then
        semanticFailure depth checked
      else if !projectedChecked.ok then
        semanticFailure depth projectedChecked
      else if value.kind == "pair" then
        demand limits paid.state depth value.${direction}
      else if value.kind == "neutral" then
        {
          ok = true;
          value = semantic.extendNeutral value {
            kind = if direction == "first" then "first-projection" else "second-projection";
          };
          inherit (paid) state;
        }
      else
        result.internal "readback" depth result.codes.malformedSemantic;
  applyMany =
    limits: state: depth: closure: arguments:
    let
      checked = representation.closureShape closure;
      start = {
        inherit (checked) ok;
        environment = if checked.ok then closure.environment else null;
        inherit state;
      };
      entered = builtins.foldl' (
        acc: argument:
        if !acc.ok then
          acc
        else
          let
            paid = charge limits "readback" acc.state depth;
            cell = representation.cellShape argument;
          in
          if !paid.ok then
            paid
          else if !cell.ok then
            semanticFailure depth cell
          else
            let
              extended = semantic.extendEnvironment acc.environment argument;
            in
            if !extended.ok then
              result.internal "readback" depth result.codes.staleGeneration
            else
              {
                ok = true;
                environment = extended.value;
                inherit (paid) state;
              }
      ) start arguments;
    in
    if !checked.ok then
      semanticFailure depth checked
    else if !entered.ok then
      entered
    else
      let
        evaluated = evalRoot entered.environment closure.body;
      in
      if !evaluated.ok then
        evaluated
      else
        {
          ok = true;
          inherit (evaluated) value;
          inherit (entered) state;
        };
  runRoot = { root, environment }: evalRoot environment root;
in
{
  inherit
    semanticFailure
    charge
    demand
    apply
    applyMany
    project
    extendContext
    chargeAmount
    emit
    evalRoot
    runRoot
    initial
    merge
    ;
}
