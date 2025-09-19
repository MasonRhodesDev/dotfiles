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

  -- Function to view session logs
  local function view_session_logs()
    local session_dir = vim.fn.expand("~/.local/share/nvim/sessions/")
    local current_session = vim.fn.fnamemodify(vim.v.this_session, ":t")

    if current_session == "" then
      vim.notify("No active session", vim.log.levels.INFO)
      return
    end

    -- Read current session file for inspection
    local session_file = session_dir .. current_session
    local lines = {}

    if vim.fn.filereadable(session_file) == 1 then
      local file = io.open(session_file, "r")
      if file then
        table.insert(lines, "=== Session: " .. current_session .. " ===")
        table.insert(lines, "Path: " .. session_file)
        table.insert(lines, "Modified: " .. os.date("%Y-%m-%d %H:%M:%S", vim.fn.getftime(session_file)))
        table.insert(lines, "")
        table.insert(lines, "--- Session Content Preview ---")

        local line_count = 0
        for line in file:lines() do
          line_count = line_count + 1
          if line_count <= 50 then  -- Show first 50 lines
            table.insert(lines, line)
          end
        end
        file:close()

        if line_count > 50 then
          table.insert(lines, "... (" .. (line_count - 50) .. " more lines)")
        end
      end
    else
      table.insert(lines, "Session file not found: " .. session_file)
    end

    -- Create a scratch buffer to show the logs
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "filetype", "vim")

    -- Open in a new split
    vim.cmd("split")
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_win_set_option(0, "wrap", false)
    vim.api.nvim_win_set_option(0, "number", true)
  end

  -- Create command for session logs
  vim.api.nvim_create_user_command("SessionLogs", view_session_logs, { desc = "View current session logs" })

  -- Keymaps for session management
  local wk = require "which-key"
  wk.add {
    { "<leader>s", group = "Session" },
    { "<leader>ss", "<cmd>SessionSave<cr>", desc = "Save Session" },
    { "<leader>sr", "<cmd>SessionRestore<cr>", desc = "Restore Session" },
    { "<leader>sd", "<cmd>SessionDelete<cr>", desc = "Delete Session" },
    { "<leader>sf", "<cmd>Telescope session-lens search_session<cr>", desc = "Find Sessions" },
    { "<leader>sl", view_session_logs, desc = "View Session Logs" },
  }
end

return M