{
  config,
  pkgs,
  ...
}:
let
  root = config.devenv.root;
  runNu = file: "nu ${root}/ci/${file}";
in
{
  packages = with pkgs; [
    deadnix
    nix-unit
    nixfmt
    nushell
    statix
    taplo
    treefmt
  ];

  scripts = {
    axiom-fmt = {
      exec = runNu "fmt.nu";
      description = "format the repository";
    };
    axiom-check = {
      exec = "devenv tasks run check:all";
      description = "run fast formatting and lint checks";
    };
    axiom-test = {
      exec = "devenv tasks run test:unit";
      description = "run every semantic test with nix-unit";
    };
    axiom-gate = {
      exec = "devenv tasks run gate:all";
      description = "run the full gate used by CI";
    };
    axiom-measure = {
      exec = "devenv tasks run measure:operations";
      description = "count executed language operations over the baseline ladder";
    };
    axiom-mutate = {
      exec = "devenv tasks run measure:mutations";
      description = "run the kernel mutation registry and fail when a mutation survives";
    };
  };

  git-hooks.hooks = {
    formatting = {
      enable = true;
      entry = "devenv shell -- ${runNu "fmt.nu"} --check";
      pass_filenames = false;
    };
    statix = {
      enable = true;
      entry = "devenv shell -- ${runNu "lint.nu statix"}";
      pass_filenames = false;
    };
    deadnix = {
      enable = true;
      entry = "devenv shell -- ${runNu "lint.nu deadnix"}";
      pass_filenames = false;
    };
    check-added-large-files = {
      enable = true;
      args = [ "--maxkb=1024" ];
    };
    commit-message = {
      enable = true;
      entry = "devenv shell -- ${runNu "commit-msg.nu"}";
      stages = [ "commit-msg" ];
    };
  };

  tasks = {
    "check:fmt" = {
      exec = runNu "fmt.nu --check";
      cwd = root;
    };
    "check:statix" = {
      exec = runNu "lint.nu statix";
      cwd = root;
    };
    "check:deadnix" = {
      exec = runNu "lint.nu deadnix";
      cwd = root;
    };
    "check:all".after = [
      "check:fmt"
      "check:statix"
      "check:deadnix"
    ];
    "test:unit" = {
      exec = runNu "unit.nu";
      cwd = root;
    };
    "measure:operations" = {
      exec = runNu "measure.nu operations";
      cwd = root;
    };
    "measure:mutations" = {
      exec = runNu "measure.nu mutations";
      cwd = root;
    };
    "gate:all".after = [
      "check:all"
      "test:unit"
    ];
  };

  enterShell = ''
    echo "axiom dev shell. Commands: axiom-fmt axiom-check axiom-test axiom-gate axiom-measure axiom-mutate"
  '';

  enterTest = ''
    devenv tasks run gate:all
  '';
}
