{ config, options, lib, owners, modulesPath, ... }:
let
  who = import ./who.nix { inherit lib options owners modulesPath; };
  writers = lib.mapAttrsToList (name: w: w // { inherit name; }) (import ./runtime-writers.nix);

  segmentsOf = path:
    lib.foldl'
      (done: segment:
        if segment == "" || segment == "." then done
        else if segment == ".." && done != [ ] && lib.last done != ".." then lib.init done
        else done ++ [ segment ])
      [ ]
      (lib.splitString "/" path);
  normalise = path: lib.concatStringsSep "/" (segmentsOf path);

  anywhere = lib.hasPrefix "**/";
  segmentRegex = glob: lib.replaceStrings [ "\\*" ] [ "[^/]*" ] (lib.escapeRegex glob);
  regexOf = glob: (if anywhere glob then "(.*/)?" else "") + segmentRegex (lib.removePrefix "**/" glob);
  lower = lib.toLower;
  claimOn = path: lib.findFirst (w: lib.any (glob: builtins.match (regexOf (lower glob)) (lower path) != null) (w.paths or [ ])) null writers;
  dirClaimOn = path: lib.findFirst (w: lib.elem (lower path) (map lower (w.dirs or [ ]))) null writers;

  above = segments: claim:
    let claimed = lib.splitString "/" claim; in
    !anywhere claim
    && lib.length segments < lib.length claimed
    && lib.all (i: builtins.match (segmentRegex (lower (lib.elemAt claimed i))) (lower (lib.elemAt segments i)) != null)
      (lib.range 0 (lib.length segments - 1));
  below = claimsOf: path:
    lib.filter (c: c.claims != [ ])
      (map (writer: { inherit writer; claims = lib.filter (above (segmentsOf path)) (claimsOf writer); }) writers);
  home = map (claim: "~/${claim}");

  isDir = path: let type = builtins.readFileType path; in type == "directory" || (type == "symlink" && builtins.pathExists "${path}/.");
  built = source: lib.any (c: c ? outputs || c.allOutputs or false) (lib.attrValues (builtins.getContext (toString source)));
  filesUnder = dir:
    lib.concatLists (lib.mapAttrsToList
      (name: type: if type == "directory" then map (file: "${name}/${file}") (filesUnder "${dir}/${name}") else [ name ])
      (builtins.readDir dir));

  declaredBy = name:
    let
      viaXdg = kind:
        let prefix = "${config.xdg."${kind}Home"}/"; option = options.xdg."${kind}File" or null; in
        lib.optionals (option != null && lib.hasPrefix prefix name) (who.definers option (lib.removePrefix prefix name));
      found = who.named (who.definers options.home.file name ++ lib.concatMap viaXdg [ "config" "data" "state" "cache" ]);
    in
    " by ${if found == [ ] then "a home-manager module" else lib.concatStringsSep ", " found}";

  refusal = how: path: w: "~/${path} is declared as ${how}, but ${w.why}. ${w.fix}";

  refusedLink = name: f:
    let
      target = normalise f.target;
      by = declaredBy name;
      opaque = f.text == null && built f.source;
      listable = f.text == null && !opaque && isDir (toString f.source);
      path = claimOn target;
      dir = dirClaimOn target;
      covered = lib.optionals (!f.recursive) (below (w: (w.dirs or [ ]) ++ (w.paths or [ ])) target);
      unlisted = lib.optionals (f.recursive && opaque) (below (w: w.paths or [ ]) target);
      inside = lib.concatMap
        (file:
          let w = claimOn "${target}/${file}"; in
          lib.optional (w != null && !lib.any (c: c.writer.name == w.name) covered)
            (refusal "a store link${by}, inside the directory linked at ~/${target}" "${target}/${file}" w))
        (lib.optionals listable (filesUnder (toString f.source)));
    in
    if path != null then [ (refusal "a store link${by}" target path) ]
    else if dir != null && !f.recursive then [ (refusal "one store link${by}" target dir) ]
    else
      map
        (c: "~/${target} is declared as one store link${by} and would cover ${lib.concatStringsSep ", " (home c.claims)}, but ${c.writer.why}. Link the files inside it one by one (recursive = true).")
        covered
      ++ map
        (c: "~/${target} is declared as a recursive store link${by} from a source that is built, so its files cannot be listed at evaluation, and it could hold ${lib.concatStringsSep ", " (home c.claims)}: ${c.writer.why}. Use a source directory from the repo or a flake input, or link the files one by one.")
        unlisted
      ++ inside;

  refused =
    lib.concatLists (lib.mapAttrsToList refusedLink (lib.filterAttrs (_: f: f.enable) config.home.file))
    ++ lib.concatMap
      (key: let path = normalise key; w = claimOn path; in lib.optional (w != null && w.secret or false) (refusal "dotfiles.mutable" path w))
      (lib.attrNames config.dotfiles.mutable);
in
{
  config.assertions = map (message: { assertion = false; inherit message; }) refused;
}
