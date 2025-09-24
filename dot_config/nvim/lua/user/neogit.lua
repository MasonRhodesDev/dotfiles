local M = {
  "NeogitOrg/neogit",
  commit = "462ccdeb26409849353d2859393e113a92a35a4a",
  event = "VeryLazy",
}

function M.config()
  local icons = require "user.icons"
  local wk = require "which-key"
  wk.add {
    { "<leader>gg", "<cmd>Neogit<CR>", desc = "Neogit" },
  }

  require("neogit").setup {
    auto_refresh = true,
    disable_builtin_notifications = false,
    use_magit_keybindings = true,
    use_default_keymaps = true,
    -- Change the default way of opening neogit
    kind = "tab",
    -- Change the default way of opening the commit popup
    commit_popup = {
      kind = "split",
    },
    -- Change the default way of opening popups
    popup = {
      kind = "split",
    },
    -- customize displayed signs
    signs = {
      -- { CLOSED, OPENED }
      section = { icons.ui.ChevronRight, icons.ui.ChevronShortDown },
      item = { icons.ui.ChevronRight, icons.ui.ChevronShortDown },
      hunk = { "", "" },
    },
  }
end

return M
