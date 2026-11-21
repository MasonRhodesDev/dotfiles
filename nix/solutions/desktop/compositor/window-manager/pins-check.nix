{ lib, pkgs }:
let
  pins = import ./pins.nix { inherit lib; };

  hex = digit: lib.concatStrings (lib.genList (_: digit) 40);
  entry = copr: fingerprint: ''    "${copr}  ${fingerprint}"'';
  array = entries: [ "COPR_KEYS=(" ] ++ entries ++ [ ")" ];
  twoCoprs = array [ (entry "owner/one" (hex "A")) (entry "owner/two" (hex "B")) ];
  installer = { variables ? [ ''KEY_FPR="${hex "C"}"'' ], coprs ? twoCoprs }: lib.concatStringsSep "\n" (
    [ "#!/bin/bash" ''KEY_URL="https://keys.example.invalid/repo.asc"'' ''REPO_URL="https://repo.example.invalid/x86_64"'' ]
    ++ variables
    ++ [ "cat >> /etc/pacman.conf <<EOF" "[fixture]" "SigLevel = Required DatabaseRequired" "EOF" ]
    ++ coprs
    ++ [ ''for entry in "''${COPR_KEYS[@]}"; do :; done'' "" ]
  );

  copr = project: fingerprint: {
    url = "https://download.copr.fedorainfracloud.org/results/owner/${project}/fedora-$releasever-$basearch/";
    key = { url = "https://download.copr.fedorainfracloud.org/results/owner/${project}/pubkey.gpg"; inherit fingerprint; };
  };
  want = {
    arch.fixture = { url = "https://repo.example.invalid/x86_64"; key = { url = "https://keys.example.invalid/repo.asc"; fingerprint = hex "C"; }; };
    fedora = {
      "copr:copr.fedorainfracloud.org:owner:one" = copr "one" (hex "A");
      "copr:copr.fedorainfracloud.org:owner:two" = copr "two" (hex "B");
    };
  };
  read = pins.parse (installer { });

  refused = value: !(builtins.tryEval (builtins.deepSeq value value)).success;
  refuses = coprs: refused (pins.parse (installer { inherit coprs; }));
  unapproved = ((import ./default.nix).linux.root { inherit lib; inputs.hypr-de = ./pins-fixture; }).repositories;

  moved = change: pins.digest (lib.recursiveUpdate want change) != pins.digest want;

  cases = {
    "an installer is read into its repositories, URLs and fingerprints" = read == want;
    "a COPR entry whose fingerprint is a digit short is refused, not dropped" =
      refuses (array [ (entry "owner/one" (hex "A")) (entry "owner/two" (lib.substring 1 39 (hex "B"))) ]);
    "a COPR entry with a lower-case fingerprint is refused, not dropped" =
      refuses (array [ (entry "owner/one" (hex "A")) (entry "owner/two" (hex "b")) ]);
    "a COPR listed twice is refused" =
      refuses (array [ (entry "owner/one" (hex "A")) (entry "owner/one" (hex "B")) ]);
    "a second COPR_KEYS array is refused" = refuses (twoCoprs ++ array [ (entry "owner/three" (hex "D")) ]);
    "a COPR_KEYS array that never closes is refused" = refuses (lib.init twoCoprs);
    "an entry outside the COPR_KEYS array is not read" =
      (pins.parse (installer { coprs = [ (entry "owner/stray" (hex "D")) ] ++ twoCoprs; })) == want;
    "an installer with no COPR_KEYS array is refused" = refuses [ ];
    "a second KEY_FPR is refused" = refused (pins.parse (installer { variables = [ ''KEY_FPR="${hex "C"}"'' ''KEY_FPR="${hex "D"}"'' ]; }));
    "a missing KEY_FPR is refused" = refused (pins.parse (installer { variables = [ ]; }));

    "the approved digest lets the set through" = pins.approved (pins.digest want) read == want;
    "any other digest is refused" = refused (pins.approved (hex "0") read);
    "the stand-in installer is one the parser reads" = !refused (pins.parse (builtins.readFile ./pins-fixture/get-hypr-de.sh));
    "the solution refuses a hypr-de whose set is not the one it approves" = refused unapproved;
    "a changed Arch fingerprint moves the digest" = moved { arch.fixture.key.fingerprint = hex "D"; };
    "a changed Arch key URL moves the digest" = moved { arch.fixture.key.url = "https://keys.example.invalid/other.asc"; };
    "a changed repository URL moves the digest" = moved { arch.fixture.url = "https://repo.example.invalid/other"; };
    "a changed COPR fingerprint moves the digest" = moved { fedora."copr:copr.fedorainfracloud.org:owner:two".key.fingerprint = hex "D"; };
    "an added COPR moves the digest" = moved { fedora."copr:copr.fedorainfracloud.org:owner:three" = copr "three" (hex "D"); };
    "a renamed Arch repository moves the digest" = pins.digest { inherit (want) fedora; arch.renamed = want.arch.fixture; } != pins.digest want;
  };
  failures = lib.attrNames (lib.filterAttrs (_: holds: !holds) cases);
in
if failures == [ ] then pkgs.runCommand "check-window-manager-pins" { } "touch $out"
else throw "check window-manager-pins failed:\n${lib.concatMapStrings (f: "  - ${f}\n") failures}"
