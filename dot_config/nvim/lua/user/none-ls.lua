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
      require("none-ls.diagnostics.flake8"),
      null_ls.builtins.completion.spell,
      -- ESLint formatting for ts/js/vue files
      require("none-ls.formatting.eslint_d").with({
        filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact", "vue" },
        condition = function(utils)
          return utils.root_has_file({ "eslint.config.js", ".eslintrc.js", ".eslintrc.json", ".eslintrc" })
        end,
      }),
    },
  }
end

return M
