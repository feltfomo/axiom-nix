{ result, core }:
let
  inherit (core) representation machine operations;
  operation = "decode-core-syntax";
  exact = names: value: builtins.isAttrs value && builtins.attrNames value == names;
  mismatch =
    expected: observed: path:
    result.mismatch {
      inherit
        operation
        path
        expected
        observed
        ;
    };
  hostFailure =
    guardedOperation: path:
    result.hostFailure {
      inherit operation path guardedOperation;
    };

  decode =
    value:
    let
      envelopeControl = builtins.tryEval (
        let
          attrs = builtins.isAttrs value;
          names = if attrs then builtins.attrNames value else [ ];
          generation = if attrs && value ? generation then value.generation else null;
          scope = if attrs && value ? scope then value.scope else null;
        in
        builtins.seq attrs (
          builtins.seq names (
            builtins.seq generation (
              builtins.seq scope {
                inherit
                  attrs
                  names
                  generation
                  scope
                  ;
              }
            )
          )
        )
      );
    in
    if !envelopeControl.success then
      hostFailure "syntax-envelope-control" [ ]
    else if !envelopeControl.value.attrs then
      mismatch "syntax-envelope" (builtins.typeOf value) [ ]
    else if
      envelopeControl.value.names != [
        "generation"
        "metadata"
        "scope"
        "term"
      ]
    then
      mismatch "exact-syntax-envelope" "malformed-attrs" [ ]
    else if !builtins.isString envelopeControl.value.generation then
      mismatch "syntax-generation" (builtins.typeOf envelopeControl.value.generation) [ "generation" ]
    else if envelopeControl.value.generation != representation.generation then
      mismatch representation.generation envelopeControl.value.generation [ "generation" ]
    else if !(builtins.isInt envelopeControl.value.scope && envelopeControl.value.scope >= 0) then
      mismatch "non-negative-scope" (builtins.typeOf envelopeControl.value.scope) [ "scope" ]
    else
      let
        rewritten = machine.rewrite {
          root = value.term;
          inherit (value) scope;
        };
      in
      if !rewritten.ok then
        if rewritten.kind == "host-failure" then
          hostFailure rewritten.detail rewritten.path
        else if rewritten.kind == "resource-exhaustion" then
          result.exhausted {
            inherit operation;
            inherit (rewritten) path;
            budget = "core-syntax";
            dimension = rewritten.detail;
            limit = representation.limits.${rewritten.detail};
            inherit (rewritten) consumed;
          }
        else if rewritten.kind == "internal-bug" then
          result.internalBug {
            inherit operation;
            inherit (rewritten) path;
            code = "AXIOM-CORE-001";
            context = {
              inherit (rewritten) detail;
            };
          }
        else
          mismatch "well-scoped-core-syntax" rewritten.detail rewritten.path
      else
        let
          metadata = operations.canonicalizeMetadata {
            inherit (value) metadata;
            validPaths = rewritten.paths;
          };
        in
        if !metadata.ok then
          if metadata.kind == "host-failure" then
            hostFailure metadata.detail [ "metadata" ]
          else if metadata.kind == "resource-exhaustion" then
            result.exhausted {
              inherit operation;
              path = [ "metadata" ];
              budget = "core-syntax-${metadata.channel}";
              inherit (metadata) dimension limit consumed;
            }
          else
            mismatch "canonical-syntax-metadata" metadata.detail [ "metadata" ]
        else
          result.success {
            inherit operation;
            path = [ ];
            policy = "core-syntax";
            category = "syntax";
            payload = {
              inherit (value) scope;
              inherit (representation) generation;
              root = rewritten.value;
              inherit (metadata) metadata;
              nodes = rewritten.consumed;
            };
          };
in
{
  inherit decode;
}
