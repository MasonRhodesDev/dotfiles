local M = {
  "typicode/bg.nvim",
  lazy = false, -- Load immediately to sync terminal background
}

-- Function to restore terminal to current WezTerm theme colors
local function restore_to_wezterm_theme()
  local theme_file_path = vim.fn.expand("$HOME/.cache/theme_state")
  local file = io.open(theme_file_path, "r")
  local current_theme = "dark" -- default fallback
  
  if file then
    current_theme = file:read("*line") or "dark"
    file:close()
  end
  
  -- Read current WezTerm theme colors
  local wezterm_config_path = vim.fn.expand("$HOME/.wezterm.lua")
  local wezterm_file = io.open(wezterm_config_path, "r")
  
  if wezterm_file then
    local content = wezterm_file:read("*all")
    wezterm_file:close()
    
    -- Extract background and foreground colors from WezTerm config
    local bg_color = content:match("background = '([^']+)'")
    local fg_color = content:match("foreground = '([^']+)'")
    
    if bg_color and fg_color then
      -- Send OSC sequences to restore to WezTerm's current theme
      io.write(string.format("\027]11;%s\007", bg_color))  -- Set background
      io.write(string.format("\027]10;%s\007", fg_color))  -- Set foreground
      io.flush()
    end
  end
end

function M.config()
  -- Override bg.nvim's exit behavior to restore to current WezTerm theme
  vim.api.nvim_create_autocmd("VimLeavePre", {
    pattern = "*",
    callback = function()
      restore_to_wezterm_theme()
    end,
    desc = "Restore terminal to current WezTerm theme colors",
    priority = 1000, -- Run before bg.nvim's default restoration
  })
end

return M