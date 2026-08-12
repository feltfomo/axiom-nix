let
  poison = throw "forced logismos poison";
in
{
  inherit poison;
  opaqueFailure = {
    family = "opaque";
    token = 17;
  };
}
