{ pkgs }:
{
  program = report: runtime: pkgs.writeShellScriptBin "dotfiles-credential" ''
    exec ${pkgs.python3}/bin/python3 -I ${./credential.py} ${pkgs.writeText "credentials-report.json" (builtins.toJSON report)} ${if runtime == null then "-" else pkgs.writeText "credentials-runtime.json" (builtins.toJSON runtime)} "$@"
  '';

  audit = program: pkgs.writeShellScript "dotfiles-secrets" ''exec ${program}/bin/dotfiles-credential audit "$@"'';
}
