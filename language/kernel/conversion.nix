{
  core,
  evaluation,
  representation,
  result,
  context,
  readback,
}:
let
  semantic = evaluation.representation;
  merge = supplied: representation.limits // supplied;
  inherit (readback) initial;
  charge =
    limits: state: depth:
    # semantic comparison pays before inspecting either candidate
    if depth > limits.depth then
      result.resource "conversion" depth "depth" limits.depth depth
    else if state.conversion >= limits.conversion then
      result.resource "conversion" depth "conversion" limits.conversion state.conversion
    else if state.comparison >= limits.comparison then
      result.resource "conversion" depth "comparison" limits.comparison state.comparison
    else
      {
        ok = true;
        state = state // {
          conversion = state.conversion + 1;
          comparison = state.comparison + 1;
          depth = if depth > state.depth then depth else state.depth;
        };
      };
  semanticFailure =
    depth: checked:
    result.internal "conversion" depth (
      if checked.reason == "stale" then result.codes.staleGeneration else result.codes.malformedSemantic
    );
  mismatch =
    depth: result.failure "conversion" depth result.codes.mismatch [ ] "convertible" "distinct";
  neutralCompare =
    limits: ctx: state: type: left: right:
    let
      paid = charge limits state ctx.depth;
      leftChecked = representation.neutralShape left;
      rightChecked = representation.neutralShape right;
      leftSpine =
        if leftChecked.ok then
          representation.boundedNewestFirst {
            value = left.spine;
            count = left.spineCount;
            limit = limits.comparison - paid.state.comparison;
          }
        else
          {
            ok = false;
            reason = "malformed";
            consumed = 0;
          };
      rightSpine =
        if rightChecked.ok then
          representation.boundedNewestFirst {
            value = right.spine;
            count = right.spineCount;
            limit = limits.comparison - paid.state.comparison - leftSpine.consumed;
          }
        else
          {
            ok = false;
            reason = "malformed";
            consumed = 0;
          };
    in
    if !paid.ok then
      paid
    else if !leftChecked.ok then
      semanticFailure ctx.depth leftChecked
    else if !rightChecked.ok then
      semanticFailure ctx.depth rightChecked
    else if !leftSpine.ok || !rightSpine.ok then
      if (leftSpine.reason or "") == "resource" || (rightSpine.reason or "") == "resource" then
        result.resource "conversion" ctx.depth "comparison" limits.comparison (
          paid.state.comparison + (leftSpine.consumed or 0) + (rightSpine.consumed or 0)
        )
      else
        result.internal "conversion" ctx.depth result.codes.malformedSemantic
    else if left.head.level != right.head.level then
      mismatch ctx.depth
    else
      let
        found = context.lookup ctx left.head.level;
        traversalState = paid.state // {
          comparison = paid.state.comparison + leftSpine.consumed + rightSpine.consumed;
        };
        walk =
          currentType: leftValue: rightValue: state0: as: bs:
          if as == [ ] && bs == [ ] then
            {
              ok = true;
              state = state0;
            }
          else if as == [ ] || bs == [ ] then
            mismatch ctx.depth
          else
            let
              a = builtins.head as;
              b = builtins.head bs;
              tailA = builtins.tail as;
              tailB = builtins.tail bs;
              ac = representation.spineItemShape a;
              bc = representation.spineItemShape b;
              nextLeft = semantic.extendNeutral leftValue a;
              nextRight = semantic.extendNeutral rightValue b;
            in
            if !ac.ok then
              semanticFailure ctx.depth ac
            else if !bc.ok then
              semanticFailure ctx.depth bc
            else if a.kind != b.kind then
              mismatch ctx.depth
            else if a.kind == "application" && currentType.kind == "pi" then
              let
                domain = readback.demand limits state0 ctx.depth currentType.domain;
              in
              if !domain.ok then
                domain
              else
                let
                  av = readback.demand limits domain.state ctx.depth a.argument;
                in
                if !av.ok then
                  av
                else
                  let
                    bv = readback.demand limits av.state ctx.depth b.argument;
                  in
                  if !bv.ok then
                    bv
                  else
                    let
                      same = compareValue limits ctx bv.state domain.value av.value bv.value;
                    in
                    if !same.ok then
                      same
                    else
                      let
                        nextType = readback.apply limits same.state ctx.depth currentType.codomain (
                          semantic.valueCell av.value
                        );
                      in
                      if !nextType.ok then nextType else walk nextType.value nextLeft nextRight nextType.state tailA tailB
            else if a.kind == "first-projection" && currentType.kind == "sigma" then
              let
                domain = readback.demand limits state0 ctx.depth currentType.domain;
              in
              if !domain.ok then domain else walk domain.value nextLeft nextRight domain.state tailA tailB
            else if a.kind == "second-projection" && currentType.kind == "sigma" then
              let
                first = readback.project limits state0 ctx.depth "first" leftValue;
              in
              if !first.ok then
                first
              else
                let
                  nextType = readback.apply limits first.state ctx.depth currentType.codomain (
                    semantic.valueCell first.value
                  );
                in
                if !nextType.ok then nextType else walk nextType.value nextLeft nextRight nextType.state tailA tailB
            else if a.kind == "sum-elimination" && currentType.kind == "sum-type" then
              let
                extended = readback.extendContext limits state0 ctx currentType;
              in
              if !extended.ok then
                extended
              else
                let
                  fresh = semantic.valueCell (semantic.neutral ctx.depth);
                  lm = readback.apply limits extended.state (ctx.depth + 1) a.motive fresh;
                in
                if !lm.ok then
                  lm
                else
                  let
                    rm = readback.apply limits lm.state (ctx.depth + 1) b.motive fresh;
                  in
                  if !rm.ok then
                    rm
                  else
                    let
                      motives = compareType limits extended.value rm.state lm.value rm.value;
                    in
                    if !motives.ok then
                      motives
                    else
                      let
                        leftType = readback.demand limits motives.state ctx.depth currentType.left;
                      in
                      if !leftType.ok then
                        leftType
                      else
                        let
                          leftCtx = readback.extendContext limits leftType.state ctx leftType.value;
                        in
                        if !leftCtx.ok then
                          leftCtx
                        else
                          let
                            x = semantic.neutral ctx.depth;
                            lx = semantic.valueCell x;
                            lt = readback.apply limits leftCtx.state (ctx.depth + 1) a.motive (
                              semantic.valueCell (semantic.leftInjection lx)
                            );
                          in
                          if !lt.ok then
                            lt
                          else
                            let
                              lbv = readback.apply limits lt.state (ctx.depth + 1) a.leftBranch lx;
                              rbv = if lbv.ok then readback.apply limits lbv.state (ctx.depth + 1) b.leftBranch lx else lbv;
                            in
                            if !lbv.ok then
                              lbv
                            else if !rbv.ok then
                              rbv
                            else
                              let
                                leftBranches = compareValue limits leftCtx.value rbv.state lt.value lbv.value rbv.value;
                              in
                              if !leftBranches.ok then
                                leftBranches
                              else
                                let
                                  rightType = readback.demand limits leftBranches.state ctx.depth currentType.right;
                                in
                                if !rightType.ok then
                                  rightType
                                else
                                  let
                                    rightCtx = readback.extendContext limits rightType.state ctx rightType.value;
                                  in
                                  if !rightCtx.ok then
                                    rightCtx
                                  else
                                    let
                                      y = semantic.neutral ctx.depth;
                                      ry = semantic.valueCell y;
                                      rt = readback.apply limits rightCtx.state (ctx.depth + 1) a.motive (
                                        semantic.valueCell (semantic.rightInjection ry)
                                      );
                                    in
                                    if !rt.ok then
                                      rt
                                    else
                                      let
                                        lrv = readback.apply limits rt.state (ctx.depth + 1) a.rightBranch ry;
                                        rrv = if lrv.ok then readback.apply limits lrv.state (ctx.depth + 1) b.rightBranch ry else lrv;
                                      in
                                      if !lrv.ok then
                                        lrv
                                      else if !rrv.ok then
                                        rrv
                                      else
                                        let
                                          rightBranches = compareValue limits rightCtx.value rrv.state rt.value lrv.value rrv.value;
                                        in
                                        if !rightBranches.ok then
                                          rightBranches
                                        else
                                          let
                                            target = readback.apply limits rightBranches.state ctx.depth a.motive (
                                              semantic.valueCell leftValue
                                            );
                                          in
                                          if !target.ok then target else walk target.value nextLeft nextRight target.state tailA tailB
            else if a.kind == "unit-elimination" && currentType.kind == "unit-type" then
              let
                extended = readback.extendContext limits state0 ctx semantic.unitType;
              in
              if !extended.ok then
                extended
              else
                let
                  fresh = semantic.valueCell (semantic.neutral ctx.depth);
                  lm = readback.apply limits extended.state (ctx.depth + 1) a.motive fresh;
                in
                if !lm.ok then
                  lm
                else
                  let
                    rm = readback.apply limits lm.state (ctx.depth + 1) b.motive fresh;
                  in
                  if !rm.ok then
                    rm
                  else
                    let
                      motives = compareType limits extended.value rm.state lm.value rm.value;
                    in
                    if !motives.ok then
                      motives
                    else
                      let
                        caseType = readback.apply limits motives.state ctx.depth a.motive (
                          semantic.valueCell semantic.unit
                        );
                      in
                      if !caseType.ok then
                        caseType
                      else
                        let
                          lc = readback.demand limits caseType.state ctx.depth a.case;
                          rc = if lc.ok then readback.demand limits lc.state ctx.depth b.case else lc;
                        in
                        if !lc.ok then
                          lc
                        else if !rc.ok then
                          rc
                        else
                          let
                            cases = compareValue limits ctx rc.state caseType.value lc.value rc.value;
                          in
                          if !cases.ok then
                            cases
                          else
                            let
                              target = readback.apply limits cases.state ctx.depth a.motive (semantic.valueCell leftValue);
                            in
                            if !target.ok then target else walk target.value nextLeft nextRight target.state tailA tailB
            else if a.kind == "empty-elimination" && currentType.kind == "empty-type" then
              let
                extended = readback.extendContext limits state0 ctx semantic.emptyType;
              in
              if !extended.ok then
                extended
              else
                let
                  fresh = semantic.valueCell (semantic.neutral ctx.depth);
                  lm = readback.apply limits extended.state (ctx.depth + 1) a.motive fresh;
                in
                if !lm.ok then
                  lm
                else
                  let
                    rm = readback.apply limits lm.state (ctx.depth + 1) b.motive fresh;
                  in
                  if !rm.ok then
                    rm
                  else
                    let
                      motives = compareType limits extended.value rm.state lm.value rm.value;
                    in
                    if !motives.ok then
                      motives
                    else
                      let
                        target = readback.apply limits motives.state ctx.depth a.motive (semantic.valueCell leftValue);
                      in
                      if !target.ok then target else walk target.value nextLeft nextRight target.state tailA tailB
            else if a.kind == "identity-elimination" && currentType.kind == "identity-type" then
              let
                carrier = readback.demand limits state0 ctx.depth currentType.carrier;
              in
              if !carrier.ok then
                carrier
              else
                let
                  witnessCtx = readback.extendContext limits carrier.state ctx carrier.value;
                in
                if !witnessCtx.ok then
                  witnessCtx
                else
                  let
                    witness = semantic.neutral ctx.depth;
                    args = [
                      (semantic.valueCell witness)
                      (semantic.valueCell witness)
                      (semantic.valueCell (semantic.refl (semantic.valueCell witness)))
                    ];
                    lt = readback.applyMany limits witnessCtx.state (ctx.depth + 1) a.motive args;
                  in
                  if !lt.ok then
                    lt
                  else
                    let
                      rt = readback.applyMany limits lt.state (ctx.depth + 1) b.motive args;
                    in
                    if !rt.ok then
                      rt
                    else
                      let
                        motives = compareType limits witnessCtx.value rt.state lt.value rt.value;
                      in
                      if !motives.ok then
                        motives
                      else
                        let
                          lbv = readback.apply limits motives.state (ctx.depth + 1) a.reflBranch (semantic.valueCell witness);
                          rbv =
                            if lbv.ok then
                              readback.apply limits lbv.state (ctx.depth + 1) b.reflBranch (semantic.valueCell witness)
                            else
                              lbv;
                        in
                        if !lbv.ok then
                          lbv
                        else if !rbv.ok then
                          rbv
                        else
                          let
                            branches = compareValue limits witnessCtx.value rbv.state lt.value lbv.value rbv.value;
                          in
                          if !branches.ok then
                            branches
                          else
                            let
                              leftEnd = readback.demand limits branches.state ctx.depth currentType.left;
                              rightEnd =
                                if leftEnd.ok then readback.demand limits leftEnd.state ctx.depth currentType.right else leftEnd;
                            in
                            if !leftEnd.ok then
                              leftEnd
                            else if !rightEnd.ok then
                              rightEnd
                            else
                              let
                                target = readback.applyMany limits rightEnd.state ctx.depth a.motive [
                                  (semantic.valueCell leftEnd.value)
                                  (semantic.valueCell rightEnd.value)
                                  (semantic.valueCell leftValue)
                                ];
                              in
                              if !target.ok then target else walk target.value nextLeft nextRight target.state tailA tailB
            else
              result.internal "conversion" ctx.depth result.codes.impossibleState;
      in
      if !found.ok then
        found
      else
        walk found.type (semantic.neutral left.head.level) (semantic.neutral right.head.level)
          traversalState
          leftSpine.values
          rightSpine.values;
  compareType =
    limits: ctx: state: left: right:
    let
      paid = charge limits state ctx.depth;
      lc = representation.semanticShape left;
      rc = representation.semanticShape right;
    in
    if !paid.ok then
      paid
    else if !lc.ok then
      semanticFailure ctx.depth lc
    else if !rc.ok then
      semanticFailure ctx.depth rc
    else if left.kind != right.kind then
      mismatch ctx.depth
    else if left.kind == "universe" then
      if core.levels.equal left.level right.level then
        {
          ok = true;
          inherit (paid) state;
        }
      else
        mismatch ctx.depth
    else if left.kind == "unit-type" || left.kind == "empty-type" then
      {
        ok = true;
        inherit (paid) state;
      }
    else if left.kind == "sum-type" then
      let
        la = readback.demand limits paid.state ctx.depth left.left;
      in
      if !la.ok then
        la
      else
        let
          ra = readback.demand limits la.state ctx.depth right.left;
        in
        if !ra.ok then
          ra
        else
          let
            first = compareType limits ctx ra.state la.value ra.value;
          in
          if !first.ok then
            first
          else
            let
              lb = readback.demand limits first.state ctx.depth left.right;
            in
            if !lb.ok then
              lb
            else
              let
                rb = readback.demand limits lb.state ctx.depth right.right;
              in
              if !rb.ok then rb else compareType limits ctx rb.state lb.value rb.value
    else if left.kind == "pi" || left.kind == "sigma" then
      let
        ld = readback.demand limits paid.state ctx.depth left.domain;
      in
      if !ld.ok then
        ld
      else
        let
          rd = readback.demand limits ld.state ctx.depth right.domain;
        in
        if !rd.ok then
          rd
        else
          let
            domains = compareType limits ctx rd.state ld.value rd.value;
          in
          if !domains.ok then
            domains
          else
            let
              extended = readback.extendContext limits domains.state ctx ld.value;
            in
            if !extended.ok then
              extended
            else
              let
                fresh = semantic.valueCell (semantic.neutral ctx.depth);
                lc = readback.apply limits extended.state (ctx.depth + 1) left.codomain fresh;
              in
              if !lc.ok then
                lc
              else
                let
                  rc = readback.apply limits lc.state (ctx.depth + 1) right.codomain fresh;
                in
                if !rc.ok then rc else compareType limits extended.value rc.state lc.value rc.value
    else if left.kind == "identity-type" then
      let
        lc = readback.demand limits paid.state ctx.depth left.carrier;
      in
      if !lc.ok then
        lc
      else
        let
          rc = readback.demand limits lc.state ctx.depth right.carrier;
        in
        if !rc.ok then
          rc
        else
          let
            carriers = compareType limits ctx rc.state lc.value rc.value;
          in
          if !carriers.ok then
            carriers
          else
            let
              ll = readback.demand limits carriers.state ctx.depth left.left;
            in
            if !ll.ok then
              ll
            else
              let
                rl = readback.demand limits ll.state ctx.depth right.left;
              in
              if !rl.ok then
                rl
              else
                let
                  lefts = compareValue limits ctx rl.state lc.value ll.value rl.value;
                in
                if !lefts.ok then
                  lefts
                else
                  let
                    lr = readback.demand limits lefts.state ctx.depth left.right;
                  in
                  if !lr.ok then
                    lr
                  else
                    let
                      rr = readback.demand limits lr.state ctx.depth right.right;
                    in
                    if !rr.ok then rr else compareValue limits ctx rr.state lc.value lr.value rr.value
    else if left.kind == "neutral" then
      neutralCompare limits ctx paid.state (semantic.universe core.levels.zero) left right
    else
      result.internal "conversion" ctx.depth result.codes.expectedType;
  compareValue =
    limits: ctx: state: type: left: right:
    let
      paid = charge limits state ctx.depth;
      tc = representation.semanticShape type;
      lc = representation.semanticShape left;
      rc = representation.semanticShape right;
    in
    if !paid.ok then
      paid
    else if !tc.ok then
      semanticFailure ctx.depth tc
    else if !lc.ok then
      semanticFailure ctx.depth lc
    else if !rc.ok then
      semanticFailure ctx.depth rc
    else if type.kind == "universe" then
      compareType limits ctx paid.state left right
    else if type.kind == "unit-type" then
      {
        ok = true;
        inherit (paid) state;
      }
    else if type.kind == "pi" then
      # function eta compares both candidates only after applying the same fresh neutral
      let
        domain = readback.demand limits paid.state ctx.depth type.domain;
      in
      if !domain.ok then
        domain
      else
        let
          extended = readback.extendContext limits domain.state ctx domain.value;
        in
        if !extended.ok then
          extended
        else
          let
            fresh = semantic.valueCell (semantic.neutral ctx.depth);
            lv = readback.apply limits extended.state (ctx.depth + 1) left fresh;
          in
          if !lv.ok then
            lv
          else
            let
              rv = readback.apply limits lv.state (ctx.depth + 1) right fresh;
            in
            if !rv.ok then
              rv
            else
              let
                codomain = readback.apply limits rv.state (ctx.depth + 1) type.codomain fresh;
              in
              if !codomain.ok then
                codomain
              else
                compareValue limits extended.value codomain.state codomain.value lv.value rv.value
    else if type.kind == "sigma" then
      let
        lf = readback.project limits paid.state ctx.depth "first" left;
      in
      if !lf.ok then
        lf
      else
        let
          rf = readback.project limits lf.state ctx.depth "first" right;
        in
        if !rf.ok then
          rf
        else
          let
            domain = readback.demand limits rf.state ctx.depth type.domain;
          in
          if !domain.ok then
            domain
          else
            let
              firsts = compareValue limits ctx domain.state domain.value lf.value rf.value;
            in
            if !firsts.ok then
              firsts
            else
              # the dependent second component is compared at the codomain instantiated by the first value
              let
                codomain = readback.apply limits firsts.state ctx.depth type.codomain (semantic.valueCell lf.value);
              in
              if !codomain.ok then
                codomain
              else
                let
                  ls = readback.project limits codomain.state ctx.depth "second" left;
                in
                if !ls.ok then
                  ls
                else
                  let
                    rs = readback.project limits ls.state ctx.depth "second" right;
                  in
                  if !rs.ok then rs else compareValue limits ctx rs.state codomain.value ls.value rs.value
    else if type.kind == "sum-type" then
      if left.kind != right.kind then
        mismatch ctx.depth
      else if left.kind == "left-injection" || left.kind == "right-injection" then
        let
          side =
            readback.demand limits paid.state ctx.depth
              type.${if left.kind == "left-injection" then "left" else "right"};
        in
        if !side.ok then
          side
        else
          let
            lv = readback.demand limits side.state ctx.depth left.value;
          in
          if !lv.ok then
            lv
          else
            let
              rv = readback.demand limits lv.state ctx.depth right.value;
            in
            if !rv.ok then rv else compareValue limits ctx rv.state side.value lv.value rv.value
      else if left.kind == "neutral" then
        neutralCompare limits ctx paid.state type left right
      else
        mismatch ctx.depth
    else if type.kind == "empty-type" then
      if left.kind == "neutral" && right.kind == "neutral" then
        neutralCompare limits ctx paid.state type left right
      else
        mismatch ctx.depth
    else if type.kind == "identity-type" then
      if left.kind == "refl" && right.kind == "refl" then
        let
          carrier = readback.demand limits paid.state ctx.depth type.carrier;
        in
        if !carrier.ok then
          carrier
        else
          let
            lv = readback.demand limits carrier.state ctx.depth left.value;
          in
          if !lv.ok then
            lv
          else
            let
              rv = readback.demand limits lv.state ctx.depth right.value;
            in
            if !rv.ok then rv else compareValue limits ctx rv.state carrier.value lv.value rv.value
      else if left.kind == "neutral" && right.kind == "neutral" then
        neutralCompare limits ctx paid.state type left right
      else
        mismatch ctx.depth
    else if left.kind == "neutral" && right.kind == "neutral" then
      neutralCompare limits ctx paid.state type left right
    else
      mismatch ctx.depth;
  finish =
    judgment: type: compared:
    if !compared.ok then
      compared
    else if judgment == "type-conversion" then
      result.typeConversion { resources = representation.resources compared.state; }
    else
      result.termConversion {
        inherit type;
        resources = representation.resources compared.state;
        observations = {
          forced = compared.state.forced or 0;
        };
      };
  compareTypesAt =
    {
      contextValue,
      left,
      right,
      state,
      limits,
    }:
    if !context.validate contextValue then
      result.internal "type-conversion" 0 result.codes.malformedContext
    else
      compareType limits contextValue state left right;
  compareTermsAt =
    {
      contextValue,
      type,
      left,
      right,
      state,
      limits,
    }:
    if !context.validate contextValue then
      result.internal "term-conversion" 0 result.codes.malformedContext
    else
      compareValue limits contextValue state type left right;
  convertTypes =
    {
      contextValue,
      left,
      right,
      limits ? { },
    }:
    let
      bounded = merge limits;
    in
    finish "type-conversion" null (compareTypesAt {
      inherit contextValue left right;
      limits = bounded;
      state = initial // {
        limits = bounded;
      };
    });
  convertTerms =
    {
      contextValue,
      type,
      left,
      right,
      limits ? { },
    }:
    let
      bounded = merge limits;
    in
    finish "term-conversion" type (compareTermsAt {
      inherit
        contextValue
        type
        left
        right
        ;
      limits = bounded;
      state = initial // {
        limits = bounded;
      };
    });
  oracle =
    {
      contextValue,
      type,
      left,
      right,
      limits ? { },
    }:
    let
      bounded = merge limits;
      ql = readback.quoteAt {
        inherit contextValue type;
        value = left;
        limits = bounded;
        state = initial;
      };
      qr =
        if ql.ok then
          readback.quoteAt {
            inherit contextValue type;
            value = right;
            limits = bounded;
            inherit (ql) state;
          }
        else
          ql;
      admit = value: core.operations.admitted (core.representation.envelope contextValue.depth value [ ]);
      leftCanonical = if qr.ok then admit ql.value else qr;
      rightCanonical = if leftCanonical.ok then admit qr.value else leftCanonical;
    in
    if !ql.ok then
      ql
    else if !qr.ok then
      qr
    else if !leftCanonical.ok || !rightCanonical.ok then
      result.internal "conversion-oracle" contextValue.depth result.codes.impossibleState
    else if core.operations.structurallyEqual leftCanonical.value rightCanonical.value then
      result.oracle {
        left = leftCanonical.value;
        right = rightCanonical.value;
        resources = representation.resources qr.state;
      }
    else
      mismatch contextValue.depth;
in
{
  inherit
    convertTypes
    convertTerms
    oracle
    compareType
    compareValue
    compareTypesAt
    compareTermsAt
    ;
}
