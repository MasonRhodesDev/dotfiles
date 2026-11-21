{ lib, pkgs, private }:
let
  lock = lib.importJSON ../flake.lock;
  owner = lock.nodes.${lock.nodes.root.inputs.hypr-de}.original.owner;

  identity = import (private + "/identity.nix");
  terms =
    if lib.isList (identity.leakTerms or null) && identity.leakTerms != [ ] && lib.all (t: lib.isString t && t != "") identity.leakTerms
    then identity.leakTerms
    else throw "identity.nix in the private input needs leakTerms: a list of the names, handles, hostnames and domains that must never appear in the public tree. Without it the leak scan checks shapes only.";

  z = "";

  caught = {
    "a home directory" = { line = "cd /home/${z}quentin/notes"; };
    "a macOS home directory" = { line = "/Users/${z}quentin"; };
    "a home directory after a word character" = { line = "$ROOT/home/${z}quentin"; };
    "a home directory after a dot" = { line = "../home/${z}quentin/x"; };
    "a home directory after a dollar sign" = { line = "prefix$/home/${z}quentin"; };
    "a home directory named for the owner" = { line = "/home/${z}${owner}/x"; };
    "a name that starts with a placeholder" = { line = "/home/${z}alexander"; };
    "a home directory under a directory that ends in modules" = { line = "mymodules/home/${z}quentin"; };

    "an email address" = { line = "mail quentin@${z}corp.io today"; };
    "an email address with the owner's name" = { line = "${owner}@${z}gmail.com"; };
    "a mailbox at github.com" = { line = "quentin@${z}github.com"; };
    "a mailbox that ends in git, at github.com" = { line = "xgit@${z}github.com:org/repo"; };
    "git at a host that starts with github.com" = { line = "git@${z}github.com.evil.io:org/repo"; };
    "a host that starts with a reserved domain" = { line = "bob@${z}example.com.evil.io"; };
    "a host that ends like a reserved domain" = { line = "bob@${z}notexample.com"; };

    "a 10/8 address" = { line = "server 10.${z}20.30.40"; };
    "a 172.16/12 address" = { line = "172.${z}31.5.4"; };
    "an address next to Docker's bridge" = { line = "172.${z}17.0.2"; };
    "a 192.168/16 address" = { line = "http://192.${z}168.1.20:8080/"; };
    "a carrier-NAT address" = { line = "100.${z}101.20.30"; };
    "a link-local address" = { line = "169.${z}254.10.10"; };

    "the owner on its own" = { line = "maintained by ${owner}"; };
    "the owner in lower case" = { line = "by ${lib.toLower owner}"; };
    "the owner after a host that only ends in github.com" = { line = "https://notgithub.com/${owner}/x"; };
    "the owner as a prefix of another owner" = { line = "github:${owner}2/x"; };

    "a home directory in a file name" = { path = "srv/home/${z}quentin/notes"; };
    "an address in a file name" = { path = "hosts/192.${z}168.1.20.conf"; };
    "a private term in a file name" = { path = "machines/${lib.head terms}.nix"; };
    "a private term in a symlink name" = { link = "${lib.head terms}.conf"; to = "elsewhere"; };
    "a home directory in a symlink target" = { link = "config"; to = "/home/${z}quentin/config"; };
  }
  // lib.listToAttrs (lib.imap0
    (i: term: lib.nameValuePair "private term ${toString i}, in another case" { line = "x${lib.toUpper term}x"; })
    terms);

  clean = {
    "the placeholder homes" = { line = "/home/${z}USER/x /home/${z}alex/.config /Users/${z}fixture /home/${z}linuxbrew/.linuxbrew"; };
    "a placeholder home that ends a sentence" = { line = "The stub user lives in /home/${z}alex."; };
    "this flake's own modules/home directory" = { line = "see nix/modules/home/${z}guard.nix"; };
    "a home directory with no name" = { line = "/home/${z}$USER and /home/${z}<name>"; };
    "example mailboxes" = { line = "alex@${z}example.invalid alex@${z}work.example.org bob@${z}example.com"; };
    "an SSH remote at github.com" = { line = "git@${z}github.com:example-org/repo.git ssh://git@${z}github.com/example-org/repo"; };
    "public and loopback addresses" = { line = "127.${z}0.0.1 192.${z}0.2.10 172.${z}32.0.1 100.${z}128.0.1 8.${z}8.8.8"; };
    "Docker's default bridge address" = { line = "DNSStubListenerExtra=172.${z}17.0.1"; };
    "a version with five numbers" = { line = "10.${z}1.2.3.4"; };
    "the owner in a repository URL" = { line = "github:${owner}/x https://github.com/${owner}/x"; };
    "the owner in a lock entry" = { line = ''"owner": "${owner}",''; };
  };

  unscanned = {
    "a file it cannot read" = { line = "x"; chmod = "000 sample.txt"; };
    "a directory it cannot list" = { path = "locked/sample.txt"; chmod = "000 locked"; };
    "a name with a newline" = { path = "ok\nhidden"; };
  };

  tree = dir: c:
    (
    if c ? line then "printf '%s\\n' ${lib.escapeShellArg c.line} > ${dir}/sample.txt"
    else if c ? path then "mkdir -p \"$(dirname ${dir}/${lib.escapeShellArg c.path})\" && touch ${dir}/${lib.escapeShellArg c.path}"
    else "ln -s ${lib.escapeShellArg c.to} ${dir}/${lib.escapeShellArg c.link}")
    + lib.optionalString (c ? chmod) "\n(cd ${dir} && chmod ${c.chmod})";
  run = want: cases: lib.concatStrings (lib.mapAttrsToList
    (name: c: ''
      dir=$(mktemp -d)
      ${tree "$dir" c}
      verdict ${want} ${lib.escapeShellArg name} "$dir"
      chmod -R u+rwX "$dir"
    '')
    cases);
in
pkgs.runCommand "check-leak-scan" { } ''
  scan() { bash ${../tools/leak-scan} --owner ${lib.escapeShellArg owner} --terms ${pkgs.writeText "leak-terms" (lib.concatMapStrings (t: "${t}\n") terms)} "$1"; }
  failed=0
  verdict() {
    local want=$1 name=$2 dir=$3 status=0 output
    output=$(scan "$dir" 2>&1) || status=$?
    case $want-$status in
      caught-1 | clean-0 | unscanned-2) ;;
      *) echo "FAIL $name: want $want, scan exited $status"; echo "$output"; failed=1 ;;
    esac
  }
  ${run "caught" caught}
  ${run "clean" clean}
  ${run "unscanned" unscanned}
  [ "$failed" = 0 ]

  scan ${../.}
  touch $out
''
