local M = {
  "ThePrimeagen/harpoon",
  commit = "ed1f853847ffd04b2b61c314865665e1dadf22c7",
  event = "VeryLazy",
  dependencies = {
    {
      "nvim-lua/plenary.nvim",
      commit = "b9fd5226c2f76c951fc8ed5923d85e4de065e509",
    },
  },
}

function M.config()
  local harpoon = require("harpoon")

  -- Harpoon 2 setup
  harpoon:setup({
    settings = {
      save_on_toggle = false,
      sync_on_ui_close = false,
      key = function()
        return vim.loop.cwd()
      end,
    },
  })

  local keymap = vim.keymap.set
  local opts = { noremap = true, silent = true }

  keymap("n", "<s-m>", function() harpoon:list():add() end, opts)
  keymap("n", "<TAB>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, opts)

  -- Optional: Add numbered shortcuts
  keymap("n", "<C-h>", function() harpoon:list():select(1) end, opts)
  keymap("n", "<C-t>", function() harpoon:list():select(2) end, opts)
  keymap("n", "<C-n>", function() harpoon:list():select(3) end, opts)
  keymap("n", "<C-s>", function() harpoon:list():select(4) end, opts)
end

return M
