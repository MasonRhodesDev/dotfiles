{ pkgs, lib, home }:
let
  json = pkgs.formats.json { };
  tool = ../tools/parity-compare;

  contentOf = path: f:
    if f.source != null then f.source
    else if f.json != null then json.generate (baseNameOf path) f.json
    else pkgs.writeText (baseNameOf path) f.text;

  index = pkgs.writeText "parity-index.json" (builtins.toJSON {
    mutable = lib.mapAttrsToList
      (path: f: { inherit path; inherit (f) strategy mode; source = contentOf path f; })
      home.dotfiles.mutable;
    root = lib.concatLists (lib.mapAttrsToList
      (owner: step: lib.mapAttrsToList
        (path: f: { inherit owner path; inherit (f) mode; source = pkgs.writeText (baseNameOf path) f.text; })
        step.files)
      home.dotfiles.root);
    rootSteps = lib.attrNames home.dotfiles.root;
  });

  tree = pkgs.runCommand "home-parity-tree.tar" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 -I ${tool} --pack ${home.home.activationPackage}/home-files ${index} > $out
  '';
in
pkgs.runCommand "home-manifest" { nativeBuildInputs = [ pkgs.python3 ]; passthru = { inherit tree; }; } ''
  python3 -I ${tool} --manifest ${tree} > $out
''
