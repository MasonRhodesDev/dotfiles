local M = {
  "nvimtools/none-ls.nvim",
  commit = "78111a97cebed3dfda8157af8141bf1915cfc327",
  dependencies = {
    {
      "nvim-lua/plenary.nvim",
      commit = "b9fd5226c2f76c951fc8ed5923d85e4de065e509",
    },
    {
      "nvimtools/none-ls-extras.nvim",
      commit = "fcbae66f72f8406815f38dfa1f25109edfe9e18e",
    },
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
          -- Search up the directory tree from current buffer, not just project root
          local current_file = vim.api.nvim_buf_get_name(0)
          if current_file == "" then return false end
          
          local config_files = { "eslint.config.js", ".eslintrc.js", ".eslintrc.json", ".eslintrc" }
          local found = vim.fs.find(config_files, { 
            path = vim.fn.fnamemodify(current_file, ":p:h"),
            upward = true 
          })
          return #found > 0
        end,
      }),
    },
  }
end

return M
