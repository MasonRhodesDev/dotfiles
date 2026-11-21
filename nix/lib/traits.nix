{ lib }:
schema:
let
  show = builtins.toJSON;
  names = lib.attrNames schema;
  many = name: schema.${name}.many or false;
  oneOf = name: lib.concatMapStringsSep " " show schema.${name}.values;
  allows = name: value: lib.elem value schema.${name}.values;
  unknown = given:
    map (name: "unknown trait '${name}' (traits: ${toString names})") (lib.subtractLists names (lib.attrNames given));
  defined = given: lib.filter (name: schema ? ${name}) (lib.attrNames given);
in
{
  inherit schema;

  problems = given:
    unknown given
    ++ map (name: "missing trait '${name}' (one of ${oneOf name})")
      (lib.filter (name: !(given ? ${name} || many name || schema.${name} ? default)) names)
    ++ lib.concatMap
      (name:
        let value = given.${name}; in
        if !many name then lib.optional (!allows name value) "trait '${name}' is ${show value}, not one of ${oneOf name}"
        else if !lib.isList value then [ "trait '${name}' is ${show value}, not a list" ]
        else map (v: "trait '${name}' has ${show v}, not one of ${oneOf name}") (lib.filter (v: !allows name v) value))
      (defined given);

  fill = given:
    lib.mapAttrs (_: trait: trait.default or [ ]) (lib.filterAttrs (name: trait: trait ? default || many name) schema) // given;

  whenProblems = when:
    unknown when
    ++ lib.concatMap
      (name:
        let value = when.${name}; in
        if lib.isList value && many name then [ "when ${name} = ${show value}: ${name} is a list trait, so name one value" ]
        else if value == [ ] then [ "when ${name} = [] matches no machine" ]
        else map (v: "when ${name} = ${show v} is not one of ${oneOf name}") (lib.filter (v: !allows name v) (lib.toList value)))
      (defined when);

  mismatches = traits: when:
    lib.filter (name: !lib.any (v: lib.elem v (lib.toList traits.${name})) (lib.toList when.${name})) (lib.attrNames when);
}
