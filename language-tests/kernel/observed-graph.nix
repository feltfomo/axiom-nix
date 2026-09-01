# the production entry points each build their own nested subsystems, so one
# shared observed graph has to be assembled from the construction seams here.
# this is a harness, not a second production entry point.
let
  observation = import ../../language/internal/operation-observer.nix;
  tracePrefix = "AXIOM-OP";
  graph =
    {
      observer,
      budgetFactory ? null,
    }:
    let
      logismos = import ../../language/logismos/construct.nix { inherit observer; };
      core = import ../../language/core/construct.nix {
        inherit observer;
        logismos = logismos.public;
      };
      evaluation = import ../../language/evaluation/construct.nix {
        inherit observer;
        core = core.public;
        logismos = logismos.public;
      };
      kernelArguments = {
        inherit observer;
        core = core.public;
        evaluation = evaluation.public;
        logismos = logismos.public;
      };
      kernel = import ../../language/kernel/construct.nix (
        if budgetFactory == null then kernelArguments else kernelArguments // { inherit budgetFactory; }
      );
    in
    {
      inherit
        logismos
        core
        evaluation
        kernel
        ;
      observers = [
        logismos.wiring.observer
        core.wiring.observer
        evaluation.wiring.observer
        kernel.wiring.observer
      ];
    };
  # run and workload framing stays outside the operation name so the closed
  # production inventory does not grow a measurement dimension
  traceHook =
    frame: event:
    builtins.trace "${tracePrefix} ${builtins.toJSON (frame // { inherit (event) operation; })}" true;
in
{
  inherit graph traceHook tracePrefix;
  observed =
    {
      hook,
      budgetFactory ? null,
    }:
    graph {
      inherit budgetFactory;
      observer = observation.observed hook;
    };
  silent =
    {
      budgetFactory ? null,
    }:
    graph {
      inherit budgetFactory;
      observer = observation.silent;
    };
}
