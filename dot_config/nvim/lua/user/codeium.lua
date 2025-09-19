local M = {
  "Exafunction/codeium.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "hrsh7th/nvim-cmp",
  },
  config = function()
    require("codeium").setup({
      -- Enable codeium completions
      enable_chat = false, -- We already have Claude Code for chat
    })
  end,
}

return M