local M = {
  "nvimtools/none-ls.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvimtools/none-ls-extras.nvim",
  },
}

function M.config()
  local null_ls = require "null-ls"

  local formatting = null_ls.builtins.formatting
  local diagnostics = null_ls.builtins.diagnostics

  null_ls.setup {
    debug = false,
    sources = {
      formatting.stylua,
      formatting.black,
      -- ESLint diagnostics and code actions
      require("none-ls.diagnostics.eslint"),
      require("none-ls.code_actions.eslint"),
      diagnostics.flake8,
      null_ls.builtins.completion.spell,
    },
  }
end

return M
