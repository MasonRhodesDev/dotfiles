local M = {
  "rmagatti/auto-session",
  lazy = false,
  dependencies = {
    "nvim-telescope/telescope.nvim", -- Only needed if you want to use session lens
  },
}

function M.config()
  require("auto-session").setup {
    auto_session_enabled = true,
    auto_save_enabled = true,
    auto_restore_enabled = true,
    auto_session_suppress_dirs = { "~/", "~/Downloads", "~/Documents", "~/Desktop/" },
    
    -- Use git branch in session name and only save in git repos
    auto_session_use_git_branch = false,
    auto_session_enable_last_session = false,
    
    -- Session lens configuration for telescope integration
    session_lens = {
      load_on_setup = true,
      theme_conf = { border = true },
      previewer = false,
    },

    -- Pre and post session hooks
    pre_save_cmds = { "tabdo NvimTreeClose" }, -- Close nvim-tree before saving
    post_restore_cmds = { "NvimTreeOpen" }, -- Reopen nvim-tree after restore
  }

  -- Keymaps for session management
  local wk = require "which-key"
  wk.add {
    { "<leader>s", group = "Session" },
    { "<leader>ss", "<cmd>SessionSave<cr>", desc = "Save Session" },
    { "<leader>sr", "<cmd>SessionRestore<cr>", desc = "Restore Session" },
    { "<leader>sd", "<cmd>SessionDelete<cr>", desc = "Delete Session" },
    { "<leader>sf", "<cmd>Telescope session-lens search_session<cr>", desc = "Find Sessions" },
  }
end

return M