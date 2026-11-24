{ lib, options, owners, modulesPath }:
let
  hm = "${toString modulesPath}/";

  module = path:
    let
      parts = lib.splitString "/" (lib.removeSuffix ".nix" (lib.removeSuffix "/default.nix" path));
      enable = lib.attrByPath (parts ++ [ "enable" ]) null options;
      enabledBy = lib.unique (lib.concatMap (def: lib.optional (owners ? ${toString def.file}) owners.${toString def.file})
        (enable.definitionsWithLocations or [ ]));
    in
    if lib.length parts != 2 || enable == null then "home-manager's ${path} module"
    else "home-manager's ${lib.concatStringsSep "." parts}"
      + lib.optionalString (enabledBy != [ ]) " (enabled by ${lib.concatStringsSep ", " enabledBy})";

  describe = file:
    if owners ? ${file} then [ owners.${file} ]
    else if lib.elem file [ (hm + "misc/xdg.nix") (hm + "misc/xdg") (hm + "misc/xdg/default.nix") ] then [ ]
    else if lib.hasPrefix hm file then [ (module (lib.removePrefix hm file)) ]
    else [ file ];
in
rec {
  definers = option: name:
    map (def: toString def.file)
      (lib.filter (def: lib.isAttrs def.value && def.value ? ${name}) option.definitionsWithLocations);

  named = files: lib.unique (lib.concatMap describe files);
}
