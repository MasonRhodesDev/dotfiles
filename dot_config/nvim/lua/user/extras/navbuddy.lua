local M = {
  "SmiteshP/nvim-navbuddy",
  commit = "a34786c77a528519f6b8a142db7609f6e387842d",
  dependencies = {
    { "SmiteshP/nvim-navic", commit = "f887d794a0f4594882814d7780980a949200a238" },
    { "MunifTanjim/nui.nvim", commit = "de740991c12411b663994b2860f1a4fd0937c130" },
  },
}

function M.config()
  local wk = require "which-key"
  wk.add {
    { "<leader>o", "<cmd>Navbuddy<cr>", desc = "Nav" },
  }

  local navbuddy = require "nvim-navbuddy"
  -- local actions = require("nvim-navbuddy.actions")
  navbuddy.setup {
    window = {
      border = "rounded",
    },
    icons = require("user.icons").kind,
    lsp = { auto_attach = true },
  }

  local opts = { noremap = true, silent = true }
  local keymap = vim.api.nvim_set_keymap

  keymap("n", "<m-s>", ":silent only | Navbuddy<cr>", opts)
  keymap("n", "<m-o>", ":silent only | Navbuddy<cr>", opts)
end

return M
