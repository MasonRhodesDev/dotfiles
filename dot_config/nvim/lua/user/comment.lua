local M = {
  "numToStr/Comment.nvim",
  commit = "e30b7f2008e52442154b66f7c519bfd2f1e32acb",
  lazy = false,
  dependencies = {
    {
      "JoosepAlviste/nvim-ts-context-commentstring",
      commit = "1b212c2eee76d787bbea6aa5e92a2b534e7b4f8f",
      event = "VeryLazy",
    },
  },
}

function M.config()
  local wk = require "which-key"
  wk.add {
    { "<leader>/", "<Plug>(comment_toggle_linewise_current)", desc = "Comment" },
  }

  wk.add {
    { "<leader>/", "<Plug>(comment_toggle_linewise_visual)", desc = "Comment", mode = "v" },
  }

  vim.g.skip_ts_context_commentstring_module = true
  ---@diagnostic disable: missing-fields
  require("ts_context_commentstring").setup {
    enable_autocmd = false,
  }

  require("Comment").setup {
    pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
  }
end

return M
