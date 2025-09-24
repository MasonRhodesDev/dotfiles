local theme_file_path = vim.fn.expand("$HOME/.cache/theme_state")
local uv = vim.uv or vim.loop

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return "dark"
  end
  local content = file:read("*line")
  file:close()
  return content
end

local function set_dark_mode()
  vim.o.background = "dark"
  vim.cmd([[colorscheme darkplus]])
  
  -- Force complete colorscheme reload and highlight refresh
  vim.cmd([[doautocmd ColorScheme darkplus]])
  
  -- Update LspCodeLens highlight for dark theme
  vim.api.nvim_set_hl(0, "LspCodeLens", { fg = "#5c6370", bg = "NONE", italic = true })

  -- Split window borders - use theme's default subtle gray
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#808080", bg = "NONE" })  -- Light gray from darkplus
  vim.api.nvim_set_hl(0, "VertSplit", { fg = "#808080", bg = "NONE" })

  -- Status line for active/inactive
  vim.api.nvim_set_hl(0, "StatusLine", { fg = "#abb2bf", bg = "#2c323c" })
  vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#5c6370", bg = "#242830" })

  -- Background differentiation - only active window changes
  vim.api.nvim_set_hl(0, "Normal", { fg = "#c8c8c8", bg = "#1e2228" })  -- Active window with explicit foreground
  vim.api.nvim_set_hl(0, "NormalNC", { fg = "#c8c8c8", bg = "#1e1e1e" })  -- Inactive - default dark bg
  vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = "#282c34", bg = "#1e2228" })  -- Match active bg
  vim.api.nvim_set_hl(0, "EndOfBufferNC", { fg = "#282c34", bg = "NONE" })
end

local function set_light_mode()
  vim.o.background = "light"
  vim.cmd([[colorscheme oxocarbon]])
  
  -- Force complete colorscheme reload and highlight refresh
  vim.cmd([[doautocmd ColorScheme oxocarbon]])
  
  -- Update LspCodeLens highlight for light theme
  vim.api.nvim_set_hl(0, "LspCodeLens", { fg = "#6b7280", bg = "NONE", italic = true })

  -- Let oxocarbon theme handle its own borders

  -- Status line for active/inactive
  vim.api.nvim_set_hl(0, "StatusLine", { fg = "#374151", bg = "#e5e7eb" })
  vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#9ca3af", bg = "#f3f4f6" })

  -- Background differentiation - only active window changes
  vim.api.nvim_set_hl(0, "Normal", { fg = "#393939", bg = "#f5f5f5" })  -- Active window with explicit foreground
  vim.api.nvim_set_hl(0, "NormalNC", { fg = "#393939", bg = "#f2f4f8" })  -- Inactive - default light bg
  vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = "#ffffff", bg = "#f5f5f5" })  -- Match active bg
  vim.api.nvim_set_hl(0, "EndOfBufferNC", { fg = "#ffffff", bg = "NONE" })
end

local function watch_theme_change()
  local handle = uv.new_fs_event()

  local unwatch_cb = function()
    if handle then
      uv.fs_event_stop(handle)
    end
  end

  local event_cb = function(err)
    if err then
      print("Theme file watcher error: " .. tostring(err))
      unwatch_cb()
    else
      -- Important to wrap in schedule, otherwise error E5560
      vim.schedule(function()
        local theme = read_file(theme_file_path)
        if theme == "light" then
          set_light_mode()
          print("Switching to light mode")
        else
          set_dark_mode()
          print("Switching to dark mode")
        end
        
        -- Force complete UI refresh
        vim.cmd([[redraw!]])
        unwatch_cb()
        watch_theme_change()
      end)
    end
  end

  local flags = {
    watch_entry = false, -- true = when dir, watch dir inode, not dir content
    stat = false, -- true = don't use inotify/kqueue but periodic check, not implemented
    recursive = false, -- true = watch dirs inside dirs
  }

  -- attach handler
  if handle then
    uv.fs_event_start(handle, theme_file_path, flags, event_cb)
  end

  return handle
end

-- Global function for manual theme switching
function _G.set_nvim_theme(mode)
  if mode == "light" then
    set_light_mode()
  else
    set_dark_mode()
  end
end

-- Create command for manual theme sync
vim.api.nvim_create_user_command("SyncTheme", function()
  local current_theme = read_file(theme_file_path)
  _G.set_nvim_theme(current_theme)
end, { desc = "Manually sync theme with system state" })

local theme = read_file(theme_file_path)

-- Defer theme sync until after plugins are loaded
vim.defer_fn(function()
  _G.set_nvim_theme(theme)
end, 100)

watch_theme_change()

return {
  {
    "LunarVim/darkplus.nvim",
    commit = "c7fff5ce62406121fc6c9e4746f118b2b2499c4c",
    lazy = false,
    priority = 1000,
  },
  {
    "nyoom-engineering/oxocarbon.nvim",
    commit = "9f85f6090322f39b11ae04a343d4eb9d12a86897",
    lazy = false,
    priority = 1000,
  },
}
