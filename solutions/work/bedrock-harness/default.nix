{
  name = "Bedrock harness aliases";
  description = "claude-bedrock, codex-bedrock, pi-bedrock against the work Bedrock catalog. The inference profile ARNs come from the machine's private.bedrock, rendered into ~/.config/bedrock-aliases.env.";
  platforms = [ "linux" "darwin" ];
  requires = [ "aws" ];

  home = { lib, machine, ... }: {
    home.file.".bashrc.d/bedrock-aliases.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./bedrock-aliases.bashrc; };

    dotfiles.mutable.".config/bedrock-aliases.env" = lib.mkIf (machine.private ? bedrock) {
      strategy = "overwrite";
      mode = "0600";
      text = lib.concatStrings (lib.mapAttrsToList (key: arn: "${key}=${lib.escapeShellArg arn}\n") machine.private.bedrock);
    };

    dotfiles.credentials."aws/sso-bedrock" = {
      description = "AWS SSO session of the bedrock-developer profile that claude-bedrock, codex-bedrock and pi-bedrock use.";
      to = "bedrock-harness";
      deliver.login = "aws sso login --profile bedrock-developer";
      probe = "aws sts get-caller-identity --profile bedrock-developer";
    };
  };
}
