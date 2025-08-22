local M = {
  "winter-again/wezterm-config.nvim",
  lazy = false,
}

-- Function to sync terminal background with current colorscheme
local function sync_terminal_background()
  -- Get current background color from nvim Normal highlight group
  local bg_color = vim.fn.synIDattr(vim.fn.hlID("Normal"), "bg")
  
  -- If no background color is set, use a default based on background setting
  if bg_color == "" or bg_color == nil then
    if vim.o.background == "dark" then
      bg_color = "#1e1e2e"  -- Default dark background
    else
      bg_color = "#ffffff"  -- Default light background
    end
  end
  
  -- Convert to OSC 11 escape sequence to change terminal background
  local osc_sequence = string.format("\027]11;%s\007", bg_color)
  
  -- Send escape sequence to terminal
  io.write(osc_sequence)
  io.flush()
end

-- Function to restore terminal to default state
local function restore_terminal()
  -- Reset terminal background to default (transparent/original)
  io.write("\027]111\007")  -- Reset background color
  io.flush()
end

function M.config()
  require('wezterm-config').setup({
    append_wezterm_to_rtp = false,
  })
  
  -- Set up autocommands for terminal sync
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      -- Small delay to ensure colorscheme is fully loaded
      vim.defer_fn(sync_terminal_background, 100)
    end,
    desc = "Sync terminal background with nvim colorscheme"
  })
  
  -- Restore terminal on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    pattern = "*",
    callback = restore_terminal,
    desc = "Restore terminal background on nvim exit"
  })
  
  -- Also sync on startup
  vim.defer_fn(sync_terminal_background, 500)
end

return M