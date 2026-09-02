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
      relationFactory ? null,
      advanceFactory ? null,
    }:
    let
      logismosArguments = { inherit observer; };
      logismos = import ../../language/logismos/construct.nix (
        if relationFactory == null then
          logismosArguments
        else
          logismosArguments // { inherit relationFactory; }
      );
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
        kernelArguments
        // (if budgetFactory == null then { } else { inherit budgetFactory; })
        // (if advanceFactory == null then { } else { inherit advanceFactory; })
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
      relationFactory ? null,
      advanceFactory ? null,
    }:
    graph {
      inherit budgetFactory relationFactory advanceFactory;
      observer = observation.observed hook;
    };
  silent =
    {
      budgetFactory ? null,
      relationFactory ? null,
      advanceFactory ? null,
    }:
    graph {
      inherit budgetFactory relationFactory advanceFactory;
      observer = observation.silent;
    };
}
