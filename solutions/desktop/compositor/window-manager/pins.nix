{ lib }:
rec {
  parse = text:
    let
      installer = lib.splitString "\n" text;
      only = what: all:
        if lib.length all == 1 then lib.head all
        else throw "window-manager: ${toString (lib.length all)} of ${what} in hypr-DE's get-hypr-de.sh, where exactly one is expected";
      one = what: re: lib.head (only what (lib.filter (m: m != null) (map (builtins.match re) installer)));

      opening = only "COPR_KEYS arrays" (lib.filter (i: lib.elemAt installer i == "COPR_KEYS=(") (lib.range 0 (lib.length installer - 1)));
      rest = lib.drop (opening + 1) installer;
      closing = lib.lists.findFirstIndex (line: line == ")") (throw "window-manager: the COPR_KEYS array in hypr-DE's get-hypr-de.sh never closes") rest;
      entry = line:
        let m = builtins.match ''[[:space:]]*"([A-Za-z0-9_.-]+)/([A-Za-z0-9_.+-]+)[[:space:]]+([0-9A-F]{40})"'' line; in
        if m != null then m
        else throw "window-manager: a COPR_KEYS line in hypr-DE's get-hypr-de.sh is not \"owner/project FINGERPRINT\": ${line}";
      copr = m:
        let owner = lib.elemAt m 0; project = lib.elemAt m 1; results = "https://download.copr.fedorainfracloud.org/results/${owner}/${project}"; in
        lib.nameValuePair "copr:copr.fedorainfracloud.org:${owner}:${project}" {
          url = "${results}/fedora-$releasever-$basearch/";
          key = { url = "${results}/pubkey.gpg"; fingerprint = lib.elemAt m 2; };
        };
      coprs = map (line: copr (entry line)) (lib.take closing rest);
    in
    {
      arch.${one "pacman repo sections" ''[[]([a-z0-9_-]+)[]]''} = {
        url = one "REPO_URL" ''REPO_URL="([^"]+)"'';
        key = { url = one "KEY_URL" ''KEY_URL="([^"]+)"''; fingerprint = one "KEY_FPR" ''KEY_FPR="([0-9A-F]{40})"''; };
      };
      fedora =
        if lib.allUnique (map (c: c.name) coprs) then lib.listToAttrs coprs
        else throw "window-manager: a COPR is listed twice in COPR_KEYS in hypr-DE's get-hypr-de.sh, so which key it pins is ambiguous";
    };

  canonical = pins: lib.concatStrings (lib.concatLists (lib.mapAttrsToList
    (family: lib.mapAttrsToList (name: r: "${family} ${name} ${r.url} ${r.key.url} ${r.key.fingerprint}\n"))
    pins));
  digest = pins: builtins.hashString "sha256" (canonical pins);

  approved = want: pins:
    if digest pins == want then pins
    else throw ''
      window-manager: hypr-DE's package repositories and signing keys are not the approved set.
      A hypr-de lock bump changed a repository, a URL or a pinned key, and each one is trusted with root package installs.
      Check every line below against hypr-DE's get-hypr-de.sh, then approve the set by putting its digest in the window-manager solution:
        ${digest pins}
      ${canonical pins}'';
}
