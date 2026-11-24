{ lib, traitsFor }:
let
  inherit (builtins) readDir pathExists;

  platforms = [ "linux" "darwin" ];
  systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
  platformOf = system: lib.last (lib.splitString "-" system);

  slots = {
    "home" = null;
    "linux.home" = "linux";
    "linux.root" = "linux";
    "darwin.home" = "darwin";
    "darwin.system" = "darwin";
  };
  partsOf = raw:
    lib.filterAttrs (_: part: part != null) (lib.mapAttrs
      (slot: _: lib.attrByPath (lib.splitString "." slot) null raw)
      slots);

  metaKeys = [ "name" "description" "platforms" "only" "when" "requires" "conflicts" "fragments" "checks" ];
  groupKeys = [ "name" "description" "when" ];
  slotKeys = { linux = [ "home" "root" ]; darwin = [ "home" "system" ]; };

  problems = raw:
    let
      has = lib.flip lib.elem (raw.platforms or [ ]);
      unknown = lib.subtractLists (metaKeys ++ [ "home" ] ++ platforms) (lib.attrNames raw);
      badSlot = p: lib.subtractLists slotKeys.${p} (lib.attrNames (raw.${p} or { }));
    in
    map (k: "unknown key '${k}'") unknown
    ++ lib.concatMap (p: map (k: "unknown key '${p}.${k}'") (badSlot p)) platforms
    ++ map (k: "missing '${k}'") (lib.filter (k: !(raw ? ${k})) [ "name" "description" "platforms" ])
    ++ lib.optional (raw ? platforms && (raw.platforms == [ ] || lib.subtractLists platforms raw.platforms != [ ]))
      "platforms must be a non-empty subset of [ linux darwin ]"
    ++ lib.optional (raw ? only && !(lib.elem raw.only systems && has (platformOf raw.only)))
      "only must be one of ${toString systems} and agree with platforms"
    ++ map (p: "has a ${p} part but does not list ${p} in platforms")
      (lib.filter (p: raw ? ${p} && !has p) platforms);

  solution = { id, parent, file, raw }:
    let found = problems raw; in
    if found != [ ] then
      throw "${file}: ${lib.concatStringsSep "; " found}"
    else {
      kind = "solution";
      inherit id parent file;
      inherit (raw) name description platforms;
      only = raw.only or null;
      when = raw.when or { };
      requires = raw.requires or [ ];
      conflicts = raw.conflicts or [ ];
      fragments = raw.fragments or [ ];
      parts = partsOf raw;
      checks = raw.checks or null;
    };

  group = { id, parent, file, raw, children }:
    let unknown = lib.subtractLists groupKeys (lib.attrNames raw); in
    if unknown != [ ] then
      throw "${file}: ${lib.concatMapStringsSep "; " (k: "unknown key '${k}'") unknown}"
    else raw // {
      kind = if parent == null then "group" else "subgroup";
      inherit id parent file children;
      when = raw.when or { };
    };

  walk = dir: shown: parent:
    lib.concatLists (lib.mapAttrsToList
      (entry: type:
        let
          path = dir + "/${entry}";
          at = "${shown}/${entry}";
          isNix = type == "regular" && lib.hasSuffix ".nix" entry;
          isGroup = type == "directory" && pathExists (path + "/_group.nix");
          isSolutionDir = type == "directory" && pathExists (path + "/default.nix");
          groupId = if parent == null then entry else "${parent}.${entry}";
          kids = walk path at groupId;
        in
        if lib.hasPrefix "_" entry then [ ]
        else if isGroup then
          [ (group {
            id = groupId;
            inherit parent;
            file = "${at}/_group.nix";
            raw = import (path + "/_group.nix");
            children = map (n: n.id) (lib.filter (n: n.parent == groupId) kids);
          }) ] ++ kids
        else if parent == null then
          throw "${at}: the top level holds groups only (a directory with _group.nix)"
        else if isNix then
          [ (solution { id = lib.removeSuffix ".nix" entry; inherit parent; file = at; raw = import path; }) ]
        else if isSolutionDir then
          [ (solution { id = entry; inherit parent; file = "${at}/default.nix"; raw = import path; }) ]
        else
          throw "${at}: not a solution (.nix file or directory with default.nix) and not a group (directory with _group.nix)")
      (readDir dir));

  loadCatalog = schema: root:
    let
      traits = traitsFor schema;
      all = walk root (baseNameOf root) null;
      byId = lib.groupBy (n: n.id) all;
      duplicates = lib.attrNames (lib.filterAttrs (_: ns: lib.length ns > 1) byId);
      nodes = lib.mapAttrs (_: lib.head) byId;
      solutions = lib.filterAttrs (_: n: n.kind == "solution") nodes;
      refs = s: map (r: lib.splitString "@" r) (s.requires ++ s.conflicts);
      dangling = lib.concatLists (lib.mapAttrsToList
        (id: s: map (r: "${s.file}: '${lib.concatStringsSep "@" r}' names no solution or platform")
          (lib.filter (r: !(solutions ? ${lib.head r}) || lib.length r > 2 || (lib.length r == 2 && !lib.elem (lib.last r) platforms)) (refs s)))
        solutions);
      readers = lib.groupBy (o: o.key) (lib.concatMap (s: map (key: { inherit key; inherit (s) id file; }) s.fragments) (lib.attrValues solutions));
      sharedKeys = lib.filterAttrs (_: os: lib.length os > 1) readers;
      badWhen = lib.concatMap (n: map (problem: "${n.file}: ${problem}") (traits.whenProblems n.when)) all;
    in
    if duplicates != [ ] then throw "${baseNameOf root}: these ids are used more than once: ${toString duplicates}"
    else if dangling != [ ] then throw (lib.concatStringsSep "\n" dangling)
    else if sharedKeys != { } then
      throw (lib.concatStringsSep "\n" (lib.mapAttrsToList
        (key: os: "fragment key '${key}' is read by more than one solution: ${toString (map (o: o.file) os)}")
        sharedKeys))
    else if badWhen != [ ] then throw (lib.concatStringsSep "\n" badWhen)
    else {
      inherit nodes solutions traits;
      fragmentOwners = lib.mapAttrs (_: os: (lib.head os).id) readers;
      roots = map (n: n.id) (lib.filter (n: n.parent == null) all);
    };
in
{ inherit loadCatalog partsOf platformOf systems; }
