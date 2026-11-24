{
  name = "Oh My Posh";
  description = "Prompt theme engine with the bubbles theme.";
  platforms = [ "linux" "darwin" ];
  requires = [ "bash" ];

  home = { pkgs, ... }: {
    home.packages = [ pkgs.oh-my-posh ];
    home.file.".config/oh-my-posh/bubbles.omp.json".source = ./bubbles.omp.json;
    home.file.".bashrc.d/oh-my-posh.bashrc".source = ./oh-my-posh.bashrc;
  };
}
