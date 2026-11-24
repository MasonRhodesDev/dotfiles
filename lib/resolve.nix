{ lib, platformOf }:
catalog:
let
  inherit (catalog) nodes solutions;
  leaves = id:
    if nodes.${id}.kind == "solution" then [ id ] else lib.concatMap leaves nodes.${id}.children;
  above = id:
    let inherit (nodes.${id}) parent; in
    lib.optionals (parent != null) (above parent) ++ [ id ];
  conditions = id:
    lib.filter (c: c.when != { }) (map (node: { inherit node; inherit (nodes.${node}) when; }) (above id));
  available = system: s:
    lib.elem (platformOf system) s.platforms && (s.only == null || s.only == system);
in
{ system, traits, include ? [ ], exclude ? [ ] }:
let
  platform = platformOf system;
  unknown = lib.filter (id: !(nodes ? ${id}));
  known = lib.filter (id: nodes ? ${id});

  ruledOut = id:
    lib.concatMap
      (c: map (trait: "${c.node} has when ${trait} = ${builtins.toJSON c.when.${trait}}") (catalog.traits.mismatches traits c.when))
      (conditions id);
  applies = id: ruledOut id == [ ] && available system solutions.${id};

  why = removeAttrs
    (lib.genAttrs (lib.filter applies (lib.attrNames solutions)) conditions)
    (lib.concatMap leaves (known exclude));
  enabled = lib.attrNames why;

  direct = id:
    map (reason: "${id} named directly but not for this machine (${reason})") (ruledOut id)
    ++ lib.optional (nodes.${id}.kind == "solution" && !available system nodes.${id})
      "${id} named directly but unavailable on ${system}";

  unmet = id:
    lib.concatMap
      (requirement:
        let
          parts = lib.splitString "@" requirement;
          applies = lib.length parts == 1 || lib.last parts == platform;
        in
        lib.optional (applies && !(why ? ${lib.head parts})) "${id} requires ${requirement}, not selected")
      solutions.${id}.requires
    ++ map (other: "${id} conflicts with ${other}")
      (lib.filter (other: why ? ${other}) solutions.${id}.conflicts);
in
{
  inherit enabled why;
  errors =
    map (id: "unknown node ${id}") (unknown (include ++ exclude))
    ++ lib.concatMap direct (known include)
    ++ lib.concatMap unmet enabled;
}
