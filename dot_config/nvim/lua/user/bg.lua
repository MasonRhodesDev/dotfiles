local M = {
  "b3nj5m1n/bg.nvim",
  commit = "df916e4df2493ee302eea62185ed014ba7ca40d9",
  lazy = false, -- Load immediately to sync terminal background
}

-- Function to set terminal to opaque when entering Neovim
local function set_terminal_opaque()
  -- Set WezTerm to fully opaque using OSC 1337 SetUserVar
  local opacity_base64 = "MS4w"  -- Base64 encoded "1.0"
  io.write(string.format("\027]1337;SetUserVar=window_background_opacity=%s\007", opacity_base64))
  io.flush()
  
  -- Also try direct opacity setting via OSC sequence as backup
  io.write("\027]1337;SetUserVar=window_background_opacity=MS4w\007")
  io.flush()
end

-- Function to restore terminal to current WezTerm theme colors and transparency
local function restore_to_wezterm_theme()
  local theme_file_path = vim.fn.expand("$HOME/.cache/theme_state")
  local file = io.open(theme_file_path, "r")
  local current_theme = "dark" -- default fallback
  
  if file then
    current_theme = file:read("*line") or "dark"
    file:close()
  end
  
  -- Read current WezTerm theme colors and opacity
  local wezterm_config_path = vim.fn.expand("$HOME/.wezterm.lua")
  local wezterm_file = io.open(wezterm_config_path, "r")
  
  if wezterm_file then
    local content = wezterm_file:read("*all")
    wezterm_file:close()
    
    -- Extract background, foreground colors and opacity from WezTerm config
    local bg_color = content:match("background = '([^']+)'")
    local fg_color = content:match("foreground = '([^']+)'")
    local opacity = content:match("window_background_opacity = ([%d%.]+)")
    
    if bg_color and fg_color then
      -- Send OSC sequences to restore to WezTerm's current theme
      io.write(string.format("\027]11;%s\007", bg_color))  -- Set background
      io.write(string.format("\027]10;%s\007", fg_color))  -- Set foreground
      
      -- Restore original opacity (default 0.95 if not found)
      local target_opacity = opacity or "0.95"
      local opacity_base64 = vim.fn.system(string.format("echo -n '%s' | base64", target_opacity)):gsub("\n", "")
      io.write(string.format("\027]1337;SetUserVar=window_background_opacity=%s\007", opacity_base64))
      io.flush()
    end
  end
end

function M.config()
  -- Set terminal opaque when colorscheme changes (Neovim theme sync)
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      vim.defer_fn(set_terminal_opaque, 100)
    end,
    desc = "Set terminal opaque when entering Neovim or changing colorscheme",
  })
  
  -- Restore terminal theme and transparency when exiting Neovim
  vim.api.nvim_create_autocmd("VimLeavePre", {
    pattern = "*",
    callback = function()
      restore_to_wezterm_theme()
    end,
    desc = "Restore terminal to current WezTerm theme colors and transparency",
  })
  
  -- Also set opaque on initial load
  vim.defer_fn(set_terminal_opaque, 500)
end

return M