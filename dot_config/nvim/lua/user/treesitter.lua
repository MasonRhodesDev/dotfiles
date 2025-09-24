local M = {
  "nvim-treesitter/nvim-treesitter",
  commit = "42fc28ba918343ebfd5565147a42a26580579482",
  lazy = false,
  priority = 900,  -- Higher priority to load before session restoration
  build = ":TSUpdate",
}

function M.config()
  require("nvim-treesitter.configs").setup {
    ensure_installed = { "lua", "markdown", "markdown_inline", "bash", "python", "typescript", "javascript", "tsx", "vue" },
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = true,  -- Enable fallback syntax highlighting
    },
    indent = { enable = true },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<C-space>",
        node_incremental = "<C-space>",
        scope_incremental = false,
        node_decremental = "<bs>",
      },
    },
  }
end

return M
