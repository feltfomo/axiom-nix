{ result, core }:
let
  decoder = import ./decode.nix { inherit result core; };
in
{
  generation = core.representation.generation;
  limits = core.representation.limits;
  validate =
    value:
    let
      decoded = decoder.decode value;
    in
    if decoded.kind == "success" then
      decoded
      // {
        # canonical roots stay private so every public use re-enters decoding
        payload = {
          inherit (decoded.payload) generation scope metadata;
          nodes = decoded.payload.nodes;
        };
      }
    else
      decoded;
}
