{
  core,
  evaluation,
  representation,
  result,
  context,
}:
let
  r = core.representation;
  semantic = evaluation.representation;
  merge = supplied: representation.limits // supplied;
  initial = {
    readback = 0;
    output = 0;
    comparison = 0;
    conversion = 0;
    checking = 0;
    context = 0;
    depth = 0;
    forced = 0;
  };
  semanticFailure =
    depth: checked:
    result.internal "readback" depth (
      if checked.reason == "stale" then result.codes.staleGeneration else result.codes.malformedSemantic
    );
  charge =
    limits: budget: state: depth:
    # every recursive boundary charges before inspecting semantic payloads
    if depth > limits.depth then
      result.resource "readback" depth "depth" limits.depth depth
    else if state.${budget} >= limits.${budget} then
      result.resource "readback" depth budget limits.${budget} state.${budget}
    else
      {
        ok = true;
        state = state // {
          ${budget} = state.${budget} + 1;
          depth = if depth > state.depth then depth else state.depth;
        };
      };
  chargeAmount =
    limits: budget: state: depth: amount:
    if !builtins.isInt amount || amount < 0 then
      result.internal "readback" depth result.codes.impossibleState
    else if depth > limits.depth then
      result.resource "readback" depth "depth" limits.depth depth
    else if state.${budget} + amount > limits.${budget} then
      result.resource "readback" depth budget limits.${budget} state.${budget}
    else
      {
        ok = true;
        state = state // {
          ${budget} = state.${budget} + amount;
          depth = if depth > state.depth then depth else state.depth;
        };
      };
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
  quoteNeutral =
    limits: ctx: state: resultType: value:
    let
      inherit (ctx) depth;
      paid = charge limits "readback" state depth;
      neutral = representation.neutralShape value;
      bounded =
        if neutral.ok then
          representation.boundedNewestFirst {
            value = value.spine;
            count = value.spineCount;
            limit = limits.readback - paid.state.readback;
          }
        else
          {
            ok = false;
            reason = "malformed";
            consumed = 0;
          };
    in
    # bounded typed replay carries the semantic type through every elimination
    if !paid.ok then
      paid
    else if !neutral.ok then
      semanticFailure depth neutral
    else if value.head.level < 0 || value.head.level >= depth then
      result.internal "readback" depth result.codes.outOfScope
    else if !bounded.ok then
      if bounded.reason == "resource" then
        result.resource "readback" depth "readback" limits.readback (paid.state.readback + bounded.consumed)
      else
        result.internal "readback" depth result.codes.malformedSemantic
    else
      let
        found = context.lookup ctx value.head.level;
        head =
          if found.ok then
            emit limits (paid.state // { readback = paid.state.readback + bounded.consumed; }) depth (
              r.variable value.head.level
            )
          else
            found;
        start =
          if !head.ok then
            head
          else
            {
              ok = true;
              term = head.value;
              currentType = found.type;
              currentValue = semantic.neutral value.head.level;
              inherit (head) state;
            };
        step =
          acc: item:
          if !acc.ok then
            acc
          else
            let
              itemShape = representation.spineItemShape item;
            in
            if !itemShape.ok then
              semanticFailure depth itemShape
            else if item.kind == "application" && acc.currentType.kind == "pi" then
              let
                domain = demand limits acc.state depth acc.currentType.domain;
              in
              if !domain.ok then
                domain
              else
                let
                  argument = demand limits domain.state depth item.argument;
                in
                if !argument.ok then
                  argument
                else
                  let
                    quoted = quoteValue limits ctx argument.state domain.value argument.value;
                  in
                  if !quoted.ok then
                    quoted
                  else
                    let
                      nextType = apply limits quoted.state depth acc.currentType.codomain (
                        semantic.valueCell argument.value
                      );
                    in
                    if !nextType.ok then
                      nextType
                    else
                      let
                        emitted = emit limits nextType.state depth (r.application acc.term quoted.value);
                      in
                      if !emitted.ok then
                        emitted
                      else
                        {
                          ok = true;
                          term = emitted.value;
                          currentType = nextType.value;
                          currentValue = semantic.extendNeutral acc.currentValue item;
                          inherit (emitted) state;
                        }
            else if item.kind == "first-projection" && acc.currentType.kind == "sigma" then
              let
                domain = demand limits acc.state depth acc.currentType.domain;
              in
              if !domain.ok then
                domain
              else
                let
                  emitted = emit limits domain.state depth (r.firstProjection acc.term);
                in
                if !emitted.ok then
                  emitted
                else
                  {
                    ok = true;
                    term = emitted.value;
                    currentType = domain.value;
                    currentValue = semantic.extendNeutral acc.currentValue item;
                    inherit (emitted) state;
                  }
            else if item.kind == "second-projection" && acc.currentType.kind == "sigma" then
              let
                first = project limits acc.state depth "first" acc.currentValue;
              in
              if !first.ok then
                first
              else
                let
                  nextType = apply limits first.state depth acc.currentType.codomain (semantic.valueCell first.value);
                in
                if !nextType.ok then
                  nextType
                else
                  let
                    emitted = emit limits nextType.state depth (r.secondProjection acc.term);
                  in
                  if !emitted.ok then
                    emitted
                  else
                    {
                      ok = true;
                      term = emitted.value;
                      currentType = nextType.value;
                      currentValue = semantic.extendNeutral acc.currentValue item;
                      inherit (emitted) state;
                    }
            else if item.kind == "sum-elimination" && acc.currentType.kind == "sum-type" then
              let
                motiveCtx = extendContext limits acc.state ctx acc.currentType;
              in
              if !motiveCtx.ok then
                motiveCtx
              else
                let
                  fresh = semantic.neutral depth;
                  motiveValue = apply limits motiveCtx.state (depth + 1) item.motive (semantic.valueCell fresh);
                in
                if !motiveValue.ok then
                  motiveValue
                else
                  let
                    motiveTerm = quoteTypeAt limits motiveCtx.value motiveValue.state motiveValue.value;
                  in
                  if !motiveTerm.ok then
                    motiveTerm
                  else
                    let
                      leftType = demand limits motiveTerm.state depth acc.currentType.left;
                    in
                    if !leftType.ok then
                      leftType
                    else
                      let
                        leftCtx = extendContext limits leftType.state ctx leftType.value;
                      in
                      if !leftCtx.ok then
                        leftCtx
                      else
                        let
                          leftFresh = semantic.neutral depth;
                          leftTarget = apply limits leftCtx.state (depth + 1) item.motive (
                            semantic.valueCell (semantic.leftInjection (semantic.valueCell leftFresh))
                          );
                        in
                        if !leftTarget.ok then
                          leftTarget
                        else
                          let
                            leftValue = apply limits leftTarget.state (depth + 1) item.leftBranch (
                              semantic.valueCell leftFresh
                            );
                          in
                          if !leftValue.ok then
                            leftValue
                          else
                            let
                              leftTerm = quoteValue limits leftCtx.value leftValue.state leftTarget.value leftValue.value;
                            in
                            if !leftTerm.ok then
                              leftTerm
                            else
                              let
                                rightType = demand limits leftTerm.state depth acc.currentType.right;
                              in
                              if !rightType.ok then
                                rightType
                              else
                                let
                                  rightCtx = extendContext limits rightType.state ctx rightType.value;
                                in
                                if !rightCtx.ok then
                                  rightCtx
                                else
                                  let
                                    rightFresh = semantic.neutral depth;
                                    rightTarget = apply limits rightCtx.state (depth + 1) item.motive (
                                      semantic.valueCell (semantic.rightInjection (semantic.valueCell rightFresh))
                                    );
                                  in
                                  if !rightTarget.ok then
                                    rightTarget
                                  else
                                    let
                                      rightValue = apply limits rightTarget.state (depth + 1) item.rightBranch (
                                        semantic.valueCell rightFresh
                                      );
                                    in
                                    if !rightValue.ok then
                                      rightValue
                                    else
                                      let
                                        rightTerm = quoteValue limits rightCtx.value rightValue.state rightTarget.value rightValue.value;
                                      in
                                      if !rightTerm.ok then
                                        rightTerm
                                      else
                                        let
                                          target = apply limits rightTerm.state depth item.motive (semantic.valueCell acc.currentValue);
                                        in
                                        if !target.ok then
                                          target
                                        else
                                          let
                                            emitted = emit limits target.state depth (
                                              r.sumElimination acc.term motiveTerm.value leftTerm.value rightTerm.value
                                            );
                                          in
                                          if !emitted.ok then
                                            emitted
                                          else
                                            {
                                              ok = true;
                                              term = emitted.value;
                                              currentType = target.value;
                                              currentValue = semantic.extendNeutral acc.currentValue item;
                                              inherit (emitted) state;
                                            }
            else if item.kind == "unit-elimination" && acc.currentType.kind == "unit-type" then
              let
                motiveCtx = extendContext limits acc.state ctx semantic.unitType;
              in
              if !motiveCtx.ok then
                motiveCtx
              else
                let
                  fresh = semantic.neutral depth;
                  motiveValue = apply limits motiveCtx.state (depth + 1) item.motive (semantic.valueCell fresh);
                in
                if !motiveValue.ok then
                  motiveValue
                else
                  let
                    motiveTerm = quoteTypeAt limits motiveCtx.value motiveValue.state motiveValue.value;
                  in
                  if !motiveTerm.ok then
                    motiveTerm
                  else
                    let
                      caseType = apply limits motiveTerm.state depth item.motive (semantic.valueCell semantic.unit);
                    in
                    if !caseType.ok then
                      caseType
                    else
                      let
                        caseValue = demand limits caseType.state depth item.case;
                      in
                      if !caseValue.ok then
                        caseValue
                      else
                        let
                          caseTerm = quoteValue limits ctx caseValue.state caseType.value caseValue.value;
                        in
                        if !caseTerm.ok then
                          caseTerm
                        else
                          let
                            target = apply limits caseTerm.state depth item.motive (semantic.valueCell acc.currentValue);
                          in
                          if !target.ok then
                            target
                          else
                            let
                              emitted = emit limits target.state depth (
                                r.unitElimination acc.term motiveTerm.value caseTerm.value
                              );
                            in
                            if !emitted.ok then
                              emitted
                            else
                              {
                                ok = true;
                                term = emitted.value;
                                currentType = target.value;
                                currentValue = semantic.extendNeutral acc.currentValue item;
                                inherit (emitted) state;
                              }
            else if item.kind == "empty-elimination" && acc.currentType.kind == "empty-type" then
              let
                motiveCtx = extendContext limits acc.state ctx semantic.emptyType;
              in
              if !motiveCtx.ok then
                motiveCtx
              else
                let
                  fresh = semantic.neutral depth;
                  motiveValue = apply limits motiveCtx.state (depth + 1) item.motive (semantic.valueCell fresh);
                in
                if !motiveValue.ok then
                  motiveValue
                else
                  let
                    motiveTerm = quoteTypeAt limits motiveCtx.value motiveValue.state motiveValue.value;
                  in
                  if !motiveTerm.ok then
                    motiveTerm
                  else
                    let
                      target = apply limits motiveTerm.state depth item.motive (semantic.valueCell acc.currentValue);
                    in
                    if !target.ok then
                      target
                    else
                      let
                        emitted = emit limits target.state depth (r.emptyElimination acc.term motiveTerm.value);
                      in
                      if !emitted.ok then
                        emitted
                      else
                        {
                          ok = true;
                          term = emitted.value;
                          currentType = target.value;
                          currentValue = semantic.extendNeutral acc.currentValue item;
                          inherit (emitted) state;
                        }
            else if item.kind == "identity-elimination" && acc.currentType.kind == "identity-type" then
              let
                carrier = demand limits acc.state depth acc.currentType.carrier;
              in
              if !carrier.ok then
                carrier
              else
                let
                  sourceCtx = extendContext limits carrier.state ctx carrier.value;
                in
                if !sourceCtx.ok then
                  sourceCtx
                else
                  let
                    targetCtx = extendContext limits sourceCtx.state sourceCtx.value carrier.value;
                  in
                  if !targetCtx.ok then
                    targetCtx
                  else
                    let
                      sourceFresh = semantic.neutral depth;
                      targetFresh = semantic.neutral (depth + 1);
                      evidenceType =
                        semantic.identityType (semantic.valueCell carrier.value) (semantic.valueCell sourceFresh)
                          (semantic.valueCell targetFresh);
                      motiveCtx = extendContext limits targetCtx.state targetCtx.value evidenceType;
                    in
                    if !motiveCtx.ok then
                      motiveCtx
                    else
                      let
                        evidenceFresh = semantic.neutral (depth + 2);
                        motiveValue = applyMany limits motiveCtx.state (depth + 3) item.motive [
                          (semantic.valueCell sourceFresh)
                          (semantic.valueCell targetFresh)
                          (semantic.valueCell evidenceFresh)
                        ];
                      in
                      if !motiveValue.ok then
                        motiveValue
                      else
                        let
                          motiveTerm = quoteTypeAt limits motiveCtx.value motiveValue.state motiveValue.value;
                        in
                        if !motiveTerm.ok then
                          motiveTerm
                        else
                          let
                            witnessCtx = extendContext limits motiveTerm.state ctx carrier.value;
                          in
                          if !witnessCtx.ok then
                            witnessCtx
                          else
                            let
                              witness = semantic.neutral depth;
                              branchTarget = applyMany limits witnessCtx.state (depth + 1) item.motive [
                                (semantic.valueCell witness)
                                (semantic.valueCell witness)
                                (semantic.valueCell (semantic.refl (semantic.valueCell witness)))
                              ];
                            in
                            if !branchTarget.ok then
                              branchTarget
                            else
                              let
                                branchValue = apply limits branchTarget.state (depth + 1) item.reflBranch (
                                  semantic.valueCell witness
                                );
                              in
                              if !branchValue.ok then
                                branchValue
                              else
                                let
                                  branchTerm =
                                    quoteValue limits witnessCtx.value branchValue.state branchTarget.value
                                      branchValue.value;
                                in
                                if !branchTerm.ok then
                                  branchTerm
                                else
                                  let
                                    left = demand limits branchTerm.state depth acc.currentType.left;
                                  in
                                  if !left.ok then
                                    left
                                  else
                                    let
                                      right = demand limits left.state depth acc.currentType.right;
                                    in
                                    if !right.ok then
                                      right
                                    else
                                      let
                                        target = applyMany limits right.state depth item.motive [
                                          (semantic.valueCell left.value)
                                          (semantic.valueCell right.value)
                                          (semantic.valueCell acc.currentValue)
                                        ];
                                      in
                                      if !target.ok then
                                        target
                                      else
                                        let
                                          emitted = emit limits target.state depth (
                                            r.identityElimination acc.term motiveTerm.value branchTerm.value
                                          );
                                        in
                                        if !emitted.ok then
                                          emitted
                                        else
                                          {
                                            ok = true;
                                            term = emitted.value;
                                            currentType = target.value;
                                            currentValue = semantic.extendNeutral acc.currentValue item;
                                            inherit (emitted) state;
                                          }
            else
              result.internal "readback" depth result.codes.impossibleState;
        replayed = if !start.ok then start else builtins.foldl' step start bounded.values;
      in
      if !replayed.ok then
        replayed
      else
        {
          ok = true;
          value = replayed.term;
          inherit (replayed) state;
          type = resultType;
        };
  quoteTypeAt =
    limits: ctx: state: value:
    let
      paid = charge limits "readback" state ctx.depth;
    in
    if !paid.ok then
      paid
    else
      let
        checked = representation.semanticShape value;
      in
      if !checked.ok then
        semanticFailure ctx.depth checked
      else if value.kind == "universe" then
        let
          normalized = core.levels.normalize value.level;
        in
        if !normalized.ok then
          result.internal "readback" ctx.depth result.codes.malformedSemantic
        else
          let
            levelOutput = chargeAmount limits "output" paid.state ctx.depth normalized.outputConsumed;
          in
          if !levelOutput.ok then
            levelOutput
          else
            emit limits levelOutput.state ctx.depth (r.universe normalized.value)
      else if value.kind == "unit-type" then
        emit limits paid.state ctx.depth r.unitType
      else if value.kind == "empty-type" then
        emit limits paid.state ctx.depth r.emptyType
      else if value.kind == "sum-type" then
        let
          a = demand limits paid.state ctx.depth value.left;
        in
        if !a.ok then
          a
        else
          let
            qa = quoteTypeAt limits ctx a.state a.value;
          in
          if !qa.ok then
            qa
          else
            let
              b = demand limits qa.state ctx.depth value.right;
            in
            if !b.ok then
              b
            else
              let
                qb = quoteTypeAt limits ctx b.state b.value;
              in
              if !qb.ok then qb else emit limits qb.state ctx.depth (r.sumType qa.value qb.value)
      else if value.kind == "pi" || value.kind == "sigma" then
        let
          domain = demand limits paid.state ctx.depth value.domain;
        in
        if !domain.ok then
          domain
        else
          let
            qd = quoteTypeAt limits ctx domain.state domain.value;
          in
          if !qd.ok then
            qd
          else
            let
              extended = extendContext limits qd.state ctx domain.value;
            in
            if !extended.ok then
              extended
            else
              # closure readback enters only after installing neutral at the current depth
              let
                body = apply limits extended.state (ctx.depth + 1) value.codomain (
                  semantic.valueCell (semantic.neutral ctx.depth)
                );
              in
              if !body.ok then
                body
              else
                let
                  qb = quoteTypeAt limits extended.value body.state body.value;
                in
                if !qb.ok then
                  qb
                else
                  emit limits qb.state ctx.depth ((if value.kind == "pi" then r.pi else r.sigma) qd.value qb.value)
      else if value.kind == "identity-type" then
        let
          carrier = demand limits paid.state ctx.depth value.carrier;
        in
        if !carrier.ok then
          carrier
        else
          let
            qc = quoteTypeAt limits ctx carrier.state carrier.value;
          in
          if !qc.ok then
            qc
          else
            let
              left = demand limits qc.state ctx.depth value.left;
            in
            if !left.ok then
              left
            else
              let
                ql = quoteValue limits ctx left.state carrier.value left.value;
              in
              if !ql.ok then
                ql
              else
                let
                  right = demand limits ql.state ctx.depth value.right;
                in
                if !right.ok then
                  right
                else
                  let
                    qr = quoteValue limits ctx right.state carrier.value right.value;
                  in
                  if !qr.ok then qr else emit limits qr.state ctx.depth (r.identityType qc.value ql.value qr.value)
      else if value.kind == "neutral" then
        quoteNeutral limits ctx paid.state (semantic.universe core.levels.zero) value
      else
        result.internal "readback" ctx.depth result.codes.expectedType;
  quoteValue =
    limits: ctx: state: type: value:
    let
      paid = charge limits "readback" state ctx.depth;
      typeChecked = representation.semanticShape type;
      valueChecked = representation.semanticShape value;
    in
    if !paid.ok then
      paid
    else if !typeChecked.ok then
      semanticFailure ctx.depth typeChecked
    else if !valueChecked.ok then
      semanticFailure ctx.depth valueChecked
    else if type.kind == "universe" then
      quoteTypeAt limits ctx paid.state value
    else if type.kind == "pi" then
      let
        domain = demand limits paid.state ctx.depth type.domain;
      in
      if !domain.ok then
        domain
      else
        let
          extended = extendContext limits domain.state ctx domain.value;
        in
        if !extended.ok then
          extended
        else
          # function eta uses the one fresh neutral selected by the absolute context depth
          let
            body = apply limits extended.state (ctx.depth + 1) value (
              semantic.valueCell (semantic.neutral ctx.depth)
            );
          in
          if !body.ok then
            body
          else
            let
              codomain = apply limits body.state (ctx.depth + 1) type.codomain (
                semantic.valueCell (semantic.neutral ctx.depth)
              );
            in
            if !codomain.ok then
              codomain
            else
              let
                quoted = quoteValue limits extended.value codomain.state codomain.value body.value;
              in
              if !quoted.ok then quoted else emit limits quoted.state ctx.depth (r.lambda quoted.value)
    else if type.kind == "sigma" then
      # pair eta deliberately demands both projections only at the known sigma type
      let
        first = project limits paid.state ctx.depth "first" value;
      in
      if !first.ok then
        first
      else
        let
          qf = demand limits first.state ctx.depth type.domain;
        in
        if !qf.ok then
          qf
        else
          let
            firstTerm = quoteValue limits ctx qf.state qf.value first.value;
          in
          if !firstTerm.ok then
            firstTerm
          else
            let
              codomain = apply limits firstTerm.state ctx.depth type.codomain (semantic.valueCell first.value);
            in
            if !codomain.ok then
              codomain
            else
              let
                second = project limits codomain.state ctx.depth "second" value;
              in
              if !second.ok then
                second
              else
                let
                  secondTerm = quoteValue limits ctx second.state codomain.value second.value;
                in
                if !secondTerm.ok then
                  secondTerm
                else
                  emit limits secondTerm.state ctx.depth (r.pair firstTerm.value secondTerm.value)
    else if type.kind == "unit-type" then
      emit limits paid.state ctx.depth r.unit
    else if type.kind == "sum-type" && value.kind == "left-injection" then
      let
        side = demand limits paid.state ctx.depth type.left;
      in
      if !side.ok then
        side
      else
        let
          payload = demand limits side.state ctx.depth value.value;
        in
        if !payload.ok then
          payload
        else
          let
            quoted = quoteValue limits ctx payload.state side.value payload.value;
          in
          if !quoted.ok then quoted else emit limits quoted.state ctx.depth (r.leftInjection quoted.value)
    else if type.kind == "sum-type" && value.kind == "right-injection" then
      let
        side = demand limits paid.state ctx.depth type.right;
      in
      if !side.ok then
        side
      else
        let
          payload = demand limits side.state ctx.depth value.value;
        in
        if !payload.ok then
          payload
        else
          let
            quoted = quoteValue limits ctx payload.state side.value payload.value;
          in
          if !quoted.ok then quoted else emit limits quoted.state ctx.depth (r.rightInjection quoted.value)
    else if type.kind == "identity-type" && value.kind == "refl" then
      let
        carrier = demand limits paid.state ctx.depth type.carrier;
      in
      if !carrier.ok then
        carrier
      else
        let
          witness = demand limits carrier.state ctx.depth value.value;
        in
        if !witness.ok then
          witness
        else
          let
            quoted = quoteValue limits ctx witness.state carrier.value witness.value;
          in
          if !quoted.ok then quoted else emit limits quoted.state ctx.depth (r.refl quoted.value)
    else if value.kind == "neutral" then
      quoteNeutral limits ctx paid.state type value
    else
      result.internal "readback" ctx.depth result.codes.malformedSemantic;
  finish =
    kind: limits: ctx: computed:
    if !computed.ok then
      computed
    else
      let
        envelope = r.envelope ctx.depth computed.value [ ];
        admitted = core.operations.admitted envelope;
      in
      if !admitted.ok then
        result.internal kind ctx.depth result.codes.impossibleState
      else if kind == "readback" then
        result.readback {
          inherit (admitted) value;
          resources = representation.resources computed.state;
        }
      else
        result.quotation {
          inherit (admitted) value;
          resources = representation.resources computed.state;
        };
  quoteAt =
    {
      contextValue,
      type,
      value,
      state,
      limits,
    }:
    if !context.validate contextValue then
      result.internal "readback" 0 result.codes.malformedContext
    else
      quoteValue limits contextValue state type value;
  quote =
    {
      contextValue,
      type,
      value,
      limits ? { },
    }:
    let
      bounded = merge limits;
      quoted = quoteAt {
        inherit contextValue type value;
        limits = bounded;
        state = initial;
      };
    in
    finish "readback" bounded contextValue quoted;
  quoteType =
    {
      contextValue,
      value,
      limits ? { },
    }:
    let
      bounded = merge limits;
    in
    if !context.validate contextValue then
      result.internal "quotation" 0 result.codes.malformedContext
    else
      finish "quotation" bounded contextValue (quoteTypeAt bounded contextValue initial value);
  normalize =
    {
      contextValue,
      type,
      value,
      limits ? { },
    }:
    quote {
      inherit
        contextValue
        type
        value
        limits
        ;
    };
in
{
  inherit
    quote
    quoteAt
    quoteType
    normalize
    demand
    apply
    applyMany
    project
    quoteValue
    quoteTypeAt
    chargeAmount
    extendContext
    initial
    merge
    ;
}
