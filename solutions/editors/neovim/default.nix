{
  name = "Neovim";
  description = "Neovim config, EDITOR/VISUAL via nvim-open.";
  platforms = [ "linux" "darwin" ];

  home = { pkgs, lib, machine, ... }: {
    home.packages = [ pkgs.neovim ];
    home.file.".config/nvim" = { source = ./nvim; recursive = true; };
    home.file.".bashrc.d/nvim.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./nvim.bashrc; };
    home.file.".bashrc.d/editors.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./editors.bashrc; };
    home.file."scripts/nvim-open" = { source = ./nvim-open; executable = true; };
  };
}
