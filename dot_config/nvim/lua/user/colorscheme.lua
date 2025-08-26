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
end

local function set_light_mode()
  vim.o.background = "light"
  vim.cmd([[colorscheme oxocarbon]])
  
  -- Force complete colorscheme reload and highlight refresh
  vim.cmd([[doautocmd ColorScheme oxocarbon]])
  
  -- Update LspCodeLens highlight for light theme
  vim.api.nvim_set_hl(0, "LspCodeLens", { fg = "#6b7280", bg = "NONE", italic = true })
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
watch_theme_change()

return {
  {
    "LunarVim/darkplus.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = false,
    priority = 1000,
  },
}
