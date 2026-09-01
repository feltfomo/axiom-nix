let
  operations = [
    "core.admission.attempt"
    "core.admission.node"
    "evaluation.direct.semantic-node"
    "evaluation.machine.transition"
    "logismos.computation.instruction"
    "logismos.transition.step"
    "kernel.transition.typed-neutral"
    "kernel.conversion.type"
    "kernel.conversion.term"
    "kernel.conversion.neutral"
    "kernel.conversion.oracle"
  ];
  exactEvent =
    event:
    builtins.isAttrs event
    && builtins.attrNames event == [ "operation" ]
    && builtins.isString event.operation
    && builtins.elem event.operation operations;
  silent = {
    identity = "silent";
    emit = _event: value: value;
  };
  # the hook only acknowledges an event and never receives the wrapped value, so
  # an injected hook cannot rewrite a result and cannot force a payload
  observed = hook: {
    identity = "observed";
    emit =
      event: value:
      if exactEvent event then builtins.seq (hook event) value else throw "invalid operation observation";
  };
in
{
  inherit
    operations
    exactEvent
    silent
    observed
    ;
}
